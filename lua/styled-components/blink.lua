--- Blink.cmp integration helpers for styled-components.nvim
---
--- This module provides helper functions to properly integrate styled-components
--- with blink.cmp using the official Provider Override API.
---
--- Users should configure blink.cmp using these helpers in their config:
---
--- ```lua
--- local styled = require("styled-components.blink")
---
--- require("blink.cmp").setup({
---   sources = {
---     default = { "lsp", "path", "snippets", "buffer", "styled-components" },
---     providers = {
---       lsp = {
---         override = {
---           transform_items = styled.get_lsp_transform_items(),
---         },
---       },
---       ["styled-components"] = {
---         name = "styled-components",
---         module = "styled-components.completion",
---         enabled = styled.enabled,
---       },
---     },
---   },
--- })
--- ```
local M = {}

--- Check if styled-components source should be enabled for current buffer
--- This is used by blink.cmp to determine when to activate the source
---
--- @return boolean True if current filetype supports styled-components
function M.enabled()
	local ft = vim.bo.filetype
	return vim.tbl_contains({
		"typescript",
		"typescriptreact",
		"javascript",
		"javascriptreact",
	}, ft)
end

--- Get transform_items function for blink.cmp's LSP source
---
--- This function filters cssls completions to ONLY appear inside styled-component
--- template literals. Outside of styled-component templates, cssls completions
--- are hidden to prevent pollution of TypeScript/JavaScript completions.
---
--- Why this is needed:
--- - styled-components.nvim configures cssls to attach to TS/JS files (required for injection)
--- - blink.cmp's LSP source shows ALL completions from ALL attached LSP clients
--- - Without filtering, users see CSS completions everywhere (React components, hooks, etc.)
--- - This filter ensures CSS completions ONLY appear in styled-component templates
---
--- How it works:
--- 1. Check if cursor is in TypeScript/JavaScript file
--- 2. Check if cursor is inside TreeSitter-injected CSS region
--- 3. If NOT in CSS region, filter out cssls completions
--- 4. If IN CSS region, allow all completions (including cssls)
---
--- @return function transform_items function compatible with blink.cmp's LSP source override API
function M.get_lsp_transform_items()
	local injection = require("styled-components.injection")

	return function(ctx, items)
		-- Safety check: ensure context and items are valid
		if not ctx or not ctx.bufnr or not ctx.cursor or not items then
			return items or {}
		end

		-- Only apply filtering for TypeScript/JavaScript files
		local ft = vim.bo[ctx.bufnr].filetype
		if not vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, ft) then
			return items
		end

		-- Check if cursor is in styled-component CSS injection region
		local row = ctx.cursor[1] - 1 -- blink.cmp uses 1-indexed, convert to 0-indexed
		local col = ctx.cursor[2] - 1

		-- Safely check injected language (may fail if TreeSitter not available)
		local ok, injected_lang = pcall(injection.get_injected_language_at_pos, ctx.bufnr, row, col)
		if not ok then
			-- TreeSitter error - skip filtering to be safe
			return items
		end

		local in_css = (injected_lang == "css" or injected_lang == "styled")

		-- If NOT in CSS context, filter out cssls completions
		if not in_css then
			return vim.tbl_filter(function(item)
				-- Detect cssls items by checking various fields
				-- Different blink.cmp versions may structure items differently

				-- Check source_name field (most common)
				if item.source_name == "cssls" then
					return false
				end

				-- Check nested source.name field (fallback)
				if item.source and item.source.name == "cssls" then
					return false
				end

				-- Check client.name field (LSP client identification)
				if item.client and item.client.name == "cssls" then
					return false
				end

				-- Check label_details.description for CSS marker
				-- Some LSP servers add language info here
				if item.label_details and item.label_details.description == "CSS" then
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
