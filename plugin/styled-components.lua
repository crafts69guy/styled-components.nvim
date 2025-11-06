-- Plugin entry point
if vim.g.loaded_styled_components then
	return
end
vim.g.loaded_styled_components = 1

-- Auto-load injection queries early on VimEnter
-- This avoids dependency order issues with plugin managers (like lazy.nvim)
-- by ensuring queries load after all core plugins are initialized
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		-- Load queries early if not already loaded via setup()
		local styled = require("styled-components")
		if styled.config.auto_setup then
			styled.load_queries_early({ debug = styled.config.debug })
		end
	end,
})

-- Setup autocmds for cache management
require("styled-components.detector").setup_autocmds()
