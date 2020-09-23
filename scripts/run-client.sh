#!/usr/bin/env sh

wg-quick up wg0
sh /root/scripts/monitor-wg.sh &
ping 10.0.0.1
