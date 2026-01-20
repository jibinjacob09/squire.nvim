local M = {}

-- Namespace for virtual text
local ns_id = vim.api.nvim_create_namespace("llm_copilot_ghost")

-- State to track current suggestion
local current_suggestion = {
    text = nil,
    start_pos = nil, -- {row, col} where suggestion starts
}

-- Make async HTTP request to Ollama
-- @param config table: Plugin configuration
-- @param prompt string: The prompt to send to Ollama
-- @param callback function: Called with (err, response_text)
function M.request_completion(config, prompt, callback)
    local curl = require("plenary.curl")
    local url = config.endpoint .. "/api/generate"

    local body = {
        model = config.model,
        prompt = prompt,
        stream = false,
        options = {
            temperature = config.temperature or 0.2,
            num_predict = config.max_tokens or 200,
        },
    }

    curl.post(url, {
        body = vim.fn.json_encode(body),
        headers = {
            ["Content-Type"] = "application/json",
        },
        timeout = config.timeout_ms or 15000,
        callback = function(response)
            vim.schedule(function()
                if response.status ~= 200 then
                    callback("HTTP error: " .. tostring(response.status), nil)
                    return
                end

                local ok, decoded = pcall(vim.fn.json_decode, response.body)
                if not ok or type(decoded) ~= "table" then
                    callback("Failed to parse JSON response", nil)
                    return
                end

                if decoded.response then
                    callback(nil, decoded.response)
                else
                    callback("No response field in Ollama output", nil)
                end
            end)
        end,
        on_error = function(err)
            vim.schedule(function()
                callback("Request failed: " .. vim.inspect(err), nil)
            end)
        end,
    })
end

-- Build the prompt to send to Ollama
-- @param context table: Contains file_content, cursor, filetype
-- @return string: The formatted prompt
function M.build_prompt(context)
    local cursor_line = context.cursor.line
    local cursor_col = context.cursor.col or 0

    local lines = vim.split(context.file_content, "\n", { plain = true })

    local before_cursor = ""
    if cursor_line > 1 then
        before_cursor = table.concat(
            vim.list_slice(lines, 1, cursor_line - 1),
            "\n"
        )
    end

    local current_line = lines[cursor_line] or ""
    local col_1_based = math.max(cursor_col, 0)
    local current_prefix = string.sub(current_line, 1, col_1_based)

    if before_cursor ~= "" then
        before_cursor = before_cursor .. "\n" .. current_prefix
    else
        before_cursor = current_prefix
    end

    local indent = current_prefix:match("^%s*") or ""

    local prompt = string.format(
        [[You are a code completion engine.
Complete the code at the cursor position.

Language: %s

Rules:
- Output ONLY the code to be inserted
- Do NOT repeat existing code
- Match the surrounding style
- Maintain the current indentation
- You may complete multiple lines if appropriate

Current indentation: "%s"

Code:
%s<CURSOR>]],
        context.filetype or "text",
        indent:gsub("\t", "\\t"),
        before_cursor
    )

    return prompt
end

-- Show suggestion as ghost text (virtual text)
function M.show_suggestion(bufnr, row, col, text)
    -- Clear any existing suggestion first
    M.clear_suggestion(bufnr)

    local lines = vim.split(text, "\n", { plain = true })
    
    -- Store suggestion state
    current_suggestion.text = lines
    current_suggestion.start_pos = {row, col}

    -- Show first line as virtual text at cursor position
    if lines[1] and lines[1] ~= "" then
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, row - 1, col, {
            virt_text = {{lines[1], "Comment"}},
            virt_text_pos = "overlay",
            hl_mode = "combine",
        })
    end

    -- Show remaining lines as virtual lines below
    for i = 2, #lines do
        if lines[i] and lines[i] ~= "" then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, row - 1, 0, {
                virt_lines = {{{lines[i], "Comment"}}},
                virt_lines_above = false,
            })
        end
    end
end

-- Clear ghost text suggestion
function M.clear_suggestion(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr or 0, ns_id, 0, -1)
    current_suggestion.text = nil
    current_suggestion.start_pos = nil
end

-- Accept suggestion and write to buffer
function M.accept_suggestion()
    if not current_suggestion.text or not current_suggestion.start_pos then
        return false
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local row, col = unpack(current_suggestion.start_pos)
    local lines = current_suggestion.text

    -- Insert first line at cursor
    vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, {lines[1]})

    -- Insert remaining lines below
    if #lines > 1 then
        vim.api.nvim_buf_set_lines(bufnr, row, row, false, vim.list_slice(lines, 2, #lines))
    end

    -- Move cursor to end of insertion
    local final_row = row + #lines - 1
    local final_col = #lines[#lines]
    if #lines == 1 then
        final_col = col + #lines[1]
    end
    vim.api.nvim_win_set_cursor(0, {final_row, final_col})

    -- Clear the suggestion
    M.clear_suggestion(bufnr)
    return true
end

-- Setup keymaps for accepting/dismissing suggestions
function M.setup_suggestion_keymaps(bufnr)
    -- Tab to accept (both normal and insert mode)
    vim.keymap.set("i", "<Tab>", function()
        if M.accept_suggestion() then
            return "" -- Accepted, do nothing else
        else
            return "<Tab>" -- No suggestion, use default Tab
        end
    end, {
        buffer = bufnr,
        expr = true,
        noremap = true,
        silent = true,
    })
    
    vim.keymap.set("n", "<Tab>", function()
        if M.accept_suggestion() then
            -- After accepting, enter insert mode at end of insertion
            vim.cmd("startinsert!")
        end
    end, {
        buffer = bufnr,
        noremap = true,
        silent = true,
    })

    -- Esc to dismiss (both modes)
    vim.keymap.set("i", "<Esc>", function()
        M.clear_suggestion(bufnr)
        return "<Esc>"
    end, {
        buffer = bufnr,
        expr = true,
        noremap = true,
        silent = true,
    })
    
    vim.keymap.set("n", "<Esc>", function()
        M.clear_suggestion(bufnr)
    end, {
        buffer = bufnr,
        noremap = true,
        silent = true,
    })
end

-- Test config
local test_config = {
    endpoint = "http://100.108.68.116:11434",
    model = "devstralCoPilot",
    temperature = 0.2,
    max_tokens = 200,
    timeout_ms = 15000,
}

-- Test command
vim.api.nvim_create_user_command("CopilotDevstralTest", function()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local file_content = table.concat(lines, "\n")
    local cursor = vim.api.nvim_win_get_cursor(0)

    local context = {
        file_content = file_content,
        cursor = {
            line = cursor[1],
            col = cursor[2],
        },
        filetype = vim.bo.filetype,
    }

    -- Setup keymaps for this buffer
    M.setup_suggestion_keymaps(buf)

    local prompt = M.build_prompt(context)
    
    vim.notify("Sending request to Ollama...", vim.log.levels.INFO)
    
    M.request_completion(test_config, prompt, function(err, res)
        if err then
            vim.notify("Error: " .. err, vim.log.levels.ERROR)
            return
        end

        vim.notify("Got response, showing as suggestion", vim.log.levels.INFO)

        -- Show as ghost text
        vim.schedule(function()
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            M.show_suggestion(buf, row, col, res)
        end)
    end)
end, {})

return M
