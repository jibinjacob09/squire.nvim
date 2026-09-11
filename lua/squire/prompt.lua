local M = {}

local SYSTEM_PROMPT = "You are an accurate, efficent code completion engine. Output ONLY the raw code to be inserted at the cursor. No explanations, no markdown fences, no commentary — just the code. Avoid importing unneeded libraries, prioritze efficent but readable code."

-- Default FIM-style template for Ollama models like qwen2.5-coder
-- Uses triple-quoted strings (FIM format) with cursor marker
-- @param before string: Context before cursor
-- @param after string: Context after cursor
-- @return string: Formatted prompt ready for Ollama API
function M.default_fim_template(before, after)
    return '"""' .. before .. '"""' .. '"""' .. after .. '"""\n\n'
end

-- Strip markdown code fences from response
-- @param text string: Raw response from LLM
-- @return string: Cleaned response
function M.strip_code_fences(text)
    text = text:gsub("^%s*```%w*\n", "")
    text = text:gsub("\n```%s*$", "")
    text = text:gsub("```%s*$", "")
    return text
end

-- Return the system prompt shared across all providers
-- @return string
function M.system_prompt()
    return SYSTEM_PROMPT
end

-- Build the user prompt to send to an LLM
-- @param context table: Contains lines_before, lines_after, filetype
-- @param cfg table|nil: Optional config with optional prompt_template function
-- @return string: The formatted prompt
function M.build_prompt(context, cfg)
    local custom_template = cfg and cfg.prompt_template

    if custom_template and type(custom_template) == "function" then
        return custom_template(
            context.lines_before or "",
            context.lines_after or ""
        )
    end

    -- Use default FIM template (pure FIM format for Ollama)
    return M.default_fim_template(context.lines_before, context.lines_after)
end

return M