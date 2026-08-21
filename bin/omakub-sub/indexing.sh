#!/bin/bash

# Exclude a folder from the GNOME file indexer (Tracker 3 / localsearch).
#
# The indexer skips any directory holding a `.trackerignore` file — it ships in
# the default `ignored-directories-with-content` list — and the skip covers the
# whole tree below it. Worth doing for large machine-local piles that desktop
# search will never usefully answer for: timelapse or burst-photo frames, render
# output, datasets, VM images. Every file added to one of those wakes
# tracker-extract for an EXIF/thumbnail pass, and on a laptop that alone is
# enough to spin the fan up. `.git` is already in that list, so source checkouts
# with a repo at their root need nothing here.
#
# Dropping the marker only stops future crawls; whatever the indexer already
# stored stays until it is deleted, which is what the `reset --file` pass does.
# Order matters: the marker has to land first, because `reset` asks the miner to
# reindex the location afterwards and only the marker keeps that request from
# re-crawling the tree we just excluded.

INDEXER_CLI=$(command -v tracker3 || command -v localsearch)

if ! gsettings list-schemas | grep -qx org.freedesktop.Tracker3.Miner.Files; then
	gum spin --spinner globe --title "No file indexer installed — nothing to exclude." -- sleep 3
else
	DIRECTORY=$(gum file --directory --all --height 20 --header "Pick a folder to exclude from search indexing" "$HOME")

	if [ -z "$DIRECTORY" ] || [ ! -d "$DIRECTORY" ]; then
		# Nothing picked
		echo ""
	elif [ -e "$DIRECTORY/.trackerignore" ]; then
		gum spin --spinner globe --title "$DIRECTORY is already excluded." -- sleep 3
	elif gum confirm "Stop indexing $DIRECTORY and everything under it?"; then
		touch "$DIRECTORY/.trackerignore"

		# Purge what is already in the index for the tree. Skipped when the CLI is
		# missing or too old for `--file`; the marker still stops future crawls.
		if [ -n "$INDEXER_CLI" ] && "$INDEXER_CLI" reset --help 2>&1 | grep -q -- '--file' &&
			gum confirm "Also drop what is already indexed under it? Can take a while on a big folder."; then
			gum spin --spinner globe --title "Removing $DIRECTORY from the index..." -- \
				"$INDEXER_CLI" reset --file "$DIRECTORY"
		fi

		gum spin --spinner globe --title "Excluded! Delete $DIRECTORY/.trackerignore to undo." -- sleep 3
	fi
fi

clear
source $OMAKUB_PATH/bin/omakub
