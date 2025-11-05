# Local Testing Guide

Hướng dẫn test plugin locally trước khi push lên GitHub.

## 🚀 Quick Test (Recommended)

### Cách 1: Dùng test script

```bash
cd /Users/caongoccuong/Workspaces/Personal/Development/styled-components.nvim

# Run test environment
./test.sh
```

**Kết quả:**
- Neovim mở với test config
- Plugin tự động load từ local directory
- Test file `test/example.tsx` được mở
- Status information hiển thị

### Cách 2: Manual command

```bash
nvim -u test/init_test.lua test/example.tsx
```

---

## 📋 Test Checklist

Khi test environment mở, verify:

### 1. Plugin Loaded

```vim
:lua require("styled-components").print_status()
```

**Should show:**
```lua
{
  enabled = true,
  auto_setup = true,
  injection_available = true,
  injection_active = true,  -- If cursor in template
  injected_language = "css",  -- If cursor in template
}
```

### 2. TreeSitter Injection

Move cursor to styled template:

```tsx
const Button = styled.div`
  display: flex;  ← Move cursor here
`;
```

Press `<leader>t` (or `:InspectTree`)

**Should see:** `(string_fragment)` nodes with language "css"

### 3. LSP Attached

```vim
:LspInfo
```

**Should show:**
- `cssls` client attached
- Filetypes include: `typescriptreact`

### 4. CSS Completions

In styled template, type:
```
dis<Ctrl-Space>
```

**Should see:**
- `display`
- `display-inside`
- `display-list-item`
- etc.

### 5. Hover Documentation

Move cursor to `display` and press `K`

**Should see:** MDN documentation in floating window

### 6. Diagnostics

Add a typo:
```tsx
const Box = styled.div`
  colr: red;  // Typo!
`;
```

**Should see:** Error underline or diagnostic message

---

## 🔧 Integration với Neovim Config Hiện Tại

Nếu bạn muốn test với Neovim config hiện tại (không dùng test config):

### Option 1: Lazy.nvim (Temporary)

Edit plugin config của bạn:

```lua
-- ~/.config/nvim/lua/plugins/styled-components.lua

{
  -- Comment out GitHub URL, use local path
  -- "crafts69guy/styled-components.nvim",
  dir = "/Users/caongoccuong/Workspaces/Personal/Development/styled-components.nvim",

  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "neovim/nvim-lspconfig",  -- Optional for Neovim 0.11+
  },

  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },

  opts = {
    debug = true,  -- Enable debug logging
  },
}
```

Sau đó:

```vim
:Lazy reload styled-components
# hoặc
:Lazy sync
```

### Option 2: Runtimepath (Manual)

Thêm vào `init.lua`:

```lua
-- Before loading plugins
vim.opt.runtimepath:prepend("/Users/caongoccuong/Workspaces/Personal/Development/styled-components.nvim")
```

---

## 🐛 Debugging

### Check Injection Queries Loaded

```vim
:lua print(vim.inspect(vim.treesitter.query.get("typescript", "injections")))
```

Should show queries with `styled`, `css`, etc.

### Check Runtimepath

```vim
:set runtimepath?
```

Should include plugin directory.

### View Plugin Logs

With `debug = true`:

```vim
:messages
```

Should show:
```
[styled-components] TreeSitter injection queries loaded successfully
[styled-components] cssls configured for filetypes: ...
```

### Manual Test Commands

```vim
" Check injection available
:lua print(require("styled-components.injection").is_injection_available())

" Check injection active
:lua print(require("styled-components.injection").is_injection_active())

" Get injected language at cursor
:lua print(require("styled-components.injection").get_injected_language_at_pos(0, vim.fn.line(".")-1, vim.fn.col(".")-1))

" Full status
:lua require("styled-components").print_status()
```

---

## 📝 Making Changes

Khi bạn edit plugin code:

### 1. Reload Plugin

**If using test script:**
```bash
# Exit Neovim (`:q`)
# Run again
./test.sh
```

**If using lazy.nvim:**
```vim
:Lazy reload styled-components
```

**If using manual runtimepath:**
```vim
" Reload modules
:lua package.loaded["styled-components"] = nil
:lua package.loaded["styled-components.injection"] = nil
:lua require("styled-components").setup({ debug = true })
```

### 2. Test Changes

Repeat test checklist above.

---

## ✅ Ready to Push

Khi mọi test pass:

1. **Remove test config from your Neovim:**

```lua
-- Change back to GitHub URL
{
  "crafts69guy/styled-components.nvim",  -- Not `dir`
  -- ...
}
```

2. **Commit changes:**

```bash
git add .
git commit -m "feat: treesitter injection architecture"
git push origin main
```

3. **Test from GitHub:**

```vim
:Lazy sync
```

Plugin sẽ download từ GitHub và hoạt động giống như local!

---

## 🎯 Test Scenarios

### Basic Test

```tsx
import styled from 'styled-components';

const Button = styled.div`
  display: flex;  // Test completion here
`;
```

### Advanced Test

```tsx
import styled, { css, createGlobalStyle, keyframes } from 'styled-components';

// Test: styled.element
const Box = styled.div`
  color: red;
`;

// Test: styled(Component)
const StyledButton = styled(Button)`
  background: blue;
`;

// Test: css helper
const styles = css`
  margin: 10px;
`;

// Test: createGlobalStyle
const Global = createGlobalStyle`
  body { margin: 0; }
`;

// Test: keyframes
const fadeIn = keyframes`
  from { opacity: 0; }
  to { opacity: 1; }
`;
```

---

## 🔍 Common Issues

### "Plugin not found"

Check path is correct:
```bash
ls /Users/caongoccuong/Workspaces/Personal/Development/styled-components.nvim
```

### "No completions"

1. Check cssls installed: `:!which vscode-css-language-server`
2. Check LSP attached: `:LspInfo`
3. Check injection active: `:lua require("styled-components").is_injection_working()`

### "TreeSitter errors"

Install parsers:
```vim
:TSInstall typescript tsx javascript css
:TSUpdate
```

---

## 💡 Pro Tips

1. **Use debug mode** during testing:
   ```lua
   opts = { debug = true }
   ```

2. **Check status frequently:**
   ```vim
   :lua require("styled-components").print_status()
   ```

3. **Use `:InspectTree`** to verify injection:
   - Should see `css` language nodes in templates

4. **Test all patterns:**
   - `styled.div`
   - `styled(Component)`
   - `css``
   - `createGlobalStyle``
   - `keyframes``

5. **Watch `:messages`** for errors

---

## 📚 Resources

- [README.md](./README.md) - Full documentation
- [QUICKSTART.md](./QUICKSTART.md) - 2-minute setup
- [CLAUDE.md](./CLAUDE.md) - Architecture details

Happy testing! 🎉
