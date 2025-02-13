vim.api.nvim_create_autocmd("FileType", {
	pattern = "zig",
	callback = function()
		local zig_14 =
			"/Users/a266836/Documents/personnel/Experiments/zig/zig-macos-aarch64-0.14.0-dev.3204+c2a3d8cbb/zig"
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
--
-- `:lua vim.diagnostic.setqflist()`

-- You can map this to a key binding in your config if you use it frequently, for example:
--
-- ```lua
-- vim.keymap.set('n', '<leader>q', vim.diagnostic.setqflist, { desc = 'Send diagnostics to quickfix' })
