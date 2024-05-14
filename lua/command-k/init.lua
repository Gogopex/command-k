local M = {}
local config = require("command-k.config")

local function escape_json_string(s)
	s = s:gsub("\\", "\\\\")
	s = s:gsub('"', '\\"')
	s = s:gsub("\n", "\\n")
	s = s:gsub("\r", "\\r")
	s = s:gsub("\t", "\\t")
	return s
end

local function get_surrounding_lines()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	return table.concat(lines, "\n")
end

local function handle_response(response)
	-- parse the JSON response to extract the message>content
	-- buggy atm
	--     local message_content = response:match('"content":"(.-)","logprobs"')
	--     if not message_content then
	--         print("Error extracting message content from response")
	--         return
	--     end

	--     -- Unescape JSON special characters
	--     message_content = message_content:gsub('\\"', '"')
	--     message_content = message_content:gsub('\\\\', '\\')
	--     message_content = message_content:gsub('\\n', '\n')
	--     message_content = message_content:gsub('\\r', '\r')
	--     message_content = message_content:gsub('\\t', '\t')

	-- Split the message content into lines
	local lines = vim.split(message_content, "\n", true)
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local win_opts = {
		relative = "win",
		width = math.ceil(width * 0.8),
		height = math.ceil(height * 0.2),
		col = 0,
		row = current_line,
		style = "minimal",
		border = "rounded",
	}
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		":lua require('command-k').accept_suggestion(" .. buf .. ", " .. win .. ")<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<Esc>",
		":lua require('command-k').decline_suggestion(" .. win .. ")<CR>",
		{ noremap = true, silent = true }
	)
end

local function send_api_request(prompt)
	local context = get_surrounding_lines()
	context = escape_json_string(context)
	prompt = escape_json_string(prompt)

	local instructions =
		"You are an Agent for code improvements. You receive the entire file as context. Respond only with code. Your response will be directly inserted into the user's code. The User's prompt is marked with [ ], and the file context with * *."

	local data = string.format(
		'{"messages": [{"role": "user", "content": "%s [ %s ] * %s *"}], "model": "llama3-8b-8192"}',
		instructions,
		prompt,
		context
	)

	local api_token = config.api_token
	local api_url = config.api_url
	local cmd = string.format(
		"curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '%s' '%s'",
		api_token,
		data,
		api_url
	)

	print("Executing command: " .. cmd)
	vim.fn.jobstart(cmd, {
		on_stdout = function(_, result)
			if result then
				handle_response(table.concat(result, ""))
			end
		end,
		stdout_buffered = true,
	})
	print("API request sent")
end

function M.open_prompt()
	local buf = vim.api.nvim_create_buf(false, true)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local win_opts = {
		relative = "win",
		width = math.ceil(width * 0.8),
		height = math.ceil(height * 0.2),
		col = cursor_pos[2],
		row = cursor_pos[1] - 1,
		style = "minimal",
		border = "rounded",
	}
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
	vim.fn.prompt_setprompt(buf, "Prompt: ")
	vim.fn.prompt_setcallback(buf, function(input)
		vim.api.nvim_win_close(win, true)
		if input then
			send_api_request(input)
		end
	end)
	vim.cmd("startinsert")
end

function M.setup()
	vim.keymap.set({ "n", "v" }, "<Cmd>k", function()
		M.open_prompt()
	end, { desc = "Trigger AI Code Assist", noremap = true, silent = true })
end

function M.accept_suggestion(buf, win)
	print("Accepting suggestion")
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, current_line, current_line, false, lines)
	vim.api.nvim_win_close(win, true)
end

function M.decline_suggestion(win)
	print("Declining suggestion")
	vim.api.nvim_win_close(win, true)
end

return M
