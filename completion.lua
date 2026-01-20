local M = {}

local ollama = require("llm-copilot.ollama")
local ui = require("llm-copilot.ui")
local config = require("llm-copilot.config")

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
    
    -- Get files in current directory
    local files = {}
    local cwd = vim.fn.getcwd()
    
    -- Use vim.fn.glob to get files (no subdirectories)
    local file_list = vim.fn.glob(cwd .. "/*", false, true)
    
    for _, filepath in ipairs(file_list) do
        -- Get just the filename, not full path
        local filename = vim.fn.fnamemodify(filepath, ":t")
        -- Filter out directories (only include files)
        if vim.fn.isdirectory(filepath) == 0 then
            table.insert(files, filename)
        end
    end
    
    return {
        file_content = file_content,
        cursor = {
            line = cursor[1],  -- 1-based
            col = cursor[2],   -- 0-based
        },
        filetype = filetype,
        files = files,
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
    
    -- Build prompt
    local prompt = ollama.build_prompt(context)
    
    if config.get().debug then
        vim.notify("Requesting completion...", vim.log.levels.INFO)
    end
    
    -- Get current cursor position for showing suggestion
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    
    -- Request completion from Ollama
    ollama.request_completion(config.get(), prompt, function(err, response)
        -- Mark request as complete
        current_request.active = false
        current_request.bufnr = nil
        
        if err then
            vim.notify("LLM Copilot error: " .. err, vim.log.levels.ERROR)
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
        
        -- Show suggestion as ghost text
        ui.show_suggestion(bufnr, cursor_pos[1], cursor_pos[2], response)
        
        if config.get().debug then
            vim.notify("Suggestion displayed", vim.log.levels.INFO)
        end
    end)
end

-- Cancel any in-flight request
function M.cancel_request()
    if current_request.active then
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
