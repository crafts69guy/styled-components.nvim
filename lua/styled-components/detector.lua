local M = {}

-- Cache for performance
local cache = {
	is_styled_import = {},
	styled_patterns = nil,
}

-- Patterns to detect styled-components
function M.get_styled_patterns()
	if cache.styled_patterns then
		return cache.styled_patterns
	end

	cache.styled_patterns = {
		-- styled.div``, styled(Component)``
		"styled%s*%.%s*%w+%s*`",
		"styled%s*%(.*%)%s*`",
		-- const Component = styled.div``
		"=%s*styled%s*%.%s*%w+%s*`",
		"=%s*styled%s*%(.*%)%s*`",
		-- css`` from styled-components
		"css%s*`",
	}

	return cache.styled_patterns
end

-- Check if buffer has styled-components import
function M.has_styled_import(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if cache.is_styled_import[bufnr] ~= nil then
		return cache.is_styled_import[bufnr]
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 50, false)

	for _, line in ipairs(lines) do
		if
			line:match("from%s+[\"']styled%-components[\"']")
			or line:match("require%s*%([\"']styled%-components[\"']%)")
		then
			cache.is_styled_import[bufnr] = true
			return true
		end
	end

	cache.is_styled_import[bufnr] = false
	return false
end

-- Check if cursor is inside styled-components template literal
function M.is_in_styled_template()
	local bufnr = vim.api.nvim_get_current_buf()

	-- Check if treesitter parser exists
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok or not parser then
		return false
	end

	-- Get node at cursor using Neovim's built-in API
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })
	if not node then
		return false
	end

	-- Walk up the tree to find template_string
	while node do
		local node_type = node:type()

		-- Check if we're in a template string
		if node_type == "template_string" or node_type == "string_fragment" then
			-- Check parent context for styled-components
			local parent = node:parent()
			while parent do
				local parent_type = parent:type()
				local ok_text, parent_text = pcall(vim.treesitter.get_node_text, parent, bufnr)

				if ok_text then
					-- Check for styled.div``, styled(Component)``, css``
					if parent_type == "call_expression" or parent_type == "tagged_template_expression" then
						if
							parent_text:match("styled%.%w+")
							or parent_text:match("styled%(")
							or parent_text:match("css`")
						then
							return true
						end
					end
				end

				parent = parent:parent()
			end

			return false
		end

		node = node:parent()
	end

	return false
end

-- Get the CSS context at cursor (property name or value)
function M.get_css_context()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2]

	local before_cursor = line:sub(1, col)
	local after_cursor = line:sub(col + 1)

	-- Check if we're after a colon (value context)
	local property_match = before_cursor:match("([%w%-]+)%s*:%s*[^;]*$")
	if property_match then
		return "value", property_match
	end

	-- Check if we're before a colon (property context)
	if before_cursor:match("%s*[%w%-]*$") and after_cursor:match("^[%w%-]*%s*:") then
		return "property", nil
	end

	-- Default to property context if on a new line or after semicolon
	if before_cursor:match("[;%s]*[%w%-]*$") then
		return "property", nil
	end

	return "property", nil
end

-- Clear cache for a buffer
function M.clear_cache(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	cache.is_styled_import[bufnr] = nil
end

-- Setup autocmds to clear cache
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup("StyledComponentsCache", { clear = true })

	vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged" }, {
		group = group,
		callback = function(ev)
			M.clear_cache(ev.buf)
		end,
	})
end

return M
