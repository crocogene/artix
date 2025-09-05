#!/usr/bin/env bash

pacman -S base-devel git python \
    micro most bat lsd dust systeroid sd fd fzf jq dash world/tmux terminus-font tealdeer \
    zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting powerline git-zsh-completion \
    dracut limine efibootmgr \
    turnstile-dinit iwd-dinit  \
    btrfs-progs nvme-cli openssh world/plymout \
    linux-cachyos-hardened amd-ucode \
    linux-cachyos-hardened-nvidia nvidia-utils-dinit switch-amd-nvidia \
    linux-firmware-amdgpu linux-firmware-nvidia linux-firmware-realtek linux-firmware-intel \
    sof-firmware

mkdir -p /boot/EFI/limine
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/    
dracut --regenerate-all