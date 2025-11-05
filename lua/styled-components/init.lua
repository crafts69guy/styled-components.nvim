local M = {}

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
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if not M.config.enabled then
		return
	end

	if M.config.auto_setup then
		-- Setup TreeSitter injection
		local injection = require("styled-components.injection")

		-- Load injection queries
		local queries_loaded = injection.setup_injection_queries({ debug = M.config.debug })

		if queries_loaded then
			M.log("TreeSitter injection queries loaded successfully")

			-- Setup cssls for injection
			vim.defer_fn(function()
				injection.setup_cssls_for_injection({
					debug = M.config.debug,
					cssls_config = M.config.cssls_config,
				})
			end, 100) -- Defer to ensure LSP system is loaded
		else
			vim.notify(
				"[styled-components] Failed to load injection queries. CSS completions may not work.",
				vim.log.levels.WARN
			)
		end
	end

	if M.config.debug then
		vim.notify("styled-components.nvim initialized with TreeSitter injection", vim.log.levels.INFO)
	end
end

function M.log(msg)
	if M.config.debug then
		vim.notify("[styled-components] " .. msg, vim.log.levels.DEBUG)
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

return M
