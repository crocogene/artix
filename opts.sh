#!/usr/bin/env bash

btrf_opt=compress-force=zstd:-1,noatime,commit=60
esp_part=/dev/"$1"p1
esp_label=ESP
tank_part=/dev/"$1"p2
tank_label=tank