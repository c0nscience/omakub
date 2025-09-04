cat <<EOF >~/.local/share/applications/9to5.desktop
[Desktop Entry]
Version=1.0
Name=Nine to Five
Comment=Nine to Five
Exec=brave-browser --app="https://9to5.app/app" --name="Nine to Five" --class="Nine to Five" --window-size=400,900
Terminal=false
Type=Application
Icon=/home/$USER/.local/share/omakub/applications/icons/9to5.png
Categories=GTK;
MimeType=text/html;text/xml;application/xhtml_xml;
StartupNotify=true
EOF
