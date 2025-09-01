#!/usr/bin/env bash

. $(dirname "$0")/btrfs_opt.sh

mkfs.vfat -n ESP -F 32 /dev/nvme0n1p1 
mkfs.btrfs /dev/nvme0n1p2 -L tank --force
mount -o $OPT /dev/disk/by-label/tank /mnt
cd /mnt
btrfs subvol create {@,@home,@cache,@swap,@shapshots}  
cd ..
umount /mnt