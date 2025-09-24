return {
	{
		"jiaoshijie/undotree",
		dependencies = { "nvim-lua/plenary.nvim" },
		---@module 'undotree.collector'
		---@type UndoTreeCollector.Opts
		opts = {
			-- your options
		},
		keys = { -- load the plugin only when using it's keybinding:
			{ "<leader>U", "<cmd>lua require('undotree').toggle()<cr>", desc = "Toggle Undotree" },
		},
	},
}
