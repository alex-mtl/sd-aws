#!/bin/bash

case "$1" in
    -d|--daemon)
        $0 < /dev/null &> /dev/null & disown
        exit 0
        ;;
    *)
        ;;
esac

./stable-diffusion-webui/webui.sh
