FROM alpine:latest
LABEL maintainer="akshshar"
LABEL description="ISC DHCP Server and NGINX on alpine"

RUN apk update && apk add --no-cache supervisor dhcp nginx

RUN mkdir /config /data

COPY overlay/ /
RUN chmod 755 /entrypoint.sh 
COPY supervisor.conf /etc/supervisord.conf

VOLUME /config
VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
