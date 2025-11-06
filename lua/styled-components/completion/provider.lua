--- LSP Completion Provider for CSS
--- Handles requesting completions from cssls for virtual CSS documents
local util = require("styled-components.util")

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

	-- Create temporary scratch buffer with virtual CSS content
	local scratch_buf = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
	vim.bo[scratch_buf].filetype = "css"

	-- Set virtual content in scratch buffer
	local lines = vim.split(virtual_content, "\n")
	vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, lines)

	-- Create URI for scratch buffer
	local scratch_uri = vim.uri_from_bufnr(scratch_buf)

	-- Notify cssls about the virtual document
	client.notify("textDocument/didOpen", {
		textDocument = {
			uri = scratch_uri,
			languageId = "css",
			version = 1,
			text = virtual_content,
		},
	})

	-- Prepare LSP completion params for the scratch buffer
	local params = {
		textDocument = {
			uri = scratch_uri,
		},
		position = {
			line = row,
			character = col,
		},
		context = {
			triggerKind = 1, -- Invoked
		},
	}

	-- Send completion request
	local success, request_id = client.request("textDocument/completion", params, function(err, result)
		-- Cleanup: notify close and delete scratch buffer
		client.notify("textDocument/didClose", {
			textDocument = {
				uri = scratch_uri,
			},
		})
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(scratch_buf) then
				vim.api.nvim_buf_delete(scratch_buf, { force = true })
			end
		end)

		if err then
			util.notify("[styled-components] cssls completion error: " .. vim.inspect(err), vim.log.levels.WARN)
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
	end, scratch_buf)

	if not success then
		-- Cleanup on failure
		client.notify("textDocument/didClose", {
			textDocument = {
				uri = scratch_uri,
			},
		})
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(scratch_buf) then
				vim.api.nvim_buf_delete(scratch_buf, { force = true })
			end
		end)
		callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
	end

	-- Return cancel function
	return function()
		if request_id then
			client.cancel_request(request_id)
		end
		-- Cleanup on cancel
		client.notify("textDocument/didClose", {
			textDocument = {
				uri = scratch_uri,
			},
		})
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(scratch_buf) then
				vim.api.nvim_buf_delete(scratch_buf, { force = true })
			end
		end)
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

	-- IMPORTANT: Remove textEdit because it has positions from virtual CSS buffer
	-- Let blink.cmp handle insertion at current cursor position
	-- Use insertText or label instead
	if lsp_item.textEdit and lsp_item.textEdit.newText then
		item.insertText = lsp_item.textEdit.newText
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
