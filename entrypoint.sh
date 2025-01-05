#!/bin/sh -e

# Display the contents of /etc/passwd
cat /etc/passwd

# Check if the secrets directory exists
if [ -d /run/secrets ]; then
  # Check and retrieve API password if the secret file exists
  if [ -s /run/secrets/$API_SECRET ]; then
    API_PASSWORD=$(cat /run/secrets/$API_SECRET)
  fi

  # Check and retrieve Admin password if the secret file exists
  if [ -s /run/secrets/$ADMIN_SECRET ]; then
    ADMIN_PASSWORD=$(cat /run/secrets/$ADMIN_SECRET)
  fi
fi

# Initial setup if not already done
if [ ! -e /etc/nut/.setup ]; then
  # Copy local UPS configuration if available
  if [ -e /etc/nut/local/ups.conf ]; then
    cp /etc/nut/local/ups.conf /etc/nut/ups.conf
  else
    # Check for SERIAL when using usbhid-ups driver
    if [ -z "$SERIAL" ] && [ "$DRIVER" = "usbhid-ups" ]; then
      echo "** This container may not work without setting SERIAL **"
    fi

    # Generate UPS configuration
    cat <<EOF >>/etc/nut/ups.conf
[$NAME]
  driver = $DRIVER
  port = $PORT
  desc = "$DESCRIPTION"
EOF

    # Append additional configurations if set
    [ -n "$SERIAL" ] && echo "  serial = \"$SERIAL\"" >> /etc/nut/ups.conf
    [ -n "$POLLINTERVAL" ] && echo "  pollinterval = $POLLINTERVAL" >> /etc/nut/ups.conf
    [ -n "$VENDORID" ] && echo "  vendorid = $VENDORID" >> /etc/nut/ups.conf
    [ -n "$SDORDER" ] && echo "  sdorder = $SDORDER" >> /etc/nut/ups.conf
  fi

  # Adjust MAXAGE if not set to 15
  [ "$MAXAGE" -ne 15 ] && sed -i -e "s/^[# ]*MAXAGE [0-9]\+/MAXAGE $MAXAGE/" /etc/nut/upsd.conf

  # Copy local UPS daemon configuration if available
  if [ -e /etc/nut/local/upsd.conf ]; then
    cp /etc/nut/local/upsd.conf /etc/nut/upsd.conf
  else
    # Generate default UPS daemon configuration
    cat <<EOF >>/etc/nut/upsd.conf
LISTEN 0.0.0.0
EOF
  fi

  # Retrieve API password
  if [ -z "$API_PASSWORD" ]; then
    API_PASSWORD=$(cat /run/secrets/api_password)
  fi

  # Retrieve Admin password
  if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(cat /run/secrets/admin_password)
  fi

  # Prepare the user configuration
  UPS_USERS_CONFIG="/etc/nut/upsd.users"

  # Initialize the config file
  cat >$UPS_USERS_CONFIG <<EOF
[$ADMIN_USER]
  password = $ADMIN_PASSWORD
  actions = set
  actions = fsd
  instcmds = all
EOF

  # Append API user configuration only if API_PASSWORD is set
  if [ -n "$API_PASSWORD" ]; then
    cat >>$UPS_USERS_CONFIG <<EOF
[$API_USER]
  password = $API_PASSWORD
  upsmon master
EOF
  fi

  # Copy local UPS monitor configuration if available
  if [ -e /etc/nut/local/upsmon.conf ]; then
    cp /etc/nut/local/upsmon.conf /etc/nut/upsmon.conf
  else
    # Generate default UPS monitor configuration
    cat <<EOF >>/etc/nut/upsmon.conf
MONITOR $NAME@localhost 1 $API_USER $API_PASSWORD $SERVER
RUN_AS_USER $USER
EOF
  fi

  # Mark setup as complete
  touch /etc/nut/.setup
fi

# Set permissions and ownership
chgrp $GROUP /etc/nut/*
chmod 640 /etc/nut/*
mkdir -p -m 2750 /dev/shm/nut
chown $USER:$GROUP /dev/shm/nut
[ -e /var/run/nut ] || ln -s /dev/shm/nut /var/run

# Issue #15 - Change pid warning message from "No such file" to "Ignoring"
echo 0 > /var/run/nut/upsd.pid && chown $USER:$GROUP /var/run/nut/upsd.pid
echo 0 > /var/run/upsmon.pid

# Start UPS driver and services
/usr/sbin/upsdrvctl -u root start
/usr/sbin/upsd -u $USER
exec /usr/sbin/upsmon -D
