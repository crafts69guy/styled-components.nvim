--- Blink.cmp integration utilities
--- Provides helper functions to integrate styled-components with blink.cmp
local M = {}

--- Get transform_items function for blink.cmp's LSP source
--- This filters cssls completions when NOT in styled-component context
---
--- Why this is needed:
--- - styled-components.nvim configures cssls to attach to TypeScript/JavaScript files
--- - This is necessary for TreeSitter injection to work
--- - However, blink.cmp's LSP source forwards ALL completions from ALL LSP clients
--- - Without filtering, users see CSS completions everywhere in TS/JS files
--- - This function filters cssls completions to ONLY appear in styled-component templates
---
--- Usage in blink.cmp config:
--- ```lua
--- require("blink.cmp").setup({
---   sources = {
---     providers = {
---       lsp = {
---         transform_items = require("styled-components.blink").get_lsp_transform_items(),
---       },
---     },
---   },
--- })
--- ```
---
--- @return function transform_items function compatible with blink.cmp's LSP source
function M.get_lsp_transform_items()
	local injection = require("styled-components.injection")

	return function(ctx, items)
		-- Only apply filtering for JS/TS files
		local ft = vim.bo[ctx.bufnr].filetype
		if not vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, ft) then
			return items
		end

		-- Check if cursor is in styled-component CSS region
		local row = ctx.cursor[1] - 1 -- Convert to 0-indexed
		local col = ctx.cursor[2] - 1 -- Convert to 0-indexed
		local injected_lang = injection.get_injected_language_at_pos(ctx.bufnr, row, col)

		-- If NOT in CSS injection, filter out cssls completions
		if injected_lang ~= "css" and injected_lang ~= "styled" then
			return vim.tbl_filter(function(item)
				-- Filter out items from cssls
				-- Check multiple fields as different blink versions may use different structures
				local source_name = item.source_name or (item.source and item.source.name)
				if source_name == "cssls" then
					return false
				end
				if item.client and item.client.name == "cssls" then
					return false
				end
				return true
			end, items)
		end

		-- In CSS injection region, allow all completions (including cssls)
		return items
	end
end

return M
