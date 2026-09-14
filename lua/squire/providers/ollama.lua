local M = {}

-- Default to localhost:11434 if no base_url provided
local DEFAULT_BASE_URL = "http://localhost:11434"

function M.complete(cfg, prompt_text, system_prompt, callback)
    -- cfg contains merged options from root-level + provider_options
    vim.validate({
        cfg          = { cfg, "table" },
        prompt_text  = { prompt_text, "string" },
        system_prompt = { system_prompt, "string", true }, -- optional
        callback     = { callback, "function" },
    })

    local url = (cfg.base_url or DEFAULT_BASE_URL) .. "/api/generate"

    -- Determine model name (prefer model_name if set, else model as generic fallback)
    local model = cfg.model_name or cfg.model or "qwen2.5-coder"

    -- Build request body for Ollama API.
    local request_body = {
        model  = model,
        prompt = prompt_text,
        system = system_prompt,  -- nil is fine; Ollama omits it from JSON
        stream = false,          -- avoid NDJSON streaming; we want one JSON object back
        options = {
            temperature = cfg.temperature or 0.2,
            num_predict = cfg.max_tokens or 200,
            top_p       = cfg.top_p or 0.9,
            stop        = cfg.stop or nil
        },
    }

    local curl = require("plenary.curl")
    local headers = { ["Content-Type"] = "application/json" }

    -- Guard against any code path calling the callback more than once
    -- (defensive; plenary shouldn't double-fire, but this makes it a no-op if it ever does)
    local done = false
    local function finish(err, result)
        if done then return end
        done = true
        callback(err, result)
    end

    curl.post(url, {
        body    = vim.fn.json_encode(request_body),
        headers = headers,                      -- Ollama doesn't require auth for local use
        timeout = cfg.timeout_ms or 15000,
        callback = function(response)
            -- plenary.curl callbacks run off Neovim's main loop; hop back before
            -- touching vim.* APIs or buffers downstream.
            vim.schedule(function()
                local status = response.status

                -- Try to decode regardless of status; error bodies are JSON too.
                local ok, decoded = pcall(vim.fn.json_decode, response.body)

                if status < 200 or status >= 300 then
                    local msg
                    if ok and type(decoded) == "table" and decoded.error then
                        msg = decoded.error
                    else
                        msg = response.body ~= "" and response.body or "no response body"
                    end
                    finish("Ollama: HTTP " .. status .. " - " .. tostring(msg), nil)
                    return
                end

                if not ok or type(decoded) ~= "table" then
                    finish("Ollama: could not parse JSON response - " .. tostring(decoded), nil)
                    return
                end

                if decoded.response == nil then
                    finish("Ollama: response missing 'response' field", nil)
                    return
                end

                finish(nil, decoded.response)
            end)
        end,
        on_error = function(err)
            vim.schedule(function()
                finish("Ollama: request failed - " .. tostring(err), nil)
            end)
        end,
    })
end

return M
