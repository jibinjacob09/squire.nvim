local M = {}

local provider_registry = {
    anthropic = "squire.providers.anthropic",
    ollama    = "squire.providers.ollama",
}

-- Validate provider-specific options (light validation)
function M.validate_provider_opts(provider, opts)
    if provider == "ollama" and not opts.base_url then
        vim.notify("Ollama: base_url is required", vim.log.levels.WARN)
    end
end

-- Resolve a provider module by name
-- @param name string|nil: Provider name (defaults to "anthropic")
-- @return table: Provider module implementing complete(config, prompt_text, callback)
function M.get(name)
    name = name or "anthropic"
    local modpath = provider_registry[name]
    if not modpath then
        error("squire: unknown provider: ", tostring(name))
    end
    return require(modpath)
end

return M
