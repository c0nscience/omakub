#!/bin/bash

cd /tmp
wget -O nvim.tar.gz "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz"
tar -xf nvim.tar.gz
sudo install nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
sudo cp -R nvim-linux-x86_64/lib /usr/local/
sudo cp -R nvim-linux-x86_64/share /usr/local/
rm -rf nvim-linux-x86_64 nvim.tar.gz
cd -

# Install luarocks and tree-sitter-cli to resolve lazyvim :checkhealth warnings
sudo apt install -y luarocks

# Only attempt to set configuration if Neovim has never been run
if [ ! -d "$HOME/.config/nvim" ]; then
  # Use LazyVim
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  # Remove the .git folder, so you can add it to your own repo later
  rm -rf ~/.config/nvim/.git

  # Always-on runtime perf log (main-loop stalls, slow LSP requests, memory
  # growth) so a freeze can be diagnosed from ~/.local/state/nvim/perf.log
  # afterwards instead of by instrumenting a live instance. :PerfLog to read it.
  mkdir -p ~/.config/nvim/plugin
  cp ~/.local/share/omakub/configs/neovim/perflog.lua ~/.config/nvim/plugin/

  # Make everything match the terminal transparency
  mkdir -p ~/.config/nvim/plugin/after
  cp ~/.local/share/omakub/configs/neovim/transparency.lua ~/.config/nvim/plugin/after/

  # Default to Tokyo Night theme
  cp ~/.local/share/omakub/themes/tokyo-night/neovim.lua ~/.config/nvim/lua/plugins/theme.lua

  # Turn off animated scrolling
  cp ~/.local/share/omakub/configs/neovim/snacks-animated-scrolling-off.lua ~/.config/nvim/lua/plugins/

  # Turn off relative line numbers
  echo "vim.opt.relativenumber = false" >>~/.config/nvim/lua/config/options.lua

  # The shada file merges jumplists from every nvim instance and imports the
  # union at startup, so ctrl-o walks into files from other projects/sessions.
  # The VimEnter clearjumps drops the imported list so the jumplist stays
  # session-local; marks/oldfiles/registers keep persisting. clearjumps is
  # per-window and shada populates every startup window, hence the loop.
  # We rely on LazyVim's jumpoptions=view, which drops nvim 0.12's "clean"
  # default - wanted here, since "clean" prunes a buffer's entries on unload and
  # would erase the ctrl-o way back into a buffer you just closed.
  cat >>~/.config/nvim/lua/config/options.lua <<'LUA'
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      vim.api.nvim_win_call(win, function()
        vim.cmd.clearjumps()
      end)
    end
  end,
})
LUA

  # Ensure editor.neo-tree is used by default
  cp ~/.local/share/omakub/configs/neovim/lazyvim.json ~/.config/nvim/

  # Move custom keymaps
  rm -rf ~/.config/nvim/lua/config/keymaps.lua
  cp ~/.local/share/omakub/configs/neovim/keymaps.lua ~/.config/nvim/lua/config/

  rm -rf ~/.config/nvim/lua/plugins/example.lua
  cp ~/.local/share/omakub/configs/neovim/better-escape.lua ~/.config/nvim/lua/plugins/
  cp ~/.local/share/omakub/configs/neovim/neo-tree.lua ~/.config/nvim/lua/plugins/
  cp ~/.local/share/omakub/configs/neovim/undotree.lua ~/.config/nvim/lua/plugins/
  cp ~/.local/share/omakub/configs/neovim/mason.lua ~/.config/nvim/lua/plugins/
  cp ~/.local/share/omakub/configs/neovim/puppet.lua ~/.config/nvim/lua/plugins/
  cp ~/.local/share/omakub/configs/neovim/java.lua ~/.config/nvim/lua/plugins/
  cp ~/.local/share/omakub/configs/neovim/kotlin.lua ~/.config/nvim/lua/plugins/
  cp ~/.local/share/omakub/configs/neovim/csvview.lua ~/.config/nvim/lua/plugins/
fi

# Replace desktop launcher with one running inside Kitty
if [[ -d ~/.local/share/applications ]]; then
  sudo rm -rf /usr/share/applications/nvim.desktop
  sudo rm -rf /usr/local/share/applications/nvim.desktop
  source ~/.local/share/omakub/applications/Neovim.sh
fi
