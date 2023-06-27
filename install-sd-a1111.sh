#!/bin/bash

# install dependencies
sudo apt -y update && sudo apt -y upgrade
sudo apt -y install aria2
sudo apt -y install python3.8-venv # change python version

# official webui installation script
bash <(wget -qO- https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh)