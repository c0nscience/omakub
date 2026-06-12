#!/bin/bash

CHOICES=(
	"Omakub        Update Omakub itself and run any migrations"
	"Ollama        Run LLMs, like Meta's Llama3, locally"
	"LazyGit       TUI for Git"
	"LazyDocker    TUI for Docker"
	"Neovim        Text editor that runs in the terminal"
	"Kitty         GPU-powered terminal with a native graphics protocol"
	"<< Back       "
)

CHOICE=$(gum choose "${CHOICES[@]}" --height 10 --header "Update manually-managed applications")

if [[ "$CHOICE" == "<< Back"* ]] || [[ -z "$CHOICE" ]]; then
	# Don't update anything
	echo ""
else
	INSTALLER=$(echo "$CHOICE" | awk -F ' {2,}' '{print $1}' | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

	case "$INSTALLER" in
	"omakub") INSTALLER_FILE="$OMAKUB_PATH/bin/omakub-sub/migrate.sh" ;;
	"ollama") INSTALLER_FILE="$OMAKUB_PATH/install/terminal/optional/app-ollama.sh" ;;
	"kitty") INSTALLER_FILE="$OMAKUB_PATH/install/desktop/app-kitty.sh" ;;
	*) INSTALLER_FILE="$OMAKUB_PATH/install/terminal/app-$INSTALLER.sh" ;;
	esac

	source $INSTALLER_FILE && gum spin --spinner globe --title "Update completed!" -- sleep 3
fi

clear
source $OMAKUB_PATH/bin/omakub
