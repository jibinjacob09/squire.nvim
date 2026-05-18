local M = {}

-- Namespace for virtual text
local ns_id = vim.api.nvim_create_namespace("squire-ghost")
local progress_ns = vim.api.nvim_create_namespace("squire-progress")

local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

-- State to track current suggestion
local current_suggestion = {
	text = nil, -- Array of lines
	start_pos = nil, -- {row, col} where suggestion starts (1-based row, 0-based col)
	bufnr = nil, -- Buffer number
}

local progress_state = {
	bufnr = nil,
	row = nil,
	col = nil,
	timer = nil,
	frame = 1,
	tokens_sent = 0,
}

local function render_progress()
	if not progress_state.bufnr or not vim.api.nvim_buf_is_valid(progress_state.bufnr) then
		return
	end
	local frame = SPINNER_FRAMES[progress_state.frame]
	local text = frame .. " Squire thinking... " .. progress_state.tokens_sent .. "↑ tkn"
	vim.api.nvim_buf_clear_namespace(progress_state.bufnr, progress_ns, 0, -1)
	vim.api.nvim_buf_set_extmark(progress_state.bufnr, progress_ns, progress_state.row - 1, 0, {
		virt_text = { { text, "Comment" } },
		virt_text_pos = "eol",
		hl_mode = "combine",
	})
end

-- Show in-flight progress indicator at end of line
-- @param bufnr number: Buffer number
-- @param row number: Row position (1-based)
-- @param col number: Column position (0-based) — kept for parity with show_suggestion
-- @param tokens_sent number: Estimated input tokens
function M.show_progress(bufnr, row, col, tokens_sent)
	M.clear_progress()

	progress_state.bufnr = bufnr
	progress_state.row = row
	progress_state.col = col
	progress_state.frame = 1
	progress_state.tokens_sent = tokens_sent or 0

	render_progress()

	local timer = vim.uv.new_timer()
	progress_state.timer = timer
	timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			progress_state.frame = (progress_state.frame % #SPINNER_FRAMES) + 1
			render_progress()
		end)
	)
end

-- Clear in-flight progress indicator
-- @param bufnr number|nil: Buffer number (defaults to the buffer where progress is showing)
function M.clear_progress(bufnr)
	if progress_state.timer then
		progress_state.timer:stop()
		if not progress_state.timer:is_closing() then
			progress_state.timer:close()
		end
		progress_state.timer = nil
	end

	local target = bufnr or progress_state.bufnr
	if target and vim.api.nvim_buf_is_valid(target) then
		vim.api.nvim_buf_clear_namespace(target, progress_ns, 0, -1)
	end

	progress_state.bufnr = nil
	progress_state.row = nil
	progress_state.col = nil
	progress_state.frame = 1
	progress_state.tokens_sent = 0
end

-- Show suggestion as ghost text (virtual text)
-- @param bufnr number: Buffer number
-- @param row number: Row position (1-based)
-- @param col number: Column position (0-based)
-- @param text string: Completion text (may contain newlines)
function M.show_suggestion(bufnr, row, col, text)
	-- Clear any in-flight progress indicator and any existing suggestion first
	M.clear_progress(bufnr)
	M.clear_suggestion()

	-- Split text into lines
	local lines = vim.split(text, "\n", { plain = true })

	-- Filter out empty strings but keep the structure
	local filtered_lines = {}
	for _, line in ipairs(lines) do
		table.insert(filtered_lines, line)
	end

	if #filtered_lines == 0 then
		return
	end

	-- Store suggestion state
	current_suggestion.text = filtered_lines
	current_suggestion.start_pos = { row, col }
	current_suggestion.bufnr = bufnr

	-- Show first line as inline virtual text at cursor position
	if filtered_lines[1] and filtered_lines[1] ~= "" then
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row - 1, col, {
			virt_text = { { filtered_lines[1], "Comment" } },
			virt_text_pos = "overlay",
			hl_mode = "combine",
		})
	end

	-- Show remaining lines as virtual lines below
	if #filtered_lines > 1 then
		for i = 2, #filtered_lines do
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, row - 1, 0, {
				virt_lines = { { { filtered_lines[i], "Comment" } } },
				virt_lines_above = false,
			})
		end
	end
