#!/usr/bin/env bash

pacman-key --lsign-key F3B607488DB35A47 
pacman -Uy 'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.0.0.r7.g1f38429-1-x86_64.pkg.tar.zst'