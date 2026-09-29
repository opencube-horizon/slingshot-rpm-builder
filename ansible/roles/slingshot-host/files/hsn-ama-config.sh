#!/usr/bin/env bash

set -euo pipefail

# 'ip' lives in /usr/bin on SUSE but /usr/sbin on RHEL-family, and the systemd
# default PATH covers neither reliably; pin a PATH that resolves it on both.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

IFACE="$1"
TRIES=10
SLEEP=3

echo "Configuring interface $IFACE..."

for attempt in $(seq 1 $TRIES) ; do
  echo "Attempt $attempt..."
  if ip link set dev "$IFACE" up \
     && ip addr flush dev "$IFACE" || true \
     && /usr/sbin/lldptool -tni "$IFACE" \
     && /usr/sbin/lldptool set-lldp -i "$IFACE" adminStatus=rxtx \
     && /opt/slingshot/slingshot-network-config/default/bin/slingshot-network-cfg-lldp "$IFACE"
  then
     /opt/slingshot/slingshot-network-config/default/bin/slingshot-ifroute.sh "$IFACE" || true
     echo "Success on attempt $attempt."
     exit 0
  fi
  echo "Attempt $attempt failed."
  sleep "$SLEEP"
done

echo "All $TRIES attempts failed for $IFACE."
exit 1
