#!/usr/bin/env bash

basestrap -P /mnt \
    system/base seatd-dinit \
    cachyos-keyring cachyos-mirrorlist cachyos-v4-mirrorlist artix-archlinux-support \
    gzip-pigz-shim
fstabgen -U /mnt >> /mnt/etc/fstab