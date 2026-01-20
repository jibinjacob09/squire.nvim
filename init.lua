local M = {}

local config = require("llm-copilot.config")
local completion = require("llm-copilot.completion")
local ui = require("llm-copilot.ui")

-- Track if plugin has been setup
local is_setup = false

-- Setup the plugin
-- @param user_config table|nil: User configuration
function M.setup(user_config)
    if is_setup then
        vim.notify("llm-copilot is already setup", vim.log.levels.WARN)
        return
    end

    -- Initialize configuration
    config.setup(user_config)

    -- Setup keymaps and autocmds
    M.setup_keymaps()
    M.setup_autocmds()

    is_setup = true

    if config.get().debug then
        vim.notify("llm-copilot initialized successfully", vim.log.levels.INFO)
    end

    -- Create user command for manual triggering
    vim.api.nvim_create_user_command("LLMCopilotTrigger", function()
        M.trigger_completion()
    end, {
        desc = "Manually trigger LLM Copilot completion"
    })
end

-- Setup global keymaps for manual trigger
function M.setup_keymaps()
    local cfg = config.get()
    local manual_key = cfg.keymaps.manual or "<leader><space>"

    -- Manual trigger in insert mode
    vim.keymap.set("i", manual_key, function()
        M.trigger_completion()
        return ""
    end, {
        expr = true,
        noremap = true,
        silent = true,
        desc = "LLM Copilot: Trigger completion"
    })

    -- Manual trigger in normal mode
    vim.keymap.set("n", manual_key, function()
        M.trigger_completion()
    end, {
        noremap = true,
        silent = true,
        desc = "LLM Copilot: Trigger completion"
    })
end

-- Setup autocmds for buffer-specific keymaps
function M.setup_autocmds()
    local group = vim.api.nvim_create_augroup("LLMCopilot", { clear = true })

    -- Setup accept/dismiss keymaps when entering a buffer
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        group = group,
        callback = function(args)
            local bufnr = args.buf

            -- Setup UI keymaps (Tab/Esc) for this buffer
            ui.setup_keymaps(bufnr, config.get())
        end,
        desc = "Setup LLM Copilot keymaps for buffer"
    })

    -- Clear suggestions when leaving insert mode
    vim.api.nvim_create_autocmd("InsertLeave", {
        group = group,
        callback = function()
            ui.clear_suggestion()
        end,
        desc = "Clear LLM Copilot suggestions on insert leave"
    })

    -- Clear suggestions when buffer is closed
    vim.api.nvim_create_autocmd("BufDelete", {
        group = group,
        callback = function(args)
            ui.clear_suggestion(args.buf)
        end,
        desc = "Clear LLM Copilot suggestions on buffer delete"
    })
end

-- Trigger completion manually
function M.trigger_completion()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Check if already requesting
    if completion.is_requesting() then
        if config.get().debug then
            vim.notify("Completion request already in progress", vim.log.levels.DEBUG)
        end
        return
    end

    -- Request completion
    completion.request_completion(bufnr)
end

-- Accept current suggestion (exposed for custom keymaps)
function M.accept_suggestion()
    return ui.accept_suggestion()
end

-- Dismiss current suggestion (exposed for custom keymaps)
function M.dismiss_suggestion()
    ui.clear_suggestion()
end

-- Check if there's an active suggestion
function M.has_suggestion()
    return ui.has_suggestion()
end

-- Cancel any in-flight request
function M.cancel()
    completion.cancel_request()
end

-- Get current configuration
function M.get_config()
    return config.get()
end

return M
