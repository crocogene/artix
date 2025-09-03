#!/usr/bin/env bash

basestrap -KM /mnt \
    base seatd-dinit \
    cachyos-keyring cachyos-mirrorlist cachyos-v4-mirrorlist artix-archlinux-support \
    gzip-pigz-shim grep-ugrep-shim
fstabgen -U /mnt >> /mnt/etc/fstab