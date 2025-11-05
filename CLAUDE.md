# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Neovim plugin that provides CSS autocompletion for styled-components in React projects. Built specifically for LazyVim and blink.cmp completion engine.

**Key Dependencies:**
- Neovim >= 0.10.0
- nvim-treesitter (with JS/TS parser)
- blink.cmp (completion engine)

## Architecture

### Core Components

1. **lua/styled-components/init.lua**
   - Main entry point with setup() function
   - Configuration management (enabled, debug, filetypes)
   - Debug logging utility

2. **lua/styled-components/detector.lua**
   - **Buffer import detection**: Caches whether buffer has `styled-components` import (checks first 50 lines)
   - **TreeSitter context detection**: Uses Neovim's built-in TreeSitter API to detect if cursor is inside a styled-components template literal
   - **CSS context parsing**: Determines if cursor is in property or value position
   - **Cache management**: Implements per-buffer caching with autocmds to clear on BufWritePost/TextChanged

3. **lua/styled-components/blink_source.lua**
   - blink.cmp completion source implementation
   - Returns different completions based on CSS context:
     - **Property context**: CSS properties with `: ` appended
     - **Value context**: Property-specific values, colors (for color properties), units (for size properties)
   - Uses sortText to control completion order (0=primary, 1=colors, 2=units)

4. **lua/styled-components/css_data.lua**
   - Static CSS property/value database
   - Curated subset for performance
   - Organized by category (Layout, Flexbox, Grid, Typography, Colors, etc.)

5. **plugin/styled-components.lua**
   - Plugin entry point (prevents double-loading)
   - Initializes cache management autocmds

### Data Flow

```
User types in styled-component template
    ↓
blink.cmp triggers Source:get_completions()
    ↓
detector.should_show_items() validates:
  1. Filetype supported? (js/ts/jsx/tsx)
  2. Has styled-components import? (cached)
  3. Cursor in template literal? (TreeSitter)
    ↓
detector.get_css_context() determines:
  - "property" context → return CSS properties
  - "value" context → return values for that property
    ↓
Return completions to blink.cmp
```

### TreeSitter Integration

Uses Neovim's **built-in TreeSitter API** (not nvim-treesitter.ts_utils):
- `vim.treesitter.get_parser()` - Get parser for buffer
- `vim.treesitter.get_node()` - Get node at cursor position
- `node:parent()` - Walk up AST tree
- Looks for `template_string` nodes within `call_expression` or `tagged_template_expression` containing `styled.` or `css`

## Development Commands

### Testing the Plugin Locally

1. **Load in Neovim:**
   ```bash
   nvim --cmd "set rtp+=." test-file.tsx
   ```

2. **Enable debug logging:**
   ```lua
   require("styled-components").setup({ debug = true })
   ```

3. **Check TreeSitter parser:**
   ```vim
   :TSInstall typescript tsx
   :checkhealth nvim-treesitter
   ```

4. **Test import detection:**
   ```vim
   :lua print(vim.inspect(require("styled-components.detector").has_styled_import(0)))
   ```

5. **Test template detection:**
   ```vim
   :lua print(require("styled-components.detector").is_in_styled_template())
   ```

6. **Test CSS context:**
   ```vim
   :lua print(vim.inspect(require("styled-components.detector").get_css_context()))
   ```

### Git Workflow

Main branch: `main`

Standard workflow:
```bash
git add .
git commit -m "feat: description"
git push origin main
```

## Key Implementation Details

### Performance Optimizations

1. **Lazy Loading**: Plugin only loads on JS/TS filetypes (`ft = { ... }` in lazy.nvim config)
2. **Import Caching**: styled-components import detection cached per buffer, cleared on write/change
3. **Pattern Caching**: Styled detection patterns cached globally
4. **Curated CSS Data**: Limited to commonly-used properties vs. full CSS spec
5. **Early Returns**: Completion source returns empty immediately if not in valid context

### Detection Patterns

The plugin recognizes these patterns as styled-components:
- `styled.div```, `styled.button```
- `styled(Component)```
- `css```
- Variable assignments: `= styled.div```

### CSS Context Detection Logic

Uses simple regex on current line:
- **Value context**: If line has `property-name: ...` before cursor
- **Property context**: If line doesn't match value context, assumes property

Returns `("value", property_name)` or `("property", nil)`

### blink.cmp Integration

The plugin registers as a blink.cmp source:
```lua
{
  name = "styled-components",
  module = "styled-components.blink_source",
  score_offset = 10,  -- Prioritize over buffer source
}
```

CompletionItemKind fallback values if blink types unavailable:
- Property = 10
- Value = 12
- Color = 16
- Unit = 11

## Common Issues

### No Completions Showing
1. Verify blink.cmp configuration includes `styled_components` in `enabled_providers`
2. Check buffer has styled-components import in first 50 lines
3. Verify cursor is inside template literal (use debug commands above)
4. Ensure TreeSitter parser installed: `:TSInstall typescript tsx`

### Cache Not Updating
- Cache clears on BufWritePost and TextChanged events
- Manual clear: `:lua require("styled-components.detector").clear_cache()`

### TreeSitter Errors
- Plugin requires Neovim's built-in TreeSitter (v0.10+)
- Does NOT use nvim-treesitter.ts_utils (removed in newer versions)
