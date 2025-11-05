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
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if M.config.debug then
		vim.notify("styled-components.nvim loaded", vim.log.levels.INFO)
	end
end

function M.log(msg)
	if M.config.debug then
		vim.notify("[styled-components] " .. msg, vim.log.levels.DEBUG)
	end
end

return M
