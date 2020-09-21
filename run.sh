#!/usr/bin/env bash

function create_network {

  network="$1"
  subnet="$2"
  gateway="$3"

  # Create the wireguard docker network
  [[ -z "$(docker network ls | grep "${network}")" ]] && docker network create --driver=bridge --subnet="${subnet}" --gateway="${gateway}" "${network}"

}

function stop_container {

  container_name="$1"

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

  id="$1"
  name="wireguard-server-${id}"

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
    "${image}" "wg-quick up wg0 && sleep 3600"

}

function start_nginx_server {

  name="nginx-lb"

  # Stop previous server
  stop_container "${name}"

  # Start the wireguard server
  docker run \
    -it \
    -d \
    --name "${name}" \
    --network "${lb_network}" \
    -m "${nginx_server_memory}" \
    --cpus="${nginx_server_cpus}" \
    -v "$(pwd)/configurations/nginx.conf:/etc/nginx/nginx.conf" \
    "nginx"

  # Add the server to the client network
  docker network connect "${client_network}" "nginx-lb"

}

function start_wireguard_client {

  name="wireguard-client"

  # Stop previous server
  stop_container "${name}"

  docker run \
    -it \
    --name "${name}" \
    --network "${client_network}" \
    -m "${wireguard_client_memory}" \
    --cpus="${wireguard_client_cpus}" \
    -v "$(pwd)/configurations/client.conf:/etc/wireguard/wg0.conf" \
    --cap-add=NET_ADMIN \
    "${image}" "wg-quick up wg0 && ping 10.0.0.1"

}

image_name="wireguard"
image_tag="dev"
image="${image_name}:${image_tag}"

wireguard_server_cpus="1"
wireguard_server_memory="50m"
wireguard_client_cpus="1"
wireguard_client_memory="50m"
nginx_server_cpus="1"
nginx_server_memory="50m"

client_network="client"
lb_network="lb"

# Create the image
docker build -q -t "${image}" "base"

# Check networks are created
create_network "${client_network}" 11.0.0.0/24 11.0.0.1
create_network "${lb_network}" 12.0.0.0/24 12.0.0.1

# Run servers
start_nginx_server
start_wireguard_server 1
start_wireguard_server 2

# Run the client
start_wireguard_client
