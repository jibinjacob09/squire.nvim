local M = {}

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
    }
  }
  
  -- Make async POST request
  curl.post(url, {
    body = vim.fn.json_encode(body),
    headers = {
      ["Content-Type"] = "application/json",
    },
    timeout = config.timeout_ms or 5000,
    callback = function(response)
      -- Handle response on main thread
      vim.schedule(function()
        if response.status ~= 200 then
          callback("HTTP error: " .. response.status, nil)
          return
        end
        
        -- Parse JSON response
        local ok, decoded = pcall(vim.fn.json_decode, response.body)
        if not ok then
          callback("Failed to parse JSON response", nil)
          return
        end
        
        -- Extract completion text
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
-- @param context table: Contains file_content, cursor, filetype, files
-- @return string: The formatted prompt
function M.build_prompt(context)
  local cursor_line = context.cursor.line
  local cursor_col = context.cursor.col
  
  -- Split content into before and after cursor
  local lines = vim.split(context.file_content, "\n")
  local before_cursor = table.concat(vim.list_slice(lines, 1, cursor_line), "\n")
  
  -- Add the partial line up to cursor
  if cursor_line <= #lines then
    local current_line = lines[cursor_line]
    before_cursor = before_cursor .. "\n" .. string.sub(current_line, 1, cursor_col)
  end
  
  -- Build file list
  local file_list = ""
  if #context.files > 0 then
    file_list = "\nFiles in directory: " .. table.concat(context.files, ", ")
  end
  
  -- Construct the prompt
  local prompt = string.format([[You are a code completion assistant. Complete the code at the cursor position.

Language: %s%s

Code:
%s<CURSOR>

Instructions:
- Provide ONLY the code completion, no explanations
- Complete multiple lines if appropriate
- Match the existing code style and indentation
- Do not repeat code that's already written]], 
    context.filetype,
    file_list,
    before_cursor
  )
  
  return prompt
end

return M
