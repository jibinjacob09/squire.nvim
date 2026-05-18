local M = {}

local prompt = require("squire.prompt")
local provider = require("squire.provider")
local ui = require("squire.ui")
local config = require("squire.config")

-- State to track in-flight requests
local current_request = {
    active = false,
    bufnr = nil,
}

-- Gather context from current buffer
-- @param bufnr number: Buffer number
-- @return table: Context object with file_content, cursor, filetype, files
local function gather_context(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    
    -- Get all lines from buffer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local file_content = table.concat(lines, "\n")
    
    -- Get cursor position
    local cursor = vim.api.nvim_win_get_cursor(0)
    
    -- Get filetype
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

    return {
        file_content = file_content,
        cursor = {
            line = cursor[1],  -- 1-based
            col = cursor[2],   -- 0-based
        },
        filetype = filetype,
    }
end

-- Request completion from LLM
-- @param bufnr number|nil: Buffer number (defaults to current)
function M.request_completion(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    
    -- If there's already a request in flight, ignore
    if current_request.active then
        if config.get().debug then
            vim.notify("Request already in progress", vim.log.levels.DEBUG)
        end
        return
    end
    
    -- Clear any existing suggestion first
    ui.clear_suggestion(bufnr)
    
    -- Mark request as active
    current_request.active = true
    current_request.bufnr = bufnr

    -- Gather context
    local context = gather_context(bufnr)

    -- Build prompt + select provider
    local prompt_text = prompt.build_prompt(context)
    local system_text = prompt.system_prompt()
    local backend = provider.get(config.get().provider)

    if config.get().debug then
        vim.notify("Requesting completion...", vim.log.levels.INFO)
    end

    -- Get current cursor position for showing suggestion
    local cursor_pos = vim.api.nvim_win_get_cursor(0)

    -- Show in-flight indicator with estimated input tokens (~chars/4)
    local tokens_sent = math.ceil((#system_text + #prompt_text) / 4)
    ui.show_progress(bufnr, cursor_pos[1], cursor_pos[2], tokens_sent)

    backend.complete(config.get(), prompt_text, system_text, function(err, raw)
        -- Mark request as complete and clear the in-flight indicator
        current_request.active = false
        current_request.bufnr = nil
        ui.clear_progress(bufnr)

        if err then
            vim.notify("Squire error: " .. err, vim.log.levels.ERROR)
            return
        end

        -- Check if buffer is still valid and we're still in it
        if not vim.api.nvim_buf_is_valid(bufnr) then
            if config.get().debug then
                vim.notify("Buffer no longer valid", vim.log.levels.DEBUG)
            end
            return
        end

        if vim.api.nvim_get_current_buf() ~= bufnr then
            if config.get().debug then
                vim.notify("Switched buffers, ignoring response", vim.log.levels.DEBUG)
            end
            return
        end

        local cleaned = prompt.strip_code_fences(raw)
        ui.show_suggestion(bufnr, cursor_pos[1], cursor_pos[2], cleaned)

        if config.get().debug then
            vim.notify("Suggestion displayed", vim.log.levels.INFO)
        end
    end)
end

-- Cancel any in-flight request
function M.cancel_request()
    if current_request.active then
        ui.clear_progress(current_request.bufnr)
        current_request.active = false
        current_request.bufnr = nil

        if config.get().debug then
            vim.notify("Request cancelled", vim.log.levels.DEBUG)
        end
    end
end

-- Check if a request is currently active
-- @return boolean: True if request is in progress
function M.is_requesting()
    return current_request.active
end

return M
