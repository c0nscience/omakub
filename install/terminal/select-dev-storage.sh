#!/bin/bash

# Install default databases
if [[ -v OMAKUB_FIRST_RUN_DBS ]]; then
  dbs=$OMAKUB_FIRST_RUN_DBS
else
  AVAILABLE_DBS=("MySQL" "Redis" "PostgreSQL")
  dbs=$(gum choose "${AVAILABLE_DBS[@]}" --no-limit --height 5 --header "Select databases (runs in Docker)")
fi

if [[ -n "$dbs" ]]; then
  for db in $dbs; do
    case $db in
    MySQL)
      sudo docker run -d --restart unless-stopped -p "3306:3306" --name=mysql -e MYSQL_ROOT_PASSWORD= -e MYSQL_ALLOW_EMPTY_PASSWORD=true mysql:9.4
      ;;
    Redis)
      sudo docker run -d --restart unless-stopped -p "6379:6379" --name=redis redis:8
      ;;
    PostgreSQL)
      sudo docker run -d --restart unless-stopped -p "5432:5432" --name=postgres -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17
      ;;
    esac
  done
fi
