#!/usr/bin/env bash

basestrap -P /mnt base seatd-dinit cachyos-keyring cachyos-mirrorlist cachyos-v4-mirrorlist artix-archlinux-support
fstabgen -U /mnt >> /mnt/etc/fstab