#!/usr/bin/env sh

function add_forward {

  server="$1"
  port="$2"

  iptables -A FORWARD -p udp --dport "${port}" -d "${server}" -j ACCEPT
  iptables -A FORWARD -p udp --sport "${port}" -s "${server}" -j ACCEPT
  iptables -A PREROUTING -t nat -i eth0 -p udp --dport "${port}" -j DNAT --to-destination "${server}:${port}"

}

function delete_forward {

  server="$1"
  port="$2"

  iptables -D FORWARD -p udp --dport "${port}" -d "${server}" -j ACCEPT
  iptables -D FORWARD -p udp --sport "${port}" -s "${server}" -j ACCEPT
  iptables -D PREROUTING -t nat -i eth0 -p udp --dport "${port}" -j DNAT --to-destination "${server}:${port}"

}

main_server="12.0.0.3"
backup_servers=( "12.0.0.4" )
servers=( "${main_server}" ${backup_servers[@]} )

from_address="11.0.0.1"
port="1500"
cycle_seconds=5

current_server=""

# Infinite lookup loop
while true
do

  next_server=""

  # Get the server to forward to
  for server in ${servers[@]}
  do

    echo "${server} | ${port} | ${server}:${port}"

    # Select the first responding server as the next server to connect to
    if $(nc -z -u "${server}:${port}")
    then
      next_server="${server}"
      break
    fi

  done

  echo "Current server: ${current_server}"
  echo "Next server: ${next_server}"

  # If there is a server change, then change the iptables
  if [ "${next_server}" != "${current_server}" ]
  then

    # If this is not the first time that a forward is set, then delete previous rules
    if [ "${current_server}" != "" ]
    then

      delete_forward "${current_server}" "${port}"
      echo "Deleted previous routes."
    
    fi

    add_forward "${next_server}" "${port}"
    echo "Added new routes."

    current_server="${next_server}"

  fi
  
  # Sleep before next server lookup
  sleep "${cycle_seconds}"

done
