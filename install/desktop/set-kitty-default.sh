#!/usr/bin/env sh

# Make kitty default terminal emulator (the kitty.app install isn't registered
# with the alternatives system by apt, so add it first)
sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$HOME/.local/kitty.app/bin/kitty" 60
sudo update-alternatives --set x-terminal-emulator "$HOME/.local/kitty.app/bin/kitty"

# Adding kitty to nautilus contextual menu requires the python wrapper for the libraries
sudo apt install -y python3-nautilus
mkdir -p ~/.local/share/nautilus-python/extensions/
rm -f ~/.local/share/nautilus-python/extensions/open-alacritty.py

cat > ~/.local/share/nautilus-python/extensions/open-kitty.py <<TECHNICALLYNOTACONFIGSOHEREDOCCEDITIS
import os
from urllib.parse import unquote
from gi.repository import Nautilus, GObject
from typing import List

class OpenTerminalExtension(GObject.GObject, Nautilus.MenuProvider):
    def _open_terminal(self, file: Nautilus.FileInfo) -> None:
        filename = unquote(file.get_uri()[7:])

        os.chdir(filename)
        os.system("$HOME/.local/kitty.app/bin/kitty")

    def menu_activate_cb(
        self,
        menu: Nautilus.MenuItem,
        file: Nautilus.FileInfo,
    ) -> None:
        self._open_terminal(file)

    def menu_background_activate_cb(
        self,
        menu: Nautilus.MenuItem,
        file: Nautilus.FileInfo,
    ) -> None:
        self._open_terminal(file)

    def get_file_items(
        self,
        files: List[Nautilus.FileInfo],
    ) -> List[Nautilus.MenuItem]:
        if len(files) != 1:
            return []

        file = files[0]
        if not file.is_directory() or file.get_uri_scheme() != "file":
            return []

        item = Nautilus.MenuItem(
            name="NautilusPython::openterminal_file_item",
            label="Open in Kitty",
            tip="Open Kitty In %s" % file.get_name(),
        )
        item.connect("activate", self.menu_activate_cb, file)

        return [
            item,
        ]

    def get_background_items(
        self,
        current_folder: Nautilus.FileInfo,
    ) -> List[Nautilus.MenuItem]:
        item = Nautilus.MenuItem(
            name="NautilusPython::openterminal_file_item2",
            label="Open in Kitty",
            tip="Open Kitty In %s" % current_folder.get_name(),
        )
        item.connect("activate", self.menu_background_activate_cb, current_folder)

        return [
            item,
        ]
TECHNICALLYNOTACONFIGSOHEREDOCCEDITIS
