# Squire

A Neovim plugin that provides AI-powered code completion using a local LLM (Ollama). Get intelligent, context-aware code suggestions displayed as inline ghost text.

## Features

- 🤖 **Local LLM Integration** - Connect to your own Ollama instance for privacy and control
- 👻 **Ghost Text Suggestions** - Non-intrusive inline suggestions in gray text
- ⌨️ **Simple Keybindings** - Tab to accept, Esc to dismiss
- 🎯 **Manual Trigger** - Request completions when you need them
- 🔧 **Fully Configurable** - Customize model, endpoint, keymaps, and more
- 📁 **Context-Aware** - Sends file content, cursor position, and directory context to LLM

## Requirements

- Neovim >= 0.8.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Ollama running locally (or accessible endpoint)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  dir = "~/.config/nvim/dev/code-copilot",  -- Adjust to your path
  name = "squire",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "VeryLazy",
  config = function()
    require("squire").setup({
      -- Optional: override defaults
      model = "devstral",
      endpoint = "http://localhost:9000",
    })
  end
}
```

## Usage

1. Position your cursor where you want code completion
2. Press `<Ctrl-Space>` (or your configured trigger key)
3. Wait for gray ghost text to appear with the suggestion
4. Press `Tab` to accept the suggestion or `Esc` to dismiss

### Example

```python
def calculate_fibonacci(n):
    # Press Ctrl-Space here
    |
```

After triggering, you'll see a gray ghost text suggestion that you can accept with Tab.

## Configuration

### Default Configuration

```lua
require("squire").setup({
  -- Ollama settings
  model = "devstral",
  endpoint = "http://localhost:9000",
  temperature = 0.2,
  max_tokens = 200,
  timeout_ms = 15000,

  -- Keymaps
  keymaps = {
    manual = "<C-Space>",  -- Trigger completion
    accept = "<Tab>",      -- Accept suggestion
    dismiss = "<Esc>",     -- Dismiss suggestion
  },

  -- File types where the plugin is active
  trigger_filetypes = {
    "python", "javascript", "typescript", "lua", "go", 
    "rust", "c", "cpp", "java", "ruby", "php", "html", 
    "css", "json", "yaml", "markdown", "vim", "sh", 
    "bash", "zsh",
  },

  -- Debug mode (shows notifications)
  debug = false,
})
```

### Configurable Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `model` | string | `"devstral"` | Ollama model name |
| `endpoint` | string | `"http://localhost:9000"` | Ollama API endpoint |
| `temperature` | number | `0.2` | LLM temperature (0-2) |
| `max_tokens` | number | `200` | Maximum tokens in completion |
| `timeout_ms` | number | `15000` | Request timeout in milliseconds |
| `keymaps.manual` | string | `"<C-Space>"` | Key to trigger completion |
| `keymaps.accept` | string | `"<Tab>"` | Key to accept suggestion |
| `keymaps.dismiss` | string | `"<Esc>"` | Key to dismiss suggestion |
| `trigger_filetypes` | table | See above | List of enabled filetypes |
| `debug` | boolean | `false` | Enable debug notifications |

### Example: Custom Configuration

```lua
require("squire").setup({
  model = "codellama:13b",
  endpoint = "http://localhost:11434",
  temperature = 0.3,
  keymaps = {
    manual = "<Leader><Space>",  -- Use leader + space
    accept = "<C-y>",            -- Use Ctrl-y to accept
  },
  debug = true,  -- See what's happening
})
```

## Commands

### Lua Functions

You can call these functions directly from Lua:

```vim
:lua require("squire").trigger_completion()
:lua require("squire").accept_suggestion()
:lua require("squire").dismiss_suggestion()
:lua require("squire").has_suggestion()
:lua require("squire").cancel()
```

### Creating Custom Commands

Add to your config:

```lua
vim.api.nvim_create_user_command("Squire", function()
  require("squire").trigger_completion()
end, { desc = "Trigger code completion" })
```

Then use `:Squire` to trigger completions.

## Default Keymaps

| Mode | Key | Action |
|------|-----|--------|
| Normal/Insert | `<C-Space>` | Trigger completion manually |
| Normal/Insert | `<Tab>` | Accept current suggestion |
| Normal/Insert | `<Esc>` | Dismiss current suggestion |

**Note:** Accept and dismiss keymaps only work when a suggestion is active. Otherwise, they behave normally.

## How It Works

1. **Trigger**: You manually trigger a completion request
2. **Context Gathering**: Plugin collects:
   - Full file content
   - Cursor position
   - Current filetype
   - Files in current directory
3. **LLM Request**: Sends context to your Ollama endpoint with a structured prompt
4. **Display**: Shows response as gray ghost text inline
5. **Accept/Dismiss**: Tab inserts the suggestion, Esc clears it

## Troubleshooting

### No suggestions appearing

1. Check Ollama is running: `curl http://localhost:9000/api/generate`
2. Enable debug mode: `debug = true` in setup
3. Check `:messages` for error logs

### Keymaps not working

1. Verify no conflicts: `:verbose imap <Tab>`
2. Try custom keymaps if defaults conflict
3. Check if plugin is loaded: `:lua print(vim.inspect(require("squire")))`

### Suggestions include markdown code fences

The plugin automatically strips `` ```language `` fences. If you still see them, make sure you're using the latest version.

## License

MIT

## Contributing

This is a personal plugin, but feel free to fork and customize for your own use!
