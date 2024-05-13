local M = {}

local function get_surrounding_lines()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	return table.concat(lines, "\n")
end

local function handle_response(response)
	local lines = vim.split(response, "\n", true)
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, current_line, current_line, false, lines)
end

local config = require("command-k.config")

local function send_api_request(prompt)
	local context = get_surrounding_lines()
	local data = string.format('{"prompt": "%s", "context": "%s"}', prompt, context)
	local api_token = config.api_token
	local api_url = config.api_url
	local cmd = string.format(
		"curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '%s' '%s'",
		api_token,
		data,
		api_url
	)

	vim.fn.jobstart(cmd, {
		on_stdout = function(_, result)
			if result then
				handle_response(table.concat(result, ""))
			end
		end,
		stdout_buffered = true,
	})
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
			print("You entered: " .. input)
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

return M
