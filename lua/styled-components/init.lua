local M = {}
local util = require("styled-components.util")

-- Cache to prevent duplicate initialization
local setup_done = false
local queries_loaded = false

M.config = {
	enabled = true,
	debug = false,
	filetypes = {
		"typescript",
		"typescriptreact",
		"javascript",
		"javascriptreact",
	},
	-- Auto-setup injection queries and cssls
	auto_setup = true,
	-- Custom cssls configuration (merged with defaults)
	cssls_config = {},

	-- Completion source performance options
	completion = {
		-- Context detection cache TTL in milliseconds
		-- Caching significantly improves performance by avoiding repeated TreeSitter queries
		cache_ttl_ms = 100,
	},

	-- Automatically integrate with blink.cmp to filter cssls completions
	-- When enabled, plugin will patch blink.cmp's LSP source to hide CSS completions
	-- outside styled-component templates (prevents cssls from triggering everywhere)
	-- Set to false if you prefer manual control via require("styled-components.blink").get_lsp_transform_items()
	blink_integration = true,
}

--- Load ONLY injection queries (lightweight, for early init)
--- This can be called in lazy.nvim's init function to ensure
--- queries are available before buffers are parsed by TreeSitter.
---@param opts? {debug?: boolean}
---@return boolean success
function M.load_queries_early(opts)
	if queries_loaded then
		return true
	end

	opts = opts or {}
	local debug = opts.debug or M.config.debug

	local injection = require("styled-components.injection")
	queries_loaded = injection.setup_injection_queries({ debug = debug })

	if queries_loaded and debug then
		util.notify("[styled-components] TreeSitter injection queries loaded (early)", vim.log.levels.INFO)
	end

	return queries_loaded
end

--- Automatically setup blink.cmp integration if available
--- This patches blink.cmp's LSP source to filter cssls completions outside styled-component context
---
--- Why this is needed:
--- - styled-components.nvim configures cssls to attach to TypeScript/JavaScript files
--- - blink.cmp's LSP source forwards ALL completions from ALL LSP clients without context filtering
--- - This causes CSS completions to appear everywhere in TS/JS files, not just in styled-components
--- - Auto-integration patches the LSP source's transform_items to filter cssls appropriately
---
--- @return boolean success Whether integration was setup successfully
function M.setup_blink_integration()
	-- Check if blink.cmp is available
	local ok, blink_cmp = pcall(require, "blink.cmp")
	if not ok then
		if M.config.debug then
			util.notify("[styled-components] blink.cmp not found, skipping auto-integration", vim.log.levels.DEBUG)
		end
		return false
	end

	-- Defer patching until blink.cmp sources are initialized
	-- This ensures blink.cmp's internal structures are ready
	vim.defer_fn(function()
		local ok_config, blink_config = pcall(require, "blink.cmp.config")
		if not ok_config then
			if M.config.debug then
				util.notify(
					"[styled-components] Failed to load blink.cmp.config, skipping auto-integration",
					vim.log.levels.WARN
				)
			end
			return
		end

		-- Get LSP source provider config
		local providers = blink_config.sources.providers or {}
		local lsp_provider = providers.lsp

		if not lsp_provider then
			if M.config.debug then
				util.notify(
					"[styled-components] blink.cmp LSP provider not found, skipping auto-integration",
					vim.log.levels.WARN
				)
			end
			return
		end

		-- Wrap existing transform_items or create new one
		local original_transform = lsp_provider.transform_items
		local blink_util = require("styled-components.blink")
		local our_transform = blink_util.get_lsp_transform_items()

		lsp_provider.transform_items = function(ctx, items)
			-- Apply original transform first if exists (preserve user's existing transformations)
			if original_transform then
				items = original_transform(ctx, items)
			end
			-- Then apply our cssls filtering
			return our_transform(ctx, items)
		end

		-- Also override get_trigger_characters to prevent cssls triggers outside CSS context
		-- This prevents ':' and ';' from triggering CSS completions in TypeScript code
		local original_get_trigger_chars = lsp_provider.get_trigger_characters
		lsp_provider.get_trigger_characters = function(self)
			-- Get original trigger characters from all LSP clients
			local triggers = {}
			if original_get_trigger_chars then
				triggers = original_get_trigger_chars(self) or {}
			end

			-- If in TypeScript/JavaScript file, check if cursor is in CSS context
			-- If not, filter out CSS-specific trigger characters
			local bufnr = vim.api.nvim_get_current_buf()
			local ft = vim.bo[bufnr].filetype
			if vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, ft) then
				-- Get cursor position
				local cursor = vim.api.nvim_win_get_cursor(0)
				local row = cursor[1] - 1
				local col = cursor[2]

				-- Check if in CSS injection
				local injection = require("styled-components.injection")
				local injected_lang = injection.get_injected_language_at_pos(bufnr, row, col)

				-- If NOT in CSS context, filter out CSS trigger characters
				if injected_lang ~= "css" and injected_lang ~= "styled" then
					-- Remove CSS-specific triggers: ':', ';', '-', etc.
					triggers = vim.tbl_filter(function(char)
						return not vim.tbl_contains({ ":", ";", "-", "{", "}" }, char)
					end, triggers)
				end
			end

			return triggers
		end

		if M.config.debug then
			util.notify(
				"[styled-components] blink.cmp LSP source patched successfully (cssls filtering + trigger override enabled)",
				vim.log.levels.INFO
			)
		end
	end, 100) -- Delay 100ms to ensure blink.cmp is fully initialized

	return true
end

function M.setup(opts)
	-- Prevent duplicate setup
	if setup_done then
		if M.config.debug then
			util.notify("[styled-components] Setup already done, skipping", vim.log.levels.DEBUG)
		end
		return
	end

	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if not M.config.enabled then
		return
	end

	if M.config.auto_setup then
		-- Load injection queries if not already loaded
		if not queries_loaded then
			local success = M.load_queries_early({ debug = M.config.debug })
			if not success then
				util.notify(
					"[styled-components] Failed to load injection queries. CSS completions may not work.",
					vim.log.levels.WARN
				)
				return
			end
		end

		-- Setup cssls for injection (deferred to ensure LSP system is ready)
		local injection = require("styled-components.injection")
		vim.defer_fn(function()
			injection.setup_cssls_for_injection({
				debug = M.config.debug,
				cssls_config = M.config.cssls_config,
			})

			if M.config.debug then
				util.notify("[styled-components] Full setup completed (cssls configured)", vim.log.levels.INFO)
			end
		end, 100)
	end

	-- Setup blink.cmp integration (auto-filter cssls completions)
	if M.config.blink_integration then
		M.setup_blink_integration()
	end

	setup_done = true

	if M.config.debug then
		util.notify("[styled-components] Plugin initialized with TreeSitter injection", vim.log.levels.INFO)
	end
end

function M.log(msg)
	if M.config.debug then
		util.notify("[styled-components] " .. msg, vim.log.levels.DEBUG)
	end
end

--- Check if injection is working for current buffer
---@return boolean
function M.is_injection_working()
	local injection = require("styled-components.injection")
	return injection.is_injection_active()
end

--- Get status information (for debugging)
---@return table
function M.status()
	local injection = require("styled-components.injection")
	local detector = require("styled-components.detector")

	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)

	return {
		enabled = M.config.enabled,
		auto_setup = M.config.auto_setup,
		injection_available = injection.is_injection_available(),
		injection_active = injection.is_injection_active(bufnr),
		has_styled_import = detector.has_styled_import(bufnr),
		in_styled_template = detector.is_in_styled_template(),
		injected_language = injection.get_injected_language_at_pos(bufnr, cursor[1] - 1, cursor[2]),
		config = M.config,
	}
end

--- Print status (for debugging)
function M.print_status()
	print(vim.inspect(M.status()))
end

--- Get blink.cmp completion source
--- Note: This returns the source module, not an instance.
--- blink.cmp will call source.new(opts) to create instances.
---@return table blink.cmp source module
function M.get_completion_source()
	local completion = require("styled-components.completion")
	-- Pass config to source when it's instantiated by blink.cmp
	local original_new = completion.new
	completion.new = function(opts)
		opts = opts or {}
		-- Merge plugin config with user-provided opts
		opts = vim.tbl_deep_extend("force", {
			debug = M.config.debug,
			cache_ttl_ms = M.config.completion.cache_ttl_ms,
		}, opts)
		return original_new(opts)
	end
	return completion
end

return M
