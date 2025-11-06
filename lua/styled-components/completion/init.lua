--- Blink.cmp completion source for styled-components
--- Provides CSS completions inside styled-component template literals
local util = require("styled-components.util")
local injection = require("styled-components.injection")
local extractor = require("styled-components.completion.extractor")
local provider = require("styled-components.completion.provider")

local M = {}

--- @class StyledComponentsSource
local source = {}

--- Initialize the source
--- @param opts table Options from user config
--- @return StyledComponentsSource
function source.new(opts)
	opts = opts or {}

	local self = setmetatable({}, { __index = source })
	self.debug = opts.debug or false
	return self
end

--- Check if source should be enabled for current buffer
--- @return boolean
function source:enabled()
	local filetype = vim.bo.filetype
	return vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype)
end

--- Get trigger characters for completion
--- @return string[]
function source:get_trigger_characters()
	return {
		-- CSS property triggers
		":",
		";",
		" ",
		"-",
		-- For triggering after property name
		"a",
		"b",
		"c",
		"d",
		"e",
		"f",
		"g",
		"h",
		"i",
		"j",
		"k",
		"l",
		"m",
		"n",
		"o",
		"p",
		"q",
		"r",
		"s",
		"t",
		"u",
		"v",
		"w",
		"x",
		"y",
		"z",
	}
end

--- Get completions for current context
--- @param ctx table blink.cmp context
--- @param callback function Callback to return completion items
--- @return function|nil Cancel function
function source:get_completions(ctx, callback)
	local bufnr = ctx.bufnr
	local row = ctx.cursor[1] - 1 -- Convert to 0-indexed (ctx.cursor is 1-indexed)
	local col = ctx.cursor[2] - 1 -- Convert to 0-indexed

	if self.debug then
		util.notify(string.format("[styled-components] Completion requested at %d:%d", row, col), vim.log.levels.DEBUG)
	end

	-- Check if cursor is in injected CSS region
	local injected_lang = injection.get_injected_language_at_pos(bufnr, row, col)

	-- Accept both "css" and "styled" as valid CSS regions
	if injected_lang ~= "css" and injected_lang ~= "styled" then
		callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
		return
	end

	if self.debug then
		util.notify("[styled-components] In CSS region, extracting...", vim.log.levels.DEBUG)
	end

	-- Extract CSS region
	local css_region = extractor.extract_css_region(bufnr, row, col)
	if not css_region then
		if self.debug then
			util.notify("[styled-components] Failed to extract CSS region", vim.log.levels.WARN)
		end
		callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
		return
	end

	if self.debug then
		util.notify(
			string.format(
				"[styled-components] Extracted CSS region: %d:%d to %d:%d",
				css_region.start_line,
				css_region.start_col,
				css_region.end_line,
				css_region.end_col
			),
			vim.log.levels.DEBUG
		)
	end

	-- Create virtual CSS document with wrapper
	local virtual_content, line_offset = extractor.create_virtual_css_document(bufnr, css_region)

	-- Adjust position for the wrapper (add line_offset to row)
	local adjusted_row = row + line_offset

	if self.debug then
		util.notify(
			string.format("[styled-components] Requesting completions at adjusted position %d:%d", adjusted_row, col),
			vim.log.levels.DEBUG
		)
	end

	-- Request completions from cssls with adjusted position
	return provider.request_completions(bufnr, virtual_content, adjusted_row, col, function(result)
		if self.debug then
			util.notify(
				string.format("[styled-components] Received %d completion items", #result.items),
				vim.log.levels.DEBUG
			)
		end
		callback(result)
	end)
end

--- Resolve additional completion item details
--- @param item table Completion item
--- @param callback function Callback with resolved item
function source:resolve(item, callback)
	-- For now, just return the item as-is
	-- In the future, we could request additional details from cssls
	callback(item)
end

-- Export the source constructor
M.new = source.new

return M
