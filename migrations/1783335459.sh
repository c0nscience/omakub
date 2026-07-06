#!/bin/bash

# Catch up machines that advanced past the June alacritty->kitty switch
# (migration 1781289040) without ever running it. That happens when the repo is
# moved forward with a bare `git pull` instead of Update -> Omakub: migrate.sh
# derives "already applied" from the pre-pull commit timestamp, so once HEAD is
# past a migration's date that migration is skipped for good. Symptom: the app
# launchers still Exec=alacritty (a terminal omakub no longer manages), so they
# fail to open. Every step here is idempotent — a no-op on a healthy machine.

# Desktop-only: kitty and the launchers don't exist on terminal-only installs.
if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
  # The launchers point at kitty, so make sure kitty exists first. A machine that
  # never switched still has its old alacritty/zellij configs — carry the theme
  # and font over, exactly as the original switch did. A machine that already has
  # kitty keeps its config untouched (this whole branch is skipped).
  if [ ! -x "$HOME/.local/kitty.app/bin/kitty" ]; then
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
    [ -n "$FONT_SIZE" ] && sed -i "s/^font_size .*$/font_size $FONT_SIZE/g" ~/.config/kitty/font-size.conf
  fi

  # Deploy the popup configs the launchers include, without clobbering an
  # existing theme/font/size choice.
  mkdir -p ~/.config/kitty
  cp $OMAKUB_PATH/configs/kitty/pane.conf ~/.config/kitty/pane.conf
  cp $OMAKUB_PATH/configs/kitty/btop.conf ~/.config/kitty/btop.conf
  [ -f ~/.config/kitty/theme.conf ] || cp $OMAKUB_PATH/themes/tokyo-night/kitty.conf ~/.config/kitty/theme.conf
  [ -f ~/.config/kitty/font.conf ] || cp $OMAKUB_PATH/configs/kitty/fonts/CaskaydiaMono.conf ~/.config/kitty/font.conf
  [ -f ~/.config/kitty/font-size.conf ] || cp $OMAKUB_PATH/configs/kitty/font-size.conf ~/.config/kitty/font-size.conf

  # Regenerate every launcher that used to open in alacritty so it opens in kitty.
  for app in Omakub About Activity Docker Neovim; do
    source $OMAKUB_PATH/applications/$app.sh
  done
  command -v update-desktop-database &>/dev/null &&
    update-desktop-database ~/.local/share/applications 2>/dev/null

  # New-terminal hotkey: repoint at kitty if it still launches alacritty.
  hotkey="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
  if gsettings get "$hotkey" command 2>/dev/null | grep -q alacritty; then
    gsettings set "$hotkey" name 'New Kitty Window'
    gsettings set "$hotkey" command "$HOME/.local/kitty.app/bin/kitty"
  fi

  # Swap alacritty for kitty in the dock favorites, if it is still pinned.
  python3 - <<'PY'
import ast, subprocess
out = subprocess.run(["gsettings", "get", "org.gnome.shell", "favorite-apps"],
                     capture_output=True, text=True).stdout.strip()
favs = ast.literal_eval(out) if out else []
if "Alacritty.desktop" in favs:
    favs = ["kitty.desktop" if f == "Alacritty.desktop" else f for f in favs]
    seen = set()
    favs = [f for f in favs if not (f in seen or seen.add(f))]  # dedupe if kitty already pinned
    subprocess.run(["gsettings", "set", "org.gnome.shell", "favorite-apps", str(favs)])
PY

  # Retire alacritty (uninstalled in the original switch) and its leftover config.
  if command -v alacritty &>/dev/null; then
    sudo apt remove -y alacritty
  fi
  rm -rf ~/.config/alacritty
fi
