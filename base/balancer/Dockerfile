FROM alpine:3.12.0

RUN apk update
RUN apk add -U bash iptables

WORKDIR /root

COPY check.sh /root

ENTRYPOINT [ "bash" ]

CMD [ "check.sh" ]
