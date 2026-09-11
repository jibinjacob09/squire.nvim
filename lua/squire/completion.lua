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

-- Global state for auto-trigger (not buffer-local)
local auto_trigger_state = {
    timer = nil,
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
    
    -- Also cancel auto-trigger timer if started
    if auto_trigger_state.timer then
        auto_trigger_state.timer:close()
        auto_trigger_state.timer = nil
    end
end

-- Check if a request is currently active
-- @return boolean: True if request is in progress
function M.is_requesting()
    return current_request.active
end

-- Start the debounce timer for auto-trigger
local function start_debounce_timer()
    local cfg = config.get()
    
    -- Close existing timer if any
    if auto_trigger_state.timer then
        auto_trigger_state.timer:close()
        auto_trigger_state.timer = nil
    end
    
    local callback = vim.schedule_wrap(function()
        if not current_request.active then
            M.request_completion()
        end
    end)
    
    auto_trigger_state.timer = vim.uv.new_timer()
    auto_trigger_state.timer:start(
        cfg.debounce_ms,
        -1,
        callback
    )
end

-- Filter out navigation and edit keys that shouldn't trigger completions
local function is_typing_key(char)
    -- Navigation keys: hjkl, arrows, home, end, page up/down, etc.
    if char == "k" or char == "j" or char == "h" or char == "l" then return false end
    if char:match("^<up>$") or char:match("^<down>$") or char:match("^<left>$") or char:match("^<right>$") then return false end
    if char:match("^<home>$") or char:match("^<end>$") or char:match("^<pageup>$") or char:match("^<pagedown>$") then return false end
    
    -- Delete/Backspace keys - these are technically typing but we'll let them through for natural deletion behavior
    if char == "<BS>" or char == "<Del>" then return true end
    
    -- Control+Key combinations to be safe
    if char:match("^<c-") then return false end
    
    -- Allow everything else (alphanumeric and most special keys)
    return true
end

-- Handle keypress event for auto-trigger
local function handle_keypress(char)
    local cfg = config.get()
    
    -- Skip if manual trigger or auto-trigger disabled
    if not cfg.auto_trigger then
        return false
    end
    
    -- Filter out non-typing keys (navigation, control combinations)
    if not is_typing_key(char) then
        return false
    end
    
    -- Check comment prefix (only if configured and char has content)
    local trimmed_char = vim.trim(char) or ""
    if cfg.comment_prefixes and trimmed_char ~= "" then
        local first_char = trimmed_char:sub(1, 1)
        for _, prefix in ipairs(cfg.comment_prefixes) do
            if first_char == prefix then
                return false -- skip triggering on comment-start chars
            end
        end
    end
    
    -- Reset last key timestamp and start/reset debounce timer
    start_debounce_timer()
    
    return true
end

-- Setup autocmds for auto-trigger registration
function M.setup_autocmds()
    local group = vim.api.nvim_create_augroup("SquireAutoTrigger", { clear = false })
    
    -- Track which buffers have been registered (to avoid duplicate autocmds)
    M._buffer_ids_with_autotriggers = {}
    
    -- Start debounce timer on InsertEnter
    vim.api.nvim_create_autocmd("InsertEnter", {
        group = group,
        callback = function(args)
            local bufnr = args.buf
            
            -- Skip if buffer already has autocmds registered
            for _, id in ipairs(M._buffer_ids_with_autotriggers) do
                if id == args.buf then return end
            end
            
            table.insert(M._buffer_ids_with_autotriggers, bufnr)
            
            -- Only enable if in a supported filetype
            if not config.is_enabled_filetype() then return end
            
            -- Register InsertLeave handler for this buffer
            vim.api.nvim_create_autocmd("InsertLeave", {
                group = group,
                buffer = bufnr,
                callback = function()
                    M.cancel_request()
                end,
                desc = "Cancel Squire request on insert leave",
            })
            
            -- Register InsertCharPre handler for this buffer
            vim.api.nvim_create_autocmd("InsertCharPre", {
                group = group,
                buffer = bufnr,
                callback = function(event)
                    local char = vim.api.nvim_replace_termcodes(event.data or "", true, false, true)
                    
                    if handle_keypress(char) then
                        -- Key was typed, return true to allow it through
                        return true
                    end
                    
                    -- Skip this keystroke (comment prefix matched) - still return true
                    return true
                end,
                desc = "Handle character input for Squire auto-trigger",
            })
        end,
        desc = "Start Squire auto-trigger on insert enter",
    })
end

return M
