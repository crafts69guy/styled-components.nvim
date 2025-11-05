-- Plugin entry point
if vim.g.loaded_styled_components then
	return
end
vim.g.loaded_styled_components = 1

-- Setup autocmds for cache management
require("styled-components.detector").setup_autocmds()
