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

local function send_api_request(prompt)
	local context = get_surrounding_lines()
	local data = string.format('{"prompt": "%s", "context": "%s"}', prompt, context)
	local api_token = "test_test"
	local api_url = "https://test.com/"
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
	local mode = vim.fn.mode()
	local prompt = ""
	if mode == "v" or mode == "V" then
		vim.cmd('normal! "vy')
		prompt = vim.fn.getreg("v")
	end

	local ui = vim.ui
	local input_options = {
		prompt = "Prompt: ",
		multiline = true,
	}
	ui.input(input_options, function(input)
		if input then
			print("You entered: " .. input)
			send_api_request(input)
		end
	end)
end

function M.setup()
	vim.keymap.set({ "n", "v" }, "<Cmd>k", function()
		M.open_prompt()
	end, { desc = "Trigger AI Code Assist", noremap = true, silent = true })
end

return M
