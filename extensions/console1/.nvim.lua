vim.api.nvim_create_autocmd("FileType", {
	pattern = "zig",
	callback = function()
		local zig_14 = "zig"
		vim.opt.makeprg = zig_14 .. " build"
		vim.keymap.set("n", "<leader>zb", function()
			require("zig-comp-diag").runWithCmd({ zig_14, "build", "-Dtest=true" })
		end, { buffer = true, desc = "Zig build" })

		vim.keymap.set("n", "<leader>zT", function()
			require("zig-comp-diag").runWithCmd({ zig_14, "build", "test" })
		end, { buffer = true, desc = "Zig build test" })

		vim.keymap.set("n", "<leader>zt", function()
			require("zig-comp-diag").runWithCmd({
				zig_14,
				"build",
				"test",
				"-Dtest=true",
				"--verbose",
				"--summary",
				"all",
			})
		end, { buffer = true, desc = "Zig build test verbose" })

		vim.keymap.set("n", "<leader>zr", function()
			require("zig-comp-diag").runWithCmd({
				zig_14,
				"build",
				"-Dtest=true",
				"--prefix",
				'"/Users/a266836/Library/Application Support/REAPER/UserPlugins"',
				"&&",
				"/Applications/REAPER.app/Contents/MacOS/REAPER",
				"new",
			})
		end, { buffer = true, desc = "Zig install reaper" })
	end,
})

-- ### Example Debug Console Commands
-- Here are some useful LLDB commands for your scenario:
-- 1. **Inspect the Pointer to the Array List**:
--    ```lldb
--    (lldb) expr state.tracks.items.ptr
--    ```
--
-- 2. **Dereference the Pointer and Access an Element**:
--    ```lldb
--    (lldb) expr state.tracks.items.ptr[1]
--    ```
--
-- 3. **Access a Field of an Element**:
--    ```lldb
--    (lldb) expr state.tracks.items.ptr[1].name
--    ```
--
-- 4. **Read Raw Memory**:
--    ```lldb
--    (lldb) memory read --size 1 --format x state.tracks.items.ptr
--    ```
--
-- 5. **Inspect the Entire Array List**:
--    ```lldb
--    (lldb) frame variable state.tracks
--    ```

-- DAP configurations for codelldb
local dap = require("dap")

-- Detect operating system
local is_mac = vim.fn.has("mac") == 1
local is_linux = vim.fn.has("unix") == 1 and vim.fn.has("mac") == 0
local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

-- Get project root directory
local project_root = vim.fn.getcwd()

-- Define REAPER path based on OS
local reaper_path
if is_mac then
	reaper_path = "/Applications/REAPER.app/Contents/MacOS/REAPER"
elseif is_linux then
	reaper_path = "/usr/local/bin/reaper" -- Adjust if needed for your Linux installation
elseif is_windows then
	reaper_path = "C:\\Program Files\\REAPER\\reaper.exe" -- Adjust if needed for your Windows installation
else
	reaper_path = "reaper" -- Fallback
end

--- Function to find the most recent test binary in .zig-cache
local function find_latest_test_binary()
	-- Default fallback path
	local fallback = project_root .. "/.zig-cache/o/b9d071ccaa1ac430f68f5e9227e86d33/reaper_zig_tests"

	-- Try to find the most recent test binary using fd or find
	local cmd
	if vim.fn.executable("fd") == 1 then
		cmd = "fd -t x -p 'test$' " .. project_root .. "/.zig-cache"
	elseif vim.fn.executable("find") == 1 then
		cmd = "find " .. project_root .. "/.zig-cache -type f -name 'test' -executable"
	else
		return fallback
	end

	local handle = io.popen(cmd)
	if not handle then
		return fallback
	end

	local result = handle:read("*a")
	handle:close()

	-- Get the most recent file from the list
	local files = {}
	for file in result:gmatch("[^\r\n]+") do
		table.insert(files, file)
	end

	if #files > 0 then
		-- Sort by modification time (most recent first)
		table.sort(files, function(a, b)
			local stat_a = vim.uv.fs_stat(a)
			local stat_b = vim.uv.fs_stat(b)
			if stat_a and stat_b then
				return stat_a.mtime.sec > stat_b.mtime.sec
			end
			return false
		end)
		return files[1]
	end

	return fallback
end

-- Add configurations for codelldb
dap.configurations.zig = {
	{
		name = "codelldb-test",
		type = "codelldb",
		request = "launch",
		program = find_latest_test_binary(),
		args = {},
		cwd = "${workspaceFolder}",
	},
	{
		name = "codelldb-ReaperDebug",
		type = "codelldb",
		request = "launch",
		program = reaper_path,
		args = { "new" },
		cwd = "${workspaceFolder}",
	},
	{
		name = "codelldb-buildTests",
		type = "codelldb",
		request = "launch",
		program = "${workspaceFolder}/zig-out/bin/reaper_zig_tests",
		args = {},
		cwd = "${workspaceFolder}",
	},
}

-- Also make these configurations available for C/C++ files
dap.configurations.c = dap.configurations.zig
dap.configurations.cpp = dap.configurations.zig
