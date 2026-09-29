#!/bin/bash
#
# Copyright 2021-2024 Hewlett Packard Enterprise Development LP. All rights reserved.
#

set -euo pipefail
shopt -s nullglob

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <netif>" 1>&2
    exit 1
fi

MATCH=$1
IFNAME=$MATCH
PATTERN="????:??:??.?"
HSN_PREFIX=hsn
NETWORK_CLASS=0x020000

VENDOR_MELLANOX=0x15b3
DEVICE_CONNECTX_5=0x1017

VENDOR_HPE_CRAY=0x17db
DEVICE_SS11_1P=0x0501

DEVICE_IDS=("${VENDOR_MELLANOX}:${DEVICE_CONNECTX_5}" "${VENDOR_HPE_CRAY}:${DEVICE_SS11_1P}")

hsn_index=-1

# get an orderd list of the PCI network devices
for PCIDEV in /sys/devices/pci*/$PATTERN /sys/devices/pci*/$PATTERN/$PATTERN ; do
    [[ -r "$PCIDEV/class" ]] || continue
    [[ -r "$PCIDEV/vendor" ]] || continue
    [[ -r "$PCIDEV/device" ]] || continue
    [[ -r "$PCIDEV/net" ]] || continue
    CLASS=$(<"$PCIDEV/class")
    [[ $CLASS == "$NETWORK_CLASS" ]] || continue
    VENDOR=$(<"$PCIDEV/vendor")
    DEVICE=$(<"$PCIDEV/device")

    # change the name if this is a high speed connection
    if [[ " ${DEVICE_IDS[*]} " =~ [[:space:]]${VENDOR}:${DEVICE}[[:space:]] ]] ; then
        PREFIX=${HSN_PREFIX}
        NETDEV=$(ls -1d "$PCIDEV"/net/* "$PCIDEV"/*/net/* 2>/dev/null)
        [[ -e $NETDEV ]] || NETDEV=""
        NETIF=${NETDEV##*/}
        hsn_index=$((hsn_index+1))
        if [[ $NETIF == "$MATCH" ]]; then
            IFNAME=$PREFIX${hsn_index}
            break
        fi
    fi
done

if [[ $IFNAME == hsn* ]] ; then
    echo "$IFNAME"
    exit 0
fi

# leave non-HSN devices to the rest of the udev rules
exit 1
