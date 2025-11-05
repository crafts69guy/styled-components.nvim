local css_data = require("styled-components.css_data")
local detector = require("styled-components.detector")
local main = require("styled-components")

-- Cache CompletionItemKind for performance
local CompletionItemKind = nil

local function get_completion_item_kind()
	if not CompletionItemKind then
		local ok, types = pcall(require, "blink.cmp.types")
		if ok then
			CompletionItemKind = types.CompletionItemKind
		else
			-- Fallback to LSP CompletionItemKind values
			CompletionItemKind = {
				Property = 10,
				Value = 12,
				Color = 16,
				Unit = 11,
			}
		end
	end
	return CompletionItemKind
end

---@class StyledComponentsSource
local Source = {}

function Source.new()
	local self = setmetatable({}, { __index = Source })
	return self
end

function Source:get_trigger_characters()
	return { ":", "-", " " }
end

function Source:should_show_items(context)
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.bo[bufnr].filetype

	-- Check if filetype is supported
	local supported = false
	for _, ft in ipairs(main.config.filetypes) do
		if ft == filetype then
			supported = true
			break
		end
	end

	if not supported then
		return false
	end

	-- Check if buffer has styled-components import
	if not detector.has_styled_import(bufnr) then
		return false
	end

	-- Check if cursor is inside styled template
	if not detector.is_in_styled_template() then
		return false
	end

	return true
end

function Source:get_completions(context, callback)
	if not self:should_show_items(context) then
		callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
		return
	end

	local items = {}
	local css_context, property_name = detector.get_css_context()
	local kind = get_completion_item_kind()

	main.log("CSS context: " .. css_context .. ", property: " .. tostring(property_name))

	if css_context == "property" then
		-- Provide CSS property completions
		for _, prop in ipairs(css_data.properties) do
			table.insert(items, {
				label = prop,
				kind = kind.Property,
				insertText = prop .. ": ",
				documentation = "CSS property: " .. prop,
				sortText = "0" .. prop,
			})
		end
	elseif css_context == "value" and property_name then
		-- Provide values for the specific property
		local values = css_data.values[property_name] or {}

		for _, value in ipairs(values) do
			table.insert(items, {
				label = value,
				kind = kind.Value,
				insertText = value,
				documentation = "Value for " .. property_name,
				sortText = "0" .. value,
			})
		end

		-- Add color keywords for color-related properties
		if property_name:match("color") or property_name:match("background") or property_name:match("border") then
			for _, color in ipairs(css_data.colors) do
				table.insert(items, {
					label = color,
					kind = kind.Color,
					insertText = color,
					documentation = "Color: " .. color,
					sortText = "1" .. color,
				})
			end
		end

		-- Add units for size-related properties
		if
			property_name:match("width")
			or property_name:match("height")
			or property_name:match("size")
			or property_name:match("margin")
			or property_name:match("padding")
			or property_name:match("top")
			or property_name:match("right")
			or property_name:match("bottom")
			or property_name:match("left")
		then
			for _, unit in ipairs(css_data.units) do
				table.insert(items, {
					label = "0" .. unit,
					kind = kind.Unit,
					insertText = unit,
					documentation = "CSS unit: " .. unit,
					sortText = "2" .. unit,
				})
			end
		end
	end

	callback({
		is_incomplete_forward = false,
		is_incomplete_backward = false,
		items = items,
	})
end

return Source

