#!/bin/bash

source colors.sh

timestamp() {
    CURRENT_TIME=$(date +"%T")
    echo -e "${C_YELLOW} $1 ${CURRENT_TIME}${C_RESET}"
}
