local M = {}

local providers = {
    anthropic = "squire.providers.anthropic",
    -- ollama = "squire.providers.ollama",
    -- openai = "squire.providers.openai",
}

-- Resolve a provider module by name
-- @param name string|nil: Provider name (defaults to "anthropic")
-- @return table: Provider module implementing complete(config, prompt_text, system_text, callback)
function M.get(name)
    name = name or "anthropic"
    local modpath = providers[name]
    if not modpath then
        error("squire: unknown provider: " .. tostring(name))
    end
    return require(modpath)
end

return M
