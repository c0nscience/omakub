return {
	{
		"max397574/better-escape.nvim",
    config = function ()
      require("better_escape").setup {
        mappings = {
          t = {
            j = {
              k = false
            }
          }
        }
      }
    end
	},
}
