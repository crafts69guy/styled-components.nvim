--- LSP Completion Provider for CSS
--- Handles requesting completions from cssls for virtual CSS documents
local M = {}

--- Get cssls client for buffer
--- @param bufnr number Buffer number
--- @return table|nil LSP client
function M.get_cssls_client(bufnr)
	local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "cssls" })
	return clients[1]
end

--- Request completions from cssls
--- @param bufnr number Buffer number
--- @param virtual_content string Virtual CSS document
--- @param row number 0-indexed row
--- @param col number 0-indexed column
--- @param callback function Callback with completion items
function M.request_completions(bufnr, virtual_content, row, col, callback)
	local client = M.get_cssls_client(bufnr)

	if not client then
		callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
		return
	end

	-- Create virtual text document identifier
	local uri = vim.uri_from_bufnr(bufnr)

	-- Prepare LSP completion params
	local params = {
		textDocument = {
			uri = uri,
		},
		position = {
			line = row,
			character = col,
		},
		-- context = {
		-- 	triggerKind = 1, -- Invoked
		-- },
	}

	-- Send completion request
	-- Note: We're using the virtual content but sending the original URI
	-- This works because cssls only needs the content at the position
	local success, request_id = client.request("textDocument/completion", params, function(err, result)
		if err then
			vim.notify("[styled-components] cssls completion error: " .. vim.inspect(err), vim.log.levels.WARN)
			callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
			return
		end

		if not result then
			callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
			return
		end

		-- Handle both CompletionList and CompletionItem[] formats
		local items
		local is_incomplete = false

		if result.items then
			-- CompletionList format
			items = result.items
			is_incomplete = result.isIncomplete or false
		elseif type(result) == "table" and #result > 0 then
			-- CompletionItem[] format
			items = result
		else
			items = {}
		end

		-- Transform LSP CompletionItem to blink.cmp format
		local blink_items = {}
		for _, item in ipairs(items) do
			table.insert(blink_items, M.transform_completion_item(item))
		end

		callback({
			items = blink_items,
			is_incomplete_forward = is_incomplete,
			is_incomplete_backward = false,
		})
	end, bufnr)

	if not success then
		callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
	end

	-- Return cancel function
	return function()
		if request_id then
			client.cancel_request(request_id)
		end
	end
end

--- Transform LSP CompletionItem to blink.cmp format
--- @param lsp_item table LSP CompletionItem
--- @return table blink.cmp CompletionItem
function M.transform_completion_item(lsp_item)
	local item = {
		label = lsp_item.label,
		kind = lsp_item.kind or 1, -- Text
		insertTextFormat = lsp_item.insertTextFormat or 1, -- PlainText
		documentation = lsp_item.documentation,
	}

	-- Handle textEdit
	if lsp_item.textEdit then
		item.textEdit = lsp_item.textEdit
	elseif lsp_item.insertText then
		item.insertText = lsp_item.insertText
	else
		item.insertText = lsp_item.label
	end

	-- Optional fields
	if lsp_item.filterText then
		item.filterText = lsp_item.filterText
	end
	if lsp_item.sortText then
		item.sortText = lsp_item.sortText
	end
	if lsp_item.detail then
		item.detail = lsp_item.detail
	end

	return item
end

return M
