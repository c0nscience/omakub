#!/bin/bash

# Replace alacritty+zellij with kitty as the omakub-managed terminal. kitty
# 0.47 covers the zellij features in use (modal keybindings, splits, tabs)
# without the multiplexer process — zellij idles hot and bloats phantom pane
# state — and brings the graphics protocol alacritty lacks (yazi previews).

if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
  # Carry the current theme and font over before the alacritty/zellij configs go away
  THEME=$(grep -oP 'theme "\K[^"]+' ~/.config/zellij/config.kdl 2>/dev/null)
  [ -d "$OMAKUB_PATH/themes/$THEME" ] || THEME="tokyo-night"
  FONT_FAMILY=$(grep -m1 -oP 'family = "\K[^"]+' ~/.config/alacritty/font.toml 2>/dev/null)
  FONT_SIZE=$(grep -oP '^size = \K[0-9.]+' ~/.config/alacritty/font-size.toml 2>/dev/null)

  source $OMAKUB_PATH/install/desktop/app-kitty.sh

  cp $OMAKUB_PATH/themes/$THEME/kitty.conf ~/.config/kitty/theme.conf
  case "$FONT_FAMILY" in
  "FiraMono"*) cp $OMAKUB_PATH/configs/kitty/fonts/FiraMono.conf ~/.config/kitty/font.conf ;;
  "JetBrainsMono"*) cp $OMAKUB_PATH/configs/kitty/fonts/JetBrainsMono.conf ~/.config/kitty/font.conf ;;
  "Meslo"*) cp $OMAKUB_PATH/configs/kitty/fonts/MesloLGS.conf ~/.config/kitty/font.conf ;;
  esac
  if [ -n "$FONT_SIZE" ]; then
    sed -i "s/^font_size .*$/font_size $FONT_SIZE/g" ~/.config/kitty/font-size.conf
  fi

  # Regenerate the launcher apps to run in kitty
  source $OMAKUB_PATH/applications/About.sh
  source $OMAKUB_PATH/applications/Activity.sh
  source $OMAKUB_PATH/applications/Docker.sh
  source $OMAKUB_PATH/applications/Neovim.sh
  source $OMAKUB_PATH/applications/Omakub.sh

  # New-terminal hotkey now opens kitty
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'New Kitty Window'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command "$HOME/.local/kitty.app/bin/kitty"

  # Swap alacritty for kitty in the dock favorites (kitty may already be pinned)
  python3 - <<'PY'
import ast
import subprocess

out = subprocess.run(
    ["gsettings", "get", "org.gnome.shell", "favorite-apps"],
    capture_output=True, text=True,
).stdout.strip()
favs = ast.literal_eval(out) if out else []
if "kitty.desktop" not in favs:
    favs = ["kitty.desktop" if f == "Alacritty.desktop" else f for f in favs]
favs = [f for f in favs if f != "Alacritty.desktop"]
subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", str(favs)])
PY

  # Retire zellij and alacritty (read above before this point)
  sudo rm -f /usr/local/bin/zellij
  rm -rf ~/.config/zellij
  sudo apt remove -y alacritty
  rm -rf ~/.config/alacritty

  echo "kitty is now the omakub terminal — already-running zellij/alacritty sessions keep running until you close them"
fi
