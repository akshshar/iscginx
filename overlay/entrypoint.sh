#!/usr/bin/env sh
set -e

# Copy default config files
if [ ! -f "/config/dhcpd.conf" ]; then
    cp /defaults/dhcpd.conf /config/dhcpd.conf
fi

if [ ! -f "/config/nginx.conf" ]; then
    cp /defaults/nginx.conf /config/nginx.conf
fi

# Ensure lease db exists
touch /config/dhcpd.leases

# Set permissions
chown -R $PUID:$PGID /config
chown -R $PUID:$PGID /data

exec "$@"
