return {
	"mfussenegger/nvim-jdtls",
	opts = {
		settings = {
			java = {
				contentProvider = { preferred = "fernflower" },
				maven = { downloadSources = true },
				configuration = {
					runtimes = {
						{
							name = "JavaSE-17",
							path = vim.fn.expand("~/.local/share/mise/installs/java/zulu-17"),
						},
						{
							name = "JavaSE-21",
							path = vim.fn.expand("~/.local/share/mise/installs/java/zulu-21"),
						},
					},
				},
			},
		},
	},
}
