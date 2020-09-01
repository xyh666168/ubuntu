#!/bin/bash

echo "start 4G service"
if [ -e /usr/local/bin/quectel-daemon.sh ];
then
    /usr/local/bin/quectel-daemon.sh
fi
