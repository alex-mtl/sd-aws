#!/bin/bash
source helpers.sh

echo "Connect to the instance to start Stable Diffusion WEB UI"
ssh -i ~/.ssh/SD-ED25519.pem -o StrictHostKeyChecking=no ubuntu@34.209.196.84  << EOF
  ./start.webui.sh -d
  exit
EOF

