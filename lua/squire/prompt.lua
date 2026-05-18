local M = {}

local SYSTEM_PROMPT = "You are an accurate, efficent code completion engine. Output ONLY the raw code to be inserted at the cursor. No explanations, no markdown fences, no commentary — just the code. Avoid importing unneeded libraries, prioritze efficent but readable code."

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
        [[Complete the code at the <CURSOR> position.

Language: %s
Current indentation: "%s"

Rules:
- Output ONLY the code to insert at <CURSOR> — nothing before it
- Do NOT repeat any code that already exists, before or after the cursor
- Match the surrounding code style and conventions
- Preserve the current indentation level
- You may complete multiple lines if the context calls for it
- if the instruction is to write docstring,  then analyze the function where the cursor is and write only docstring,  NO code
- if the instruction is to write tests for a specific function, then
- 1. list out the appropriate test cases suitable for the function
- 2. automate the listed test case using the appropriate testing framework (pytest, jest, cypress, etc,)

Code:
%s<CURSOR>]],
        context.filetype or "text",
        indent:gsub("\t", "\\t"),
        before_cursor
    )

    return prompt
end

return M
