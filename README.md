# Squire

A simple on-demand AI powered code completion plugin for Neovim. 
Run AI code completion only when and where you want it, with minimial token and context usage.

Supports Anthropic Claude out of the box, can be customized for other LLM's

## Requirements

- Neovim ≥ 0.10 (uses `vim.uv`)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- `SQUIRE_LLM_API_KEY` set in your environment

## Installation

```lua
-- lazy.nvim
{
  "jibinjacob09/squire.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "VeryLazy",
  config = function()
    require("squire").setup({})
  end,
}
```

The `config` block is required — `:SquireComplete` and the default keymaps are only registered when `setup()` runs.

## Usage

1. Place the cursor where you want a completion
2. Press `<C-Space>` (or run `:SquireComplete`)
3. The suggestion renders as gray ghost text; `<Tab>` accepts, `<Esc>` dismisses


## Configuration

```lua
require("squire").setup({
  provider    = "anthropic",                          -- registered in provider.lua
  api_key     = os.getenv("SQUIRE_LLM_API_KEY"),
  model       = "claude-sonnet-4-20250514",
  temperature = 0.2,                                  -- 0–2
  max_tokens  = 2000,
  timeout_ms  = 15000,

  keymaps = {
    manual  = "<C-Space>",                            -- trigger
    accept  = "<Tab>",                                -- accept active suggestion
    dismiss = "<Esc>",                                -- dismiss active suggestion
  },

  trigger_filetypes = {                               -- filetypes where Squire is active
    "python", "javascript", "typescript", "lua", "go",
    "rust", "c", "cpp", "java", "ruby", "php", "html",
    "css", "json", "yaml", "markdown", "vim", "sh",
    "bash", "zsh",
  },

  debug = false,                                      -- verbose vim.notify output
})
```

## Troubleshooting

**`<C-Space>` does nothing.** Most terminals send Ctrl-Space as `<C-@>` / `<Nul>`. Add a fallback:

```lua
vim.keymap.set({ "i", "n" }, "<C-@>", "<Cmd>SquireComplete<CR>", { silent = true })
```

**Nothing happens at all.** Run `:SquireHealthcheck` — it sends a one-token ping and reports whether the API key and network path are working.

## License

MIT

