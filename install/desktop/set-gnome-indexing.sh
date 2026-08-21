#!/bin/bash

# Keep the GNOME file indexer (Tracker 3 / localsearch) in the background where
# it belongs. Its defaults assume a plugged-in desktop: crawl flat out, index on
# battery, start seconds after login. On a laptop that surfaces as
# tracker-extract bursts — an EXIF and thumbnail pass over whatever is new —
# big enough to swing package temperature by ~10°C and kick the fan on.
# `index-on-battery-first-time` is deliberately left at its default so a machine
# that never sees AC still gets an initial index.
#
# Guarded on the schema: these scripts are sourced under `set -e`, so a
# `gsettings set` against a missing schema would abort the whole install.
if gsettings list-schemas | grep -qx org.freedesktop.Tracker3.Miner.Files; then
	# Pause (value/20)*1000ms between batches of files rather than crawling
	# flat out, spreading the work instead of spiking it (default 0, max 20)
	gsettings set org.freedesktop.Tracker3.Miner.Files throttle 5

	# Stop indexing on battery once the first index is done — search results
	# nobody asked for aren't worth the runtime (default true)
	gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery false

	# Seconds to wait after login before the first crawl, so indexing doesn't
	# pile onto session startup (default 15)
	gsettings set org.freedesktop.Tracker3.Miner.Files initial-sleep 180
fi
