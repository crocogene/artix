#!/usr/bin/env bash

pacman -Qi | awk -F': ' '/^Name/{n=$2}/^Version/{v=$2}/^Architecture/{a=$2; printf "%-25s %-20s %-10s\n", n, v, a}' | sort