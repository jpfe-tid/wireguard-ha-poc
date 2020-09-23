#!/usr/bin/env sh

while true
do

  if ! ping -c 1 10.0.0.1 > /dev/null
  then

    # Restart the wireguard network
    wg-quick down wg0
    wg-quick up wg0

    echo "Restarted interface wg0."

  fi

  # Sleep some time
  sleep 5

done
