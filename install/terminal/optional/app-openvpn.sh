#!/bin/bash

sudo apt install -y apt-transport-https curl
sudo sh -c 'curl -sSfL https://packages.openvpn.net/packages-repo.gpg >/etc/apt/keyrings/openvpn.asc'
sudo sh -c 'echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/debian noble main" >>/etc/apt/sources.list.d/openvpn3.list'
sudo apt update -y
sudo apt install -y openvpn3
