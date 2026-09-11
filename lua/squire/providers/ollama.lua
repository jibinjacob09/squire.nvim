local M = {}

-- Default to localhost:11434 if no base_url provided
local DEFAULT_BASE_URL = "http://localhost:11434"

function M.complete(cfg, prompt_text)
    -- cfg contains merged options from root-level + provider_options
    -- Build request body for Ollama
    
    local url = cfg.base_url or DEFAULT_BASE_URL

    -- Determine model name (prefer model_name if set, else model as generic fallback)
    local model = cfg.model_name or cfg.model or "qwen2.5-coder"
    
    -- Build prompt (Ollama expects single string in "prompt" field)
    -- We've already truncated file_content in completion.lua
    
    -- Build request body for Ollama API
    local response_body = {
        model      = model,                             -- determined from cfg
        prompt     = prompt_text,                        -- pre-truncated content
        temperature= cfg.temperature or 0.8,             -- map from root config  
        max_tokens = cfg.max_tokens or 400,              -- Ollama's num_predict 
        top_p      = cfg.top_p or 0.9,                   -- from provider_options if available
        stop       = cfg.stop or nil,                    -- array of stop strings
    }

    local curl = require("plenary.curl")
    local headers = { ["Content-Type"] = "application/json" }

    curl.post(url, {  -- Ollama streaming is separate via /api/generate-stream, but we use /api/generate here
        body       = vim.fn.json_encode(response_body),
        headers    = headers,                                 -- Ollama API doesn't require auth for local use
        timeout    = cfg.timeout_ms or 15000,                 -- shared timeout setting
        callback   = function(response)                      -- handle response
            vim.schedule(function()                           -- run in next lua event loop iteration
                if response.status ~= 200 then
                    callback("Ollama: request failed or model not found", nil)
                    return
                end

                local ok, decoded = pcall(vim.fn.json_decode, response.body)
                if not ok or type(decoded) ~= "table" then
                    callback("Ollama: could not parse JSON response", nil)
                    return
                end

                -- Ollama returns {response: "actual completion text"}
                local raw_response = decoded.response
                
                if raw_response and raw_response ~= "" then
                    callback(nil, raw_response)
                else
                    callback("Ollama: empty or invalid response from model", nil)
                end
            end)
        end,
        on_error  = function(err)                             -- handle network failures etc.
            vim.schedule(function()                           -- run in next lua event loop iteration
                callback("Ollama: request failed: " .. tostring(err), nil)
            end)
        end,
    })
end

return M