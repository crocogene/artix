#!/usr/bin/env bash

basestrap /mnt base seatd-dinit cachyos-keyring cachyos-v4-mirrorlist artix-archlinux-support
fstabgen -U /mnt >> /mnt/etc/fstab