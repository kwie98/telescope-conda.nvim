local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local scan = require("plenary.scandir")

local M = {}

local conda_path

M.setup = function(setup_config)
	local home = os.getenv("HOME")
	local viableInstallationDirs = { "/miniconda3", "/anaconda3" }

	conda_path = setup_config.anaconda_path or nil -- TODO throw error on wrong path

	local i = 1
	while not conda_path and viableInstallationDirs[i] do
		local currentPath = home .. viableInstallationDirs[i]
		if vim.fn.isdirectory(currentPath) ~= 0 then
			conda_path = currentPath
		end
		i = i + 1
	end

	if not conda_path then
		error(
			"Anaconda installation path not found! Please make sure Anaconda is installed or configure the correct path"
		)
	else
		conda_path = vim.fn.expand(conda_path) -- To enable vars in configuration path
	end
end

M.conda = function(opts)
	opts = opts or {}
	local conda_env_path = conda_path .. "/envs"
	local conda_finder = function()
		local conda_envs = {}
		scan.scan_dir(conda_env_path, {
			hidden = opts.hidden or false,
			add_dirs = true,
			depth = 1,
			on_insert = function(entry, typ)
				table.insert(conda_envs, entry)
			end,
		})

		local conda_maker = function(entry)
			local path_remove = function(String, Path)
				if String == conda_path then
					return "base"
				else
					return string.gsub(String, Path .. "/", "")
				end
			end

			local disp = path_remove(entry, conda_env_path)

			return { value = entry, display = disp, ordinal = disp }
		end

		table.insert(conda_envs, conda_path)
		return finders.new_table({ results = conda_envs, entry_maker = conda_maker })
	end

	pickers.new(opts, {
		prompt_title = "Select an Environment",
		results_title = "Conda Environments",
		finder = conda_finder(),
		sorter = conf.generic_sorter(opts),

		-- TODO: There seems to be a bug if you immediately select the suggestion without moving first, that this one is not written into 
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				env_to_bin = function(env_name, env_path)
					if env_name == "base" or not env_name then
						return conda_path .. "/bin"
					else
						print('env_name')
						print(env_name)
						print('env_path')
						print(env_path)
						if not env_path then
						    return conda_env_path .. '/' .. env_name .. '/bin'
                        else
							if string.strsub(env_path, 1, -4) == '/bin' then
								return env_path
							else
								return env_path .. "/bin"
							end
						end
					end
				end
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()

				-- print(vim.inspect(selection)) -- for debugging only
				
				local current_env_name = vim.env.CONDA_DEFAULT_ENV_NAME
				local current_env_path = vim.env.CONDA_DEFAULT_ENV_PATH

				local next_env_name = selection["display"]
				local next_env_path = selection['value']
				vim.env.CONDA_DEFAULT_ENV_NAME = next_env_name
				vim.env.CONDA_DEFAULT_ENV_PATH = next_env_path
				current_anaconda = env_to_bin(current_env_name, current_env_path)
				next_anaconda = env_to_bin(next_env_name, next_env_path)

				-- remove it and append it separately. Otherwise might have issues when no env in path in the beginning
				vim.env.PATH = string.gsub(vim.env.PATH, current_anaconda .. '', '')
				vim.env.PATH = current_anaconda .. ':' .. vim.env.PATH
			end)
			return true
		end,
	}):find()
end

return M
