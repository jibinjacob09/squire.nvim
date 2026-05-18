local M = {}

-- Provider contract:
-- M.complete(config, prompt_text, system_text, callback)
--   callback(err, raw_response_text)
-- Returns raw model output; fence stripping is the orchestrator's job.

function M.complete(config, prompt_text, system_text, callback)
    local curl = require("plenary.curl")
    local url = "https://api.anthropic.com/v1/messages"

    local body = {
        model = config.model or "claude-sonnet-4-20250514",
        max_tokens = config.max_tokens or 200,
        temperature = config.temperature or 0.2,
        system = system_text,
        messages = {
            {
                role = "user",
                content = prompt_text,
            },
        },
    }

    curl.post(url, {
        body = vim.fn.json_encode(body),
        headers = {
            ["Content-Type"] = "application/json",
            ["x-api-key"] = config.api_key,
            ["anthropic-version"] = "2023-06-01",
        },
        timeout = config.timeout_ms or 15000,
        callback = function(response)
            vim.schedule(function()
                if response.status ~= 200 then
                    callback("HTTP error: " .. tostring(response.status) .. " — " .. tostring(response.body), nil)
                    return
                end

                local ok, decoded = pcall(vim.fn.json_decode, response.body)
                if not ok or type(decoded) ~= "table" then
                    callback("Failed to parse JSON response", nil)
                    return
                end

                local text = decoded.content
                    and decoded.content[1]
                    and decoded.content[1].text

                if text then
                    callback(nil, text)
                else
                    callback("No content in Anthropic response", nil)
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

return M
