# Roll back the zram swap experiment shipped earlier today (migration
# 1785415609, now deleted). It was a fix for one machine's specific
# memory-pressure problem and should never have gone out to every machine.
# Fully guarded: on a machine that never ran it, every step is a no-op.
if swapon --show=NAME --noheadings 2>/dev/null | grep -q '^/dev/zram0$'; then
  sudo swapoff /dev/zram0 || true
fi
sudo systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
if [ -e /sys/block/zram0 ]; then
  sudo zramctl --reset /dev/zram0 2>/dev/null || true
fi
sudo rm -f /etc/systemd/zram-generator.conf.d/omakub.conf
sudo rmdir /etc/systemd/zram-generator.conf.d 2>/dev/null || true

if [ -f /etc/sysctl.d/99-omakub-zram.conf ]; then
  sudo rm -f /etc/sysctl.d/99-omakub-zram.conf
  # restore the kernel defaults the removed file had overridden
  sudo sysctl -w vm.swappiness=60 vm.page-cluster=3 >/dev/null 2>&1 || true
fi

if dpkg -s systemd-zram-generator >/dev/null 2>&1; then
  sudo apt remove -y systemd-zram-generator || true
fi
sudo systemctl daemon-reload 2>/dev/null || true
