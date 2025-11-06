local M = {}

--- Safe notification helper that works during early init
--- Defers notification to avoid issues with UI plugins that aren't loaded yet
---
--- This is critical for plugins that load early (via lazy.nvim's init function)
--- because notification systems like Snacks (in LazyVim) may not be loaded yet.
---
--- @param msg string The message to display
--- @param level number vim.log.levels (INFO, WARN, ERROR, DEBUG)
function M.notify(msg, level)
	-- Use vim.schedule to defer notification to next event loop tick
	-- This ensures UI plugins (like Snacks in LazyVim) are loaded
	vim.schedule(function()
		-- pcall for extra safety in case notification system has issues
		pcall(vim.notify, msg, level)
	end)
end

return M
