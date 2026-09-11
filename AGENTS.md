# Squire.nvim Setup Notes

## Core Commands

```bash
# Validate LLM connection (required first step)
:lua vim.notify(require("squire").setup{}, 1)  -- initialize then run healthcheck
:SquireHealthcheck
```

## Key Quirks

- `<C-Space>` often sends `<C-@>` / `<Nul>`. If trigger doesn't work, add fallback:
  ```lua
  vim.keymap.set({ "i", "n" }, "<C-@>", "<Cmd>SquireComplete<CR>", { silent = true })
  ```

## Configuration Order

1. Set `SQUIRE_LLM_API_KEY` environment variable
2. Call `require("squire").setup(cfg)` to register keymaps and commands
3. Trigger completion via `<leader><space>` or `:SquireComplete`

## Architecture

- `lua/squire/init.lua`: Plugin orchestrator (keymaps, autocomplete)
- `lua/squire/config.lua`: Defaults, validation, filetype gating
- `lua/squire/provider.lua`: Provider registry (currently only Anthropic)
- `lua/squire/providers/anthropic.lua`: HTTP client to Anthropic API via plenary.curl

## Healthcheck Flow

```
:SquireHealthcheck → checks api_key → pings model with 1-token request → reports OK/FAIL
```
