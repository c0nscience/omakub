# Compressed swap in RAM ahead of the disk swap files. Idle JVM heap pages
# (jdtls, IntelliJ, Gradle daemons) get compressed into zram at memory speed
# instead of paged to disk, which is what made every reconcile crawl once a
# language server had been idle for a while. Disk swap stays as overflow:
# zram registers at priority 100, above the swap files.
sudo apt install -y systemd-zram-generator

# The package ships /etc/systemd/zram-generator.conf as a conffile (with a
# [zram0] section on kernel defaults), so never test for its absence - use the
# drop-in directory, which cleanly overrides it and survives package upgrades.
sudo mkdir -p /etc/systemd/zram-generator.conf.d
sudo tee /etc/systemd/zram-generator.conf.d/omakub.conf >/dev/null <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF

# Kernel guidance for zram-backed swap: prefer swapping (it is cheap now) and
# drop readahead clustering (random access into zram has no seek cost).
sudo tee /etc/sysctl.d/99-omakub-zram.conf >/dev/null <<'EOF'
vm.swappiness = 180
vm.page-cluster = 0
EOF

# Runtime activation. At boot the generator handles this alone; at runtime a
# restart can race a queued start job against a device the failed previous run
# left half-initialized ("Device or resource busy"), so: stop everything, reset
# the device, clear the failed state, then issue ONE start.
if ! swapon --show=NAME --noheadings | grep -q '^/dev/zram0$'; then
  sudo systemctl daemon-reload
  sudo systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
  [ -e /sys/block/zram0 ] && sudo zramctl --reset /dev/zram0 2>/dev/null || true
  sudo systemctl reset-failed systemd-zram-setup@zram0.service 2>/dev/null || true
  sudo systemctl start systemd-zram-setup@zram0.service
fi
sudo sysctl --load /etc/sysctl.d/99-omakub-zram.conf >/dev/null

swapon --show
