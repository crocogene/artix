#!/usr/bin/env bash

pacman -S --noconfirm pacman-contrib 
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47 

basestrap -KMP -C ~/artix/etc/pacman.conf /mnt \
    system/base system/pacman seatd-dinit iptables-nft \
    cachyos-keyring cachyos-mirrorlist cachyos-v4-mirrorlist \
    gzip-pigz-shim grep-ugrep-shim zlib-ng-compat \
    2>basestrap_errors.txt

fstabgen -U /mnt >> /mnt/etc/fstab