local M = {}

-- take whole open buffer i
local function get_surrounding_lines()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	return table.concat(lines, "\n")
end

local function handle_response(response)
	local lines = vim.split(response, "\n", { trimempty = "true" })
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, current_line, current_line, false, lines)
end

local function send_api_request(prompt)
	local context = get_surrounding_lines()
	local data = string.format('{"prompt": "%s", "context": "%s"}', prompt, context)
	local cmd = string.format(
		"curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '%s' '%s'",
		"test_token",
		data,
		"test.com/"
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
	local prompt = vim.fn.input("OpenAI Prompt: ")
	if prompt ~= "" then
		send_api_request(prompt)
	end
end

-- Set up key mapping
function M.setup()
	vim.api.nvim_set_keymap(
		"n",
		"<Ctrl>k",
		':lua require("lazyvim_openai").open_prompt()<CR>',
		{ noremap = true, silent = true }
	)
end

return M
