#!/usr/bin/env bash
basestrap -KMP -C ~/artix/etc/pacman.conf /mnt \
    system/base system/pacman seatd-dinit iptables-nft \
    cachyos-keyring cachyos-mirrorlist cachyos-v4-mirrorlist artix-archlinux-support \
    gzip-pigz-shim grep-ugrep-shim
fstabgen -U /mnt >> /mnt/etc/fstab