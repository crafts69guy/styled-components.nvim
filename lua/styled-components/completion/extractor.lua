--- CSS Content Extractor
--- Extracts CSS content from styled-component template literals
--- Uses whitespace replacement trick (like VS Code) to preserve positions
local M = {}

--- Extract CSS region from buffer
--- @param bufnr number Buffer number
--- @param row number 0-indexed row
--- @param col number 0-indexed column
--- @return table|nil { content: string, start_line: number, start_col: number, end_line: number, end_col: number }
function M.extract_css_region(bufnr, row, col)
	-- Get TreeSitter parser
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok or not parser then
		return nil
	end

	-- Get node at cursor
	local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })
	if not node then
		return nil
	end

	-- Walk up to find string_fragment inside template_string
	local string_fragment = nil
	local current = node
	local depth = 0

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
		return nil
	end

	-- Verify this is a styled-component template
	local template_string = string_fragment:parent()
	if not template_string then
		return nil
	end

	local call_expr = template_string:parent()
	if not call_expr or call_expr:type() ~= "call_expression" then
		return nil
	end

	-- Check if this is styled.X`...` or css`...` or similar patterns
	local function_node = call_expr:child(0)
	if not function_node then
		return nil
	end

	local is_styled = false
	local func_type = function_node:type()

	if func_type == "member_expression" then
		-- styled.div`...`
		local object_node = function_node:child(0)
		if object_node and object_node:type() == "identifier" then
			local object_text = vim.treesitter.get_node_text(object_node, bufnr)
			if object_text == "styled" then
				is_styled = true
			end
		end
	elseif func_type == "identifier" then
		-- css`...` or createGlobalStyle`...` or keyframes`...`
		local func_text = vim.treesitter.get_node_text(function_node, bufnr)
		if func_text == "css" or func_text == "createGlobalStyle" or func_text == "keyframes" then
			is_styled = true
		end
	elseif func_type == "call_expression" then
		-- styled(Component)`...`
		local inner_func = function_node:child(0)
		if inner_func and inner_func:type() == "identifier" then
			local func_text = vim.treesitter.get_node_text(inner_func, bufnr)
			if func_text == "styled" then
				is_styled = true
			end
		end
	end

	if not is_styled then
		return nil
	end

	-- Get CSS content range
	local start_row, start_col, end_row, end_col = string_fragment:range()

	-- Extract CSS content
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
	if #lines == 0 then
		return nil
	end

	-- Handle single-line vs multi-line
	local content
	if start_row == end_row then
		content = lines[1]:sub(start_col + 1, end_col)
	else
		-- First line
		lines[1] = lines[1]:sub(start_col + 1)
		-- Last line
		lines[#lines] = lines[#lines]:sub(1, end_col)
		content = table.concat(lines, "\n")
	end

	return {
		content = content,
		start_line = start_row,
		start_col = start_col,
		end_line = end_row,
		end_col = end_col,
	}
end

--- Create virtual CSS document with whitespace replacement
--- This preserves line/column positions for LSP requests
--- @param bufnr number Buffer number
--- @param css_region table CSS region from extract_css_region()
--- @return string Virtual CSS document
function M.create_virtual_css_document(bufnr, css_region)
	-- Get all buffer lines
	local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Replace everything outside CSS region with whitespace
	local virtual_lines = {}

	for i, line in ipairs(all_lines) do
		local line_idx = i - 1 -- 0-indexed

		if line_idx < css_region.start_line or line_idx > css_region.end_line then
			-- Outside CSS region: replace with whitespace
			virtual_lines[i] = string.rep(" ", #line)
		elseif line_idx == css_region.start_line and line_idx == css_region.end_line then
			-- Single-line CSS
			local before = string.rep(" ", css_region.start_col)
			local css = line:sub(css_region.start_col + 1, css_region.end_col)
			local after = string.rep(" ", #line - css_region.end_col)
			virtual_lines[i] = before .. css .. after
		elseif line_idx == css_region.start_line then
			-- First line of multi-line CSS
			local before = string.rep(" ", css_region.start_col)
			local css = line:sub(css_region.start_col + 1)
			virtual_lines[i] = before .. css
		elseif line_idx == css_region.end_line then
			-- Last line of multi-line CSS
			local css = line:sub(1, css_region.end_col)
			local after = string.rep(" ", #line - css_region.end_col)
			virtual_lines[i] = css .. after
		else
			-- Middle lines: keep as is
			virtual_lines[i] = line
		end
	end

	return table.concat(virtual_lines, "\n")
end

return M
