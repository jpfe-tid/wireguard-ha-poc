#!/usr/bin/env bash

function create_network {

  local network="$1"
  local subnet="$2"
  local gateway="$3"

  # Create the wireguard docker network
  [[ -z "$(docker network ls | grep "${network}")" ]] && docker network create --driver=bridge --subnet="${subnet}" --gateway="${gateway}" "${network}"

}

function stop_container {

  local container_name="$1"

  if [[ ! -z "$(docker ps -a | grep ${container_name})" ]]
  then

    if [[ ! -z "$(docker ps | grep ${container_name})" ]]
    then
      docker kill "${container_name}"
    fi

    docker rm "${container_name}"
  
  else
    echo "No previous ${container_name} container."
  fi

}

function start_wireguard_server {

  local id="$1"
  local name="wireguard-server-${id}"

  # Stop previous server
  stop_container "${name}"

  # Start the wireguard server
  docker run \
    -it \
    --restart unless-stopped \
    -d \
    --name "${name}" \
    --network "${lb_network}" \
    -m "${wireguard_server_memory}" \
    --cpus="${wireguard_server_cpus}" \
    -v "$(pwd)/configurations/server.conf:/etc/wireguard/wg0.conf" \
    --cap-add=NET_ADMIN \
    "${wireguard_image}" "wg-quick up wg0 && sleep 3600"

}

function start_nginx_server {

  local name="balancer"

  # Stop previous server
  stop_container "${name}"

  # Start the wireguard server
  docker run \
    -it \
    -d \
    --name "${name}" \
    --network "${client_network}" \
    -m "${nginx_server_memory}" \
    --cpus="${nginx_server_cpus}" \
    --ip "11.0.0.2" \
    -v "$(pwd)/configurations/nginx.conf:/etc/nginx/nginx.conf" \
    -v "$(pwd)/logs:/logs" \
    "nginx"

  # Add the server to the client network
  docker network connect "${lb_network}" "${name}" --ip "12.0.0.2"

}

function start_balancer_server {

  local name="balancer"

  # Stop previous server
  stop_container "${name}"

  # Start the wireguard server
  docker run \
    -it \
    -d \
    --name "${name}" \
    --network "${client_network}" \
    -m "${nginx_server_memory}" \
    --cpus="${nginx_server_cpus}" \
    --ip "11.0.0.2" \
    --cap-add=NET_ADMIN \
    "${balancer_image}"

  # Add the server to the client network
  docker network connect "${lb_network}" "${name}" --ip "12.0.0.2"

}

function start_wireguard_client {

  local name="wireguard-client"

  # Stop previous server
  stop_container "${name}"

  docker run \
    -it \
    --name "${name}" \
    --network "${client_network}" \
    -m "${wireguard_client_memory}" \
    --cpus="${wireguard_client_cpus}" \
    -v "$(pwd)/configurations/client.conf:/etc/wireguard/wg0.conf" \
    -v "$(pwd)/scripts:/root/scripts" \
    --cap-add=NET_ADMIN \
    "${wireguard_image}" "sh /root/scripts/run-client.sh"

}

function run {

  local balancer="$1"

  if [[ "${balancer}" == "iptables" || "${balancer}" == "nginx" ]]
  then

    # Create the image
    docker build -q -t "${wireguard_image}" "base/wireguard"
    docker build -q -t "${balancer_image}" "base/balancer"

    # Check networks are created
    create_network "${client_network}" 11.0.0.0/24 11.0.0.1
    create_network "${lb_network}" 12.0.0.0/24 12.0.0.1

    # Run servers
    if [[ "${balancer}" == "nginx" ]]
    then
      start_nginx_server
    else
      start_balancer_server
    fi

    start_wireguard_server 1
    start_wireguard_server 2

    # Run the client
    start_wireguard_client

  else

    echo "Balancer type ${balancer} is not allowed. Use one of: [balancer, nginx]"

  fi

}

wireguard_image_name="wireguard"
balancer_image_name="balancer"
image_tag="dev"
wireguard_image="${wireguard_image_name}:${image_tag}"
balancer_image="${balancer_image_name}:${image_tag}"

wireguard_server_cpus="1"
wireguard_server_memory="50m"
wireguard_client_cpus="1"
wireguard_client_memory="50m"
nginx_server_cpus="1"
nginx_server_memory="50m"

client_network="client"
lb_network="lb"

run "$@"
