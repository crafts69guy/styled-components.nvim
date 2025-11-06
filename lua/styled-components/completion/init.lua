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

	-- Context detection cache for performance optimization
	-- Cache structure: { "bufnr:row:col" = { in_css: boolean, timestamp: number } }
	self.context_cache = {}
	self.cache_ttl_ms = opts.cache_ttl_ms or 100 -- Cache validity: 100ms

	return self
end

--- Check if source should be enabled for current buffer
--- @return boolean
function source:enabled()
	local filetype = vim.bo.filetype
	return vim.tbl_contains({ "typescript", "typescriptreact", "javascript", "javascriptreact" }, filetype)
end

--- Lightweight check if cursor is in styled-component template pattern
--- This verifies the TreeSitter structure without full extraction
--- @param bufnr number Buffer number
--- @param row number 0-indexed row
--- @param col number 0-indexed column
--- @return boolean
function source:_is_styled_component_pattern(bufnr, row, col)
	-- Get TreeSitter node at cursor
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, col } })
	if not ok or not node then
		if self.debug then
			util.notify("[styled-components] Pattern check: no node at position", vim.log.levels.DEBUG)
		end
		return false
	end

	if self.debug then
		util.notify(
			string.format("[styled-components] Pattern check: node=%s", node:type()),
			vim.log.levels.DEBUG
		)
	end

	-- Walk up to find string_fragment inside template_string
	local current = node
	local depth = 0
	local string_fragment = nil

	while current and depth < 10 do
		if
			current:type() == "string_fragment"
			and current:parent()
			and current:parent():type() == "template_string"
		then
			string_fragment = current
			break
		end
		current = current:parent()
		depth = depth + 1
	end

	if not string_fragment then
		if self.debug then
			util.notify("[styled-components] Pattern check: not in template_string", vim.log.levels.DEBUG)
		end
		return false
	end

	-- Check if parent is call_expression
	local template_string = string_fragment:parent()
	if not template_string then
		return false
	end

	local call_expr = template_string:parent()
	if not call_expr or call_expr:type() ~= "call_expression" then
		if self.debug then
			util.notify(
				string.format(
					"[styled-components] Pattern check: parent is not call_expression, got %s",
					call_expr and call_expr:type() or "nil"
				),
				vim.log.levels.DEBUG
			)
		end
		return false
	end

	-- Quick pattern check: styled, css, createGlobalStyle, keyframes
	local function_node = call_expr:child(0)
	if not function_node then
		return false
	end

	local func_type = function_node:type()

	if self.debug then
		util.notify(
			string.format("[styled-components] Pattern check: function type=%s", func_type),
			vim.log.levels.DEBUG
		)
	end

	-- Check member_expression: styled.div
	if func_type == "member_expression" then
		local object_node = function_node:child(0)
		if object_node and object_node:type() == "identifier" then
			local object_text = vim.treesitter.get_node_text(object_node, bufnr)
			if self.debug then
				util.notify(
					string.format("[styled-components] Pattern check: member_expression object=%s", object_text),
					vim.log.levels.DEBUG
				)
			end
			if object_text == "styled" then
				return true
			end
		end
	end

	-- Check identifier: css, createGlobalStyle, keyframes
	if func_type == "identifier" then
		local func_text = vim.treesitter.get_node_text(function_node, bufnr)
		if self.debug then
			util.notify(
				string.format("[styled-components] Pattern check: identifier=%s", func_text),
				vim.log.levels.DEBUG
			)
		end
		if func_text == "css" or func_text == "createGlobalStyle" or func_text == "keyframes" then
			return true
		end
	end

	-- Check call_expression: styled(Component)
	if func_type == "call_expression" then
		local inner_func = function_node:child(0)
		if inner_func and inner_func:type() == "identifier" then
			local func_text = vim.treesitter.get_node_text(inner_func, bufnr)
			if self.debug then
				util.notify(
					string.format("[styled-components] Pattern check: call_expression func=%s", func_text),
					vim.log.levels.DEBUG
				)
			end
			if func_text == "styled" then
				return true
			end
		end
	end

	if self.debug then
		util.notify(
			string.format("[styled-components] Pattern check: NO MATCH (func_type=%s)", func_type),
			vim.log.levels.WARN
		)
	end

	return false
end

--- Check if cursor is in CSS context (with caching for performance)
--- @param bufnr number Buffer number
--- @param row number 0-indexed row
--- @param col number 0-indexed column
--- @return boolean
function source:is_in_css_context(bufnr, row, col)
	-- Generate cache key
	local cache_key = string.format("%d:%d:%d", bufnr, row, col)
	local now = vim.uv.now() -- Get current time in milliseconds

	-- Check cache
	local cached = self.context_cache[cache_key]
	if cached and (now - cached.timestamp) < self.cache_ttl_ms then
		if self.debug then
			util.notify("[styled-components] Cache hit for " .. cache_key, vim.log.levels.DEBUG)
		end
		return cached.in_css
	end

	-- Cache miss or expired - perform detection
	-- Step 1: Check TreeSitter injection (fast via native API)
	local injected_lang = injection.get_injected_language_at_pos(bufnr, row, col)
	local has_css_injection = (injected_lang == "css" or injected_lang == "styled")

	-- Step 2: Verify it's actually a styled-component pattern (not other CSS injection)
	-- This prevents false positives from custom injection queries
	local in_css = has_css_injection and self:_is_styled_component_pattern(bufnr, row, col)

	-- Update cache
	self.context_cache[cache_key] = {
		in_css = in_css,
		timestamp = now,
	}

	-- Clean old cache entries (prevent memory leak)
	-- Only run cleanup occasionally (every 50 checks)
	if not self._cache_check_count then
		self._cache_check_count = 0
	end
	self._cache_check_count = self._cache_check_count + 1

	if self._cache_check_count % 50 == 0 then
		self:cleanup_cache(now)
	end

	if self.debug then
		util.notify(
			string.format(
				"[styled-components] Cache miss: %s → injection=%s, pattern=%s, result=%s",
				cache_key,
				tostring(has_css_injection),
				tostring(in_css and has_css_injection),
				tostring(in_css)
			),
			vim.log.levels.DEBUG
		)
	end

	return in_css
end

--- Clean up expired cache entries
--- @param current_time number Current timestamp in milliseconds
function source:cleanup_cache(current_time)
	local removed_count = 0
	for key, entry in pairs(self.context_cache) do
		if (current_time - entry.timestamp) >= self.cache_ttl_ms then
			self.context_cache[key] = nil
			removed_count = removed_count + 1
		end
	end

	if self.debug and removed_count > 0 then
		util.notify(
			string.format("[styled-components] Cleaned %d expired cache entries", removed_count),
			vim.log.levels.DEBUG
		)
	end
end

--- Get trigger characters for completion
--- Returns empty array to let blink.cmp handle keyword-based triggering automatically.
--- This prevents false triggers (e.g., ':' for TypeScript type annotations).
--- blink.cmp will still trigger completions based on alphanumeric input.
--- @return string[]
function source:get_trigger_characters()
	-- No explicit trigger characters - let blink.cmp handle keyword triggering
	-- Why: ':' and ';' are too aggressive (used in TypeScript syntax)
	-- blink.cmp automatically triggers on alphanumeric input, which is sufficient
	return {}
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

	-- Fast path: Check if cursor is in CSS context (with caching)
	-- This early return prevents expensive operations when not in styled-component templates
	if not self:is_in_css_context(bufnr, row, col) then
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
