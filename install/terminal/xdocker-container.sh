#!/bin/bash

sudo docker run -d --network local --restart unless-stopped -p "6000:80" --name=excalidraw excalidraw/excalidraw:latest
sudo docker run -d --network local --restart unless-stopped -p "5000:80" -p "2525:25" --name=mail rnwood/smtp4dev
