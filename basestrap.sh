#!/usr/bin/env bash
cp ~/artix/etc/pacman.conf /mnt/etc
basestrap -KM /mnt \
    base seatd-dinit \
    cachyos-keyring cachyos-mirrorlist cachyos-v4-mirrorlist artix-archlinux-support \
    gzip-pigz-shim grep-ugrep-shim
fstabgen -U /mnt >> /mnt/etc/fstab