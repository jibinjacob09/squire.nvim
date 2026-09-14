local M = {}

-- Default configuration
M.defaults = {
	-- LLM provider — must match a key in squire.provider's registry
	provider = "anthropic",

	-- Claude settings
	api_key = os.getenv("SQUIRE_LLM_API_KEY"),
	model = "claude-sonnet-4-6",
	timeout_ms = 15000,

	-- Keymaps
	keymaps = {
		manual = "<C-Space>", -- Manual trigger
		accept = "<Tab>", -- Accept suggestion
		dismiss = "<Esc>", -- Dismiss suggestion
	},

	-- File types where manual trigger is enabled
	-- (we're skipping auto-trigger for now)
	trigger_filetypes = {
		"python",
		"javascript",
		"typescript",
		"lua",
		"go",
		"rust",
		"c",
		"cpp",
		"java",
		"ruby",
		"php",
		"html",
		"css",
		"json",
		"yaml",
		"markdown",
		"vim",
		"sh",
		"bash",
		"zsh",
	},

  -- Debug mode
  debug = false,

  -- Auto-trigger settings
  auto_trigger = false,
  debounce_ms = 300,
  comment_prefixes = {}, -- e.g., { "#", "//", "--" } — empty by default (fire on everything)

  -- Code context limit for prompt
  max_lines = 40, -- maximum lines of code to include in completion request

  -- Provider-specific config overrides (merged per provider)
  provider_options = {
	temperature = 0.2,
	max_tokens = 2000,
    top_p = 0.9,
  },
}

-- Current active configuration
M.options = {}

-- Merge user config with defaults
function M.setup(user_config)
	user_config = user_config or {}

	-- Deep merge for nested tables like keymaps
	M.options = vim.tbl_deep_extend("force", M.defaults, user_config)

	-- Validate configuration
	M.validate()

	return M.options
end

-- Validate configuration values
function M.validate()
	-- Check timeout is reasonable
	if M.options.timeout_ms < 1000 then
		vim.notify("squire: timeout_ms is very low, may cause issues", vim.log.levels.WARN)
	end

	-- Check temperature range
	if M.options.temperature < 0 or M.options.temperature > 2 then
		vim.notify("squire: temperature should be between 0 and 2", vim.log.levels.WARN)
	end

	-- Ensure trigger_filetypes is a table
	if type(M.options.trigger_filetypes) ~= "table" then
		vim.notify("squire: trigger_filetypes must be a table", vim.log.levels.ERROR)
		M.options.trigger_filetypes = M.defaults.trigger_filetypes
	end

  -- Ensure max_lines is positive integer
  local ml = type(M.options.max_lines) == "number" and math.floor(M.options.max_lines) or 40
  if ml < 1 then
    vim.notify("squire: max_lines must be a positive integer", vim.log.levels.WARN)
  end

  -- Anthropic requires API key
  if M.options.provider == "anthropic" and (not M.options.api_key or M.options.api_key == "") then
    vim.notify("squire: SQUIRE_LLM_API_KEY is not set for Anthropic", vim.log.levels.WARN)
  end

  -- Ollama requires base_url and model/model_name  
  if M.options.provider == "ollama" then
    if not M.options.base_url then
      vim.notify("Ollama: base_url is required", vim.log.levels.WARN)
    end
    local ollama_model = M.options.model or M.options.model_name
    if not ollama_model then
      vim.notify("Ollama: model or model_name is required", vim.log.levels.WARN)
    end
  end
end

-- Check if current filetype should have squire enabled
function M.is_enabled_filetype(filetype)
	filetype = filetype or vim.bo.filetype

	-- Check if filetype is in the enabled list
	for _, ft in ipairs(M.options.trigger_filetypes) do
		if ft == filetype then
			return true
		end
	end

	return false
end

-- Get current config
function M.get()
	return M.options
end

return M
