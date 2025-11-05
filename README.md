# styled-components.nvim

A high-performance Neovim plugin providing CSS autocompletion for styled-components in React projects. Built specifically for LazyVim and blink.cmp.

## Features

- 🚀 **Fast & Efficient**: Optimized with caching and lazy loading
- 🎯 **Smart Detection**: Automatically detects styled-components usage with TreeSitter
- 💡 **CSS Completions**: Full CSS property and value suggestions
- 🎨 **Context-Aware**: Different completions for properties vs values
- ⚡ **blink.cmp Integration**: Native support for blink.cmp completion engine

## Requirements

- Neovim >= 0.10.0 (tested on 0.11.4)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with JavaScript/TypeScript parser
- [blink.cmp](https://github.com/saghen/blink.cmp)

**Note**: This plugin uses Neovim's built-in TreeSitter API (no `nvim-treesitter.ts_utils` dependency).

## Installation

### Lazy.nvim (LazyVim)

```lua
{
  "yourusername/styled-components.nvim",
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  config = function()
    require("styled-components").setup({
      enabled = true,
      debug = false, -- Set to true for debugging
    })
  end,
}
```

### Configure blink.cmp

Add the styled-components source to your blink.cmp configuration:

```lua
{
  "saghen/blink.cmp",
  opts = {
    sources = {
      providers = {
        styled_components = {
          name = "styled-components",
          module = "styled-components.blink_source",
          score_offset = 10, -- Higher priority for styled-components suggestions
        },
      },
      -- Add to completion sources
      completion = {
        enabled_providers = { "lsp", "path", "snippets", "buffer", "styled_components" },
      },
    },
  },
}
```

## Usage

The plugin automatically activates when:

1. You're in a TypeScript/JavaScript file
2. The file imports `styled-components`
3. Your cursor is inside a styled-components template literal

### Example

```typescript
import styled from 'styled-components';

const Button = styled.button`
  dis|  // Type 'dis' and get 'display' suggestion
  display: f|  // Type 'f' and get 'flex', 'flexbox', etc.
  flex-direction: |  // Get 'row', 'column', etc.
`;
```

## Configuration

```lua
require("styled-components").setup({
  enabled = true,      -- Enable/disable the plugin
  debug = false,       -- Show debug messages
  filetypes = {        -- Supported filetypes
    "typescript",
    "typescriptreact",
    "javascript",
    "javascriptreact",
  },
})
```

## Performance

- **Lazy Loading**: Only loads when needed
- **Caching**: Caches styled-components detection per buffer
- **Optimized Data**: Uses a curated subset of CSS properties for fast completions
- **TreeSitter**: Efficient syntax detection

## Troubleshooting

### No completions showing

1. Ensure blink.cmp is configured correctly with the styled-components source
2. Check if the file has `import styled from 'styled-components'`
3. Verify TreeSitter parser is installed: `:TSInstall typescript tsx`
4. Enable debug mode to see logs: `debug = true`

### Performance issues

- The plugin is designed to be lightweight
- If experiencing slowdowns, check TreeSitter is up to date
- Report issues with debug logs enabled

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT
