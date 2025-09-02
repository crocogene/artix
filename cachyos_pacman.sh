#!/usr/bin/env bash

pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47 
pacman -U --noconfirm \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.0.0.r7.g1f38429-1-x86_64.pkg.tar.zst'
pacman-key --populate archlinux
cp ~/artix/etc/pacman.conf /etc/pacman.conf
pacman -Sy
