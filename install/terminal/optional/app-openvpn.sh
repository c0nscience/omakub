#!/bin/bash

sudo apt install -y apt-transport-https
curl -sSfL https://packages.openvpn.net/packages-repo.gpg | sudo tee /etc/apt/keyrings/openvpn.asc
echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/debian noble main" | sudo tee /etc/apt/sources.list.d/openvpn3.list
sudo apt update -y
sudo apt install -y openvpn3
