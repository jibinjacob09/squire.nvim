local M = {}

-- Default configuration
M.defaults = {
    -- Ollama settings
    model = "devstralCoPilot",
    endpoint = "http://localhost:11434",
    temperature = 0.2,
    max_tokens = 200,
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
    -- Check endpoint format
    if not M.options.endpoint:match("^https?://") then
        vim.notify(
            "code-copilot: endpoint must start with http:// or https://",
            vim.log.levels.WARN
        )
    end

    -- Check timeout is reasonable
    if M.options.timeout_ms < 1000 then
        vim.notify(
            "code-copilot: timeout_ms is very low, may cause issues",
            vim.log.levels.WARN
        )
    end

    -- Check temperature range
    if M.options.temperature < 0 or M.options.temperature > 2 then
        vim.notify(
            "code-copilot: temperature should be between 0 and 2",
            vim.log.levels.WARN
        )
    end

    -- Ensure trigger_filetypes is a table
    if type(M.options.trigger_filetypes) ~= "table" then
        vim.notify(
            "code-copilot: trigger_filetypes must be a table",
            vim.log.levels.ERROR
        )
        M.options.trigger_filetypes = M.defaults.trigger_filetypes
    end
end

-- Check if current filetype should have copilot enabled
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
