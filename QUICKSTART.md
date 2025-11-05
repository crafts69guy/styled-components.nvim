# Quick Start Guide

Get CSS completions in styled-components in **under 2 minutes**!

## ⚡ Installation

### 1. Install CSS Language Server

```bash
npm install -g vscode-langservers-extracted
```

### 2. Install Plugin (lazy.nvim)

**For Neovim 0.11+ (Native LSP):**

```lua
{
  "crafts69guy/styled-components.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    -- nvim-lspconfig is optional for Neovim 0.11+
  },
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  opts = {},  -- Use default config
}
```

**For Neovim 0.10.x:**

```lua
{
  "crafts69guy/styled-components.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "neovim/nvim-lspconfig",  -- Required for 0.10.x
  },
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  opts = {},  -- Use default config
}
```

### 3. Done! 🎉

Plugin auto-configures everything. Just reload Neovim.

## 🧪 Test It

Create `test.tsx`:

```tsx
import styled from 'styled-components';

const Button = styled.div`
  dis    ← Type here and trigger completion (Ctrl+Space)
`;
```

You should see:
- `display`
- `display-inside`
- `display-list-item`
- etc.

## ✨ Features You Get

### Completions

```tsx
const Box = styled.div`
  dis        → display, display-inside, ...
  display: f  → flex, flow-root, ...
  color:      → CSS colors, values, ...
`;
```

### Hover Documentation

```tsx
const Box = styled.div`
  display: flex;
  ^^^^^^^
  Press K here → See MDN documentation!
`;
```

### Diagnostics (Errors)

```tsx
const Box = styled.div`
  colr: red;     // ← Error: Unknown property 'colr'
  display: flexxx; // ← Error: Invalid value 'flexxx'
`;
```

## 🐛 Troubleshooting

### No completions?

**Check cssls installed:**

```vim
:!which vscode-css-language-server
```

Should show path. If not found, run step 1 again.

**Check LSP attached:**

```vim
:LspInfo
```

Should show `cssls` client attached.

**Check TreeSitter:**

```vim
:TSInstall typescript tsx
```

### Still not working?

**Debug mode:**

```lua
require("styled-components").setup({ debug = true })
```

**Check status:**

```vim
:lua require("styled-components").print_status()
```

Should show:

```lua
{
  injection_available = true,
  injection_active = true,
  injected_language = "css",  -- When cursor in template
}
```

If `injection_available = false`:

- Check Neovim version: `:version` (need 0.10+)
- Update TreeSitter: `:TSUpdate`

If `injection_active = false`:

- Make sure you're in a `.tsx` or `.ts` file
- Check you have `import styled from 'styled-components'`
- Place cursor INSIDE template literal

## 📖 Supported Patterns

All these work automatically:

```tsx
// styled.element
const Box = styled.div`...`;

// styled(Component)
const Styled = styled(Button)`...`;

// css helper
const styles = css`...`;

// createGlobalStyle
const Global = createGlobalStyle`...`;

// keyframes
const fadeIn = keyframes`...`;
```

## ⚙️ Configuration (Optional)

Default config works for 99% of users. To customize:

```lua
require("styled-components").setup({
  enabled = true,
  debug = false,
  auto_setup = true,
  cssls_config = {
    settings = {
      css = {
        validate = true,
        lint = {
          unknownAtRules = "ignore",
          vendorPrefix = "warning",
        },
      },
    },
  },
})
```

## 🚀 That's It!

You now have **native CSS LSP** in styled-components!

- Same experience as .css files
- Full CSS completions from cssls
- Hover documentation
- Diagnostics for errors
- Zero configuration needed

Enjoy! 🎉

## 📚 Learn More

- [README.md](./README.md) - Full documentation
- [CLAUDE.md](./CLAUDE.md) - Architecture details
- [VS_CODE_COMPARISON.md](./VS_CODE_COMPARISON.md) - How it compares

## 💬 Need Help?

Create an issue: https://github.com/crafts69guy/styled-components.nvim/issues
