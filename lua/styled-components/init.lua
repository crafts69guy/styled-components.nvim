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
