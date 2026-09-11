# Squire

A simple on-demand AI powered code completion plugin for Neovim. 
Run AI code completion only when and where you want it, with minimal token and context usage.

Supports Anthropic Claude out of the box and Ollama (local inference).


## Requirements

- Neovim ≥ 0.10 (uses `vim.uv`)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- For Anthropic: set `SQUIRE_LLM_API_KEY` environment variable
- For Ollama: local server running via `ollama serve --server-port 11434`


## Installation

```lua
-- lazy.nvim
{
  "jibinjacob09/squire.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "VeryLazy",
  config = function()
    require("squire").setup({} -- or pass your config here
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
  provider            = "anthropic",                  -- or "ollama"

  -- Anthropic-specific fields (required when using Anthropic)
  api_key             = os.getenv("SQUIRE_LLM_API_KEY"),
  model               = "claude-sonnet-4-6",
  
  -- Ollama-specific fields (used only when provider == "ollama")
  base_url            = "http://localhost:11434",    -- or your remote Ollama server URL
  model_name          = "qwen2.5-coder:latest",      -- model to use, e.g., "qwen2.5-coder:latest"
  
  -- Shared fields used by both providers
  temperature         = 0.2,                          -- 0–2 (or higher for some Ollama models)
  max_tokens          = 2000,                         -- tokens to generate / num_predict for Ollama
  timeout_ms          = 15000,                        -- request timeout in milliseconds

  keymaps = {
    manual   = "<C-Space>",                            -- trigger
    accept   = "<Tab>",                                -- accept active suggestion
    dismiss  = "<Esc>",                                -- dismiss active suggestion
  },

  trigger_filetypes = {                               -- filetypes where Squire is active
    "python", "javascript", "typescript", "lua", "go",
    "rust", "c", "cpp", "java", "ruby", "php", "html",
    "css", "json", "yaml", "markdown", "vim", "sh",
    "bash", "zsh",
  },

  debug               = false,                                  -- verbose vim.notify output
  
  -- Auto-trigger settings (experimental)
  auto_trigger        = true,                                   -- enable automatic completion on typing
  debounce_ms         = 300,                                    -- wait 300ms after last keystroke before triggering
  comment_prefixes    = {},                                      -- skip triggering when line starts with these chars
  
  -- Code context limit for prompt
  max_lines           = 40,                                     -- maximum lines of code to include in request
  
  provider_options     = {},                                    -- merged per provider (Ollama params below)
})
```

### Provider Options

Use `provider_options` to pass provider-specific configuration fields:

#### Anthropic Provider

Anthropic parameters are typically passed via root-level config fields. If you need additional options that aren't exposed at the top level, add them here:

```lua
require("squire").setup({
  provider    = "anthropic",
  api_key     = os.getenv("SQUIRE_LLM_API_KEY"),
  model       = "claude-sonnet-4-6",
  
  provider_options = {                                      -- additional Anthropic options here if needed
    -- e.g. custom headers, extra body fields, etc.
  },
})
```

#### Ollama Provider

Use `provider` set to `"ollama"` and include the following under `provider_options`:

- `base_url`: (optional) Ollama server URL, defaults to `http://localhost:11434`
- `model_name`: model to use (required for Ollama, e.g., `"qwen2.5-coder"` or just `"qwen-coder"`)
- `temperature`: (0–2) controls randomness; higher values are more creative
- `max_tokens`: maps to Ollama's `num_predict`, the number of tokens to generate
- `top_p`: nucleus sampling threshold (default 0.9 if omitted)
- `stop`: array of stop sequence strings that terminate generation (e.g., `["\[END"]`)
- `prompt_template`: function taking `(lines_before, lines_after)` that returns a formatted prompt string—useful for models requiring FIM-style prompts

Example using the Qwen2.5 coder model with automatic prompt template:

```lua
require("squire").setup({
  provider     = "ollama",
  
  -- Basic Ollama setup (all required and shared params in root, extras here)
  api_key      = nil,  -- not needed for local Ollama server
  
  model_name   = "qwen2.5-coder:latest",
  base_url     = "http://localhost:11434",
  temperature  = 0.8,
  
  provider_options = {                                      -- optional additional fields
    top_k       = 40,                                       -- explore more diverse completions
    num_ctx     = 8192,                                     -- context window size
    -- custom template function (optional):
    prompt_template = function(before, after)               -- FIM-style example for Qwen Coder
      return '"""' .. before .. '"""' .. '"""' .. after .. '\"""',
    end,
  },
})
```

Note: Each Ollama model may require its own `prompt_template` function. Experiment and adjust as needed for your preferred models.


## Usage Examples

### Auto-trigger completion on typing

By default, completions trigger automatically when you finish typing for 300ms:

- Only fires in insert mode while typing content
- Skips navigation keys (`h`, `j`, `k`, `l`, arrows) and most control keys
- Resets the debounce timer on each new keystroke
- Disabled for lines starting with configured comment prefixes

### Disable auto-trigger

```lua
require("squire").setup({
  auto_trigger = false,                               -- rely on manual trigger only
})
```

### Skip certain comments or code patterns

```lua
require("squire").setup({
  comment_prefixes = { "#", "//", "--" },              -- skip triggering when line starts with these
})
```

### Limit context to fewer lines

```lua
require("squire").setup({
  max_lines = 40,                                      -- truncate prompt to 40 lines of context
})
```


## Troubleshooting

**`<C-Space>` does nothing.** Most terminals send Ctrl-Space as `<C-@>` / `<Nul>`. Add a fallback:

```lua
vim.keymap.set({ "i", "n" }, "<C-@>", "<Cmd>SquireComplete<CR>", { silent = true })
```

**Nothing happens at all.** Run `:SquireHealthcheck` — it sends a one-token ping and reports whether the API key and network path are working for Anthropic. For Ollama, ensure your local server is running via `ollama serve`.


## License

MIT
