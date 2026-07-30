# Compressed swap in RAM ahead of the disk swap files. Idle JVM heap pages
# (jdtls, IntelliJ, Gradle daemons) get compressed into zram at memory speed
# instead of paged to disk, which is what made every reconcile crawl once a
# language server had been idle for a while. Disk swap stays as overflow:
# zram registers at priority 100, above the swap files.
sudo apt install -y systemd-zram-generator

if [ ! -f /etc/systemd/zram-generator.conf ]; then
  sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF
fi

# Kernel guidance for zram-backed swap: prefer swapping (it is cheap now) and
# drop readahead clustering (random access into zram has no seek cost).
if [ ! -f /etc/sysctl.d/99-omakub-zram.conf ]; then
  sudo tee /etc/sysctl.d/99-omakub-zram.conf >/dev/null <<'EOF'
vm.swappiness = 180
vm.page-cluster = 0
EOF
fi

sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true
sudo sysctl --load /etc/sysctl.d/99-omakub-zram.conf >/dev/null
