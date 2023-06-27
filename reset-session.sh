#!/bin/bash

ROOT_KEY_ID="XXXXXXXXXXXXXXXXXXX"
ROOT_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXXX"

#Switch session to root user
aws configure set aws_access_key_id "${ROOT_KEY_ID}"
aws configure set aws_secret_access_key "${ROOT_SECRET_ACCESS_KEY}"

echo -e "$C_GREEN Session switched to root account$C_RESET"