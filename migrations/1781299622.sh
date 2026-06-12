# Kitty cannot see Ubuntu's CBDT-bitmap-only emoji font; emoji in symbol_map
# render as dots. Install the scalable COLRv1 build user-level instead.
if [ ! -f ~/.local/share/fonts/Noto-COLRv1.ttf ]; then
  mkdir -p ~/.local/share/fonts
  curl -sL -o ~/.local/share/fonts/Noto-COLRv1.ttf \
    https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/Noto-COLRv1.ttf
  fc-cache -f ~/.local/share/fonts
fi
