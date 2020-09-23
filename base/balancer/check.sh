#!/usr/bin/env sh

function prerouting {

  local server="$1"
  local port="$2"

  echo "PREROUTING -t nat -i eth0 -p udp --dport ${port} -j DNAT --to-destination ${server}:${port}"

}

function postrouting {

  local server="$1"

  echo "POSTROUTING -t nat -o eth1 -p udp --destination ${server} -j SNAT --to-source 12.0.0.2"

}

function add_forward {

  local server="$1"
  local port="$2"

  eval "iptables -A $(prerouting "${server}" "${port}")"
  eval "iptables -A $(postrouting "${server}")"

}

function delete_forward {

  local server="$1"
  local port="$2"

  eval "iptables -D $(prerouting "${server}" "${port}")"
  eval "iptables -D $(postrouting "${server}")"

}

main_server="12.0.0.3"
backup_servers=( "12.0.0.4" )
servers=( "${main_server}" ${backup_servers[@]} )

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