end

-- Clear ghost text suggestion
-- @param bufnr number|nil: Buffer number (defaults to current suggestion's buffer)
function M.clear_suggestion(bufnr)
	bufnr = bufnr or current_suggestion.bufnr or vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	current_suggestion.text = nil
	current_suggestion.start_pos = nil
	current_suggestion.bufnr = nil
end

-- Check if there's an active suggestion
-- @return boolean: True if suggestion is active
function M.has_suggestion()
	return current_suggestion.text ~= nil
end

-- Get current suggestion data
-- @return table|nil: Current suggestion or nil
function M.get_suggestion()
	if not M.has_suggestion() then
		return nil
	end

	return {
		text = current_suggestion.text,
		start_pos = current_suggestion.start_pos,
		bufnr = current_suggestion.bufnr,
	}
end

-- Accept suggestion and write to buffer
-- @return boolean: True if suggestion was accepted, false otherwise
function M.accept_suggestion()
	if not M.has_suggestion() then
		return false
	end

	local bufnr = current_suggestion.bufnr
	local row, col = unpack(current_suggestion.start_pos)
	local lines = current_suggestion.text

	-- Ensure we're in the correct buffer
	if bufnr ~= vim.api.nvim_get_current_buf() then
		vim.notify("Suggestion is for a different buffer", vim.log.levels.WARN)
		M.clear_suggestion()
		return false
	end

	-- Insert first line at cursor position
	vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { lines[1] })

	-- Insert remaining lines below if multi-line
	if #lines > 1 then
		vim.api.nvim_buf_set_lines(bufnr, row, row, false, vim.list_slice(lines, 2, #lines))
	end

	-- Calculate final cursor position
	local final_row = row + #lines - 1
	local final_col

	if #lines == 1 then
		-- Single line: cursor goes to end of inserted text
		final_col = col + #lines[1]
	else
		-- Multi-line: cursor goes to end of last line
		final_col = #lines[#lines]
	end

	-- Move cursor to end of insertion
	vim.api.nvim_win_set_cursor(0, { final_row, final_col })

	-- Clear the suggestion
	M.clear_suggestion()

	return true
end

-- Setup keymaps for accepting/dismissing suggestions
-- @param bufnr number: Buffer number to set keymaps on
-- @param config table: Configuration with keymaps
function M.setup_keymaps(bufnr, config)
	local accept_key = config.keymaps.accept or "<Tab>"
	local dismiss_key = config.keymaps.dismiss or "<Esc>"

	-- Accept keymaps (both normal and insert mode)
	-- Use vim.schedule to defer buffer modification
	vim.keymap.set("i", accept_key, function()
		if M.has_suggestion() then
			vim.schedule(function()
				M.accept_suggestion()
			end)
		else
			-- No suggestion, simulate default Tab behavior
			local key = vim.api.nvim_replace_termcodes(accept_key, true, false, true)
			vim.api.nvim_feedkeys(key, "n", false)
		end
	end, {
		buffer = bufnr,
		noremap = true,
		silent = true,
		desc = "Squire: Accept suggestion",
	})

	vim.keymap.set("n", accept_key, function()
		if M.accept_suggestion() then
			-- After accepting, enter insert mode at end of insertion
			vim.cmd("startinsert!")
		end
	end, {
		buffer = bufnr,
		noremap = true,
		silent = true,
		desc = "Squire: Accept suggestion",
	})

	-- Dismiss keymaps (both normal and insert mode)
	vim.keymap.set("i", dismiss_key, function()
		if M.has_suggestion() then
			M.clear_suggestion()
		else
			-- No suggestion, simulate default Esc behavior
			local key = vim.api.nvim_replace_termcodes(dismiss_key, true, false, true)
			vim.api.nvim_feedkeys(key, "n", false)
		end
	end, {
		buffer = bufnr,
		noremap = true,
		silent = true,
		desc = "Squire: Dismiss suggestion",
	})

	vim.keymap.set("n", dismiss_key, function()
		if M.has_suggestion() then
			M.clear_suggestion()
		end
	end, {
		buffer = bufnr,
		noremap = true,
		silent = true,
		desc = "Squire: Dismiss suggestion",
	})
end

return M
