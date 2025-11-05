local M = {}

--- Check if TreeSitter injection is available
---@return boolean
function M.is_injection_available()
	-- Check if nvim-treesitter is available
	local has_ts, _ = pcall(require, "nvim-treesitter")
	if not has_ts then
		return false
	end

	-- Check Neovim version (need 0.10+)
	if vim.fn.has("nvim-0.10") == 0 then
		return false
	end

	return true
end

--- Setup TreeSitter injection queries
---@param opts table Options
function M.setup_injection_queries(opts)
	opts = opts or {}

	if not M.is_injection_available() then
		vim.notify("[styled-components] TreeSitter injection requires Neovim 0.10+", vim.log.levels.WARN)
		return false
	end

	-- Get plugin root directory
	local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
	local queries_dir = plugin_root .. "/queries"

	-- Check if queries exist
	if vim.fn.isdirectory(queries_dir) == 0 then
		vim.notify("[styled-components] Injection queries not found at: " .. queries_dir, vim.log.levels.ERROR)
		return false
	end

	-- Add query paths to runtimepath
	-- Neovim will automatically load queries from these directories
	vim.opt.runtimepath:append(plugin_root)

	if opts.debug then
		vim.notify("[styled-components] Injection queries loaded from: " .. queries_dir, vim.log.levels.INFO)
	end

	return true
end

--- Check if injection is active for current buffer
---@param bufnr number|nil Buffer number (default: current)
---@return boolean
function M.is_injection_active(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Get filetype
	local filetype = vim.bo[bufnr].filetype
	if not vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype) then
		return false
	end

	-- Check if TreeSitter parser exists
	local has_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not has_parser or not parser then
		return false
	end

	-- Get the actual parser language
	local parser_lang = parser:lang()

	-- Check if we have injection queries loaded for this parser language
	local has_query = pcall(vim.treesitter.query.get, parser_lang, "injections")
	if not has_query then
		return false
	end

	return true
end

--- Get injected language at cursor position
---@param bufnr number|nil Buffer number
---@param row number 0-indexed row
---@param col number 0-indexed column
---@return string|nil Injected language (e.g., "css")
function M.get_injected_language_at_pos(bufnr, row, col)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not M.is_injection_active(bufnr) then
		return nil
	end

	-- Get the parser
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok or not parser then
		return nil
	end

	-- Get the language tree at position
	local lang_tree = parser:language_for_range({ row, col, row, col })
	if not lang_tree then
		return nil
	end

	-- Get the language
	local lang = lang_tree:lang()

	-- Only return if it's CSS (injected language)
	if lang == "css" then
		return lang
	end

	return nil
end

--- Check if Neovim 0.11+ with native vim.lsp.config
---@return boolean
local function has_native_lsp_config()
	return vim.fn.has("nvim-0.11") == 1 and vim.lsp.config ~= nil
end

--- Setup cssls to work with injected CSS
---@param opts table|nil Options
function M.setup_cssls_for_injection(opts)
	opts = opts or {}

	-- Define extended filetypes
	local extended_filetypes = {
		"css",
		"scss",
		"less",
		"typescript",
		"typescriptreact",
		"javascript",
		"javascriptreact",
	}

	-- Define CSS settings
	local css_settings = {
		css = {
			validate = true,
			lint = {
				unknownAtRules = "ignore", -- styled-components may use custom at-rules
			},
		},
	}

	-- Use native Neovim 0.11+ API if available
	if has_native_lsp_config() then
		-- Configure using vim.lsp.config
		vim.lsp.config.cssls = vim.tbl_deep_extend("force", {
			cmd = { "vscode-css-language-server", "--stdio" },
			root_markers = { "package.json", ".git" },
			filetypes = extended_filetypes,
			settings = css_settings,
			capabilities = {
				textDocument = {
					completion = {
						completionItem = {
							snippetSupport = true,
						},
					},
				},
			},
		}, opts.cssls_config or {})

		-- Enable cssls
		vim.lsp.enable("cssls")

		if opts.debug then
			vim.notify(
				"[styled-components] cssls configured (vim.lsp.config) for filetypes: "
					.. table.concat(extended_filetypes, ", "),
				vim.log.levels.INFO
			)
		end

		return true
	end

	-- Fallback to nvim-lspconfig for older Neovim versions
	local has_lspconfig, lspconfig = pcall(require, "lspconfig")
	if not has_lspconfig then
		if opts.debug then
			vim.notify(
				"[styled-components] nvim-lspconfig not found. Please configure cssls manually.",
				vim.log.levels.WARN
			)
		end
		return false
	end

	-- Get current cssls config
	local cssls_config = lspconfig.cssls or {}

	-- Setup or update cssls (legacy API)
	lspconfig.cssls.setup(vim.tbl_deep_extend("force", cssls_config, {
		filetypes = extended_filetypes,
		settings = css_settings,
	}, opts.cssls_config or {}))

	if opts.debug then
		vim.notify(
			"[styled-components] cssls configured (lspconfig) for filetypes: " .. table.concat(extended_filetypes, ", "),
			vim.log.levels.INFO
		)
	end

	return true
end

return M
