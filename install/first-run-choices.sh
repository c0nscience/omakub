#!/bin/bash

AVAILABLE_LANGUAGES=("Ruby on Rails" "Node.js" "Go" "PHP" "Python" "Elixir" "Rust" "Java")
SELECTED_LANGUAGES="Go","Node.js", "Python", "Rust", "Java"
export OMAKUB_FIRST_RUN_LANGUAGES=$(gum choose "${AVAILABLE_LANGUAGES[@]}" --no-limit --selected "$SELECTED_LANGUAGES" --height 10 --header "Select programming languages")

AVAILABLE_DBS=("MySQL" "Redis" "PostgreSQL")
SELECTED_DBS="PostgreSQL"
export OMAKUB_FIRST_RUN_DBS=$(gum choose "${AVAILABLE_DBS[@]}" --no-limit --selected "$SELECTED_DBS" --height 5 --header "Select databases (runs in Docker)")
