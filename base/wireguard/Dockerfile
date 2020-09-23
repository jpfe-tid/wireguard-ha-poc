FROM alpine:3.12.0

RUN apk update
RUN apk add -U wireguard-tools 
RUN apk add hping3 --update --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing

WORKDIR /root

ENTRYPOINT [ "sh", "-c" ]
