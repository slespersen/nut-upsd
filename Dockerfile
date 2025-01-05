FROM alpine:3.21

LABEL org.label-schema.name=nut-upsd

ARG NUT_VERSION=2.8.2-r2

ENV API_USER=upsmon \
    API_PASSWORD= \
    API_SECRET=nut-upsd-api\
	ADMIN_USER=admin \
	ADMIN_PASSWORD= \
    ADMIN_SECRET=nut-upsd-admin\
    DESCRIPTION=UPS \
    DRIVER=usbhid-ups \
    GROUP=nut \
    MAXAGE=15 \
    NAME=ups \
    POLLINTERVAL= \
    PORT=auto \
    SDORDER= \
    SERIAL= \
    SERVER=master \
    USER=nut \
    VENDORID= \
	SHUTDOWN_CMD="/opt/nut/scripts/shutdown" 

HEALTHCHECK CMD upsc $NAME@localhost:3493 2>&1|grep -q stale && \
    killall -TERM upsmon || true

RUN apk add --no-cache dash && \
    apk add --update --no-cache nut=$NUT_VERSION \
      busybox linux-pam \
      libcrypto3 libssl3 \
      libusb musl net-snmp-libs util-linux

EXPOSE 3493
COPY entrypoint.sh /usr/local/bin/
COPY shutdown /opt/nut/scripts/
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]