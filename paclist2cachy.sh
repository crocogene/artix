#!/usr/bin/env bash

# Скрипт: проверить зависимости установленных пакетов, доступных в указанном репозитории
# Использование: ./paclist2cachy.sh <имя_репозитория>
# Пример: ./paclist2cachy.sh cachyos-znver4f

repo="$1"

# --- Проверка параметра ---
if [[ -z "$repo" ]]; then
    echo "Ошибка: не указано имя репозитория."
    echo "Использование: $0 <имя_репозитория>"
    exit 1
fi

# --- Проверка наличия репозитория через pacman-conf ---
if ! pacman-conf -r "$repo" &>/dev/null; then
    echo "Ошибка: репозиторий '$repo' не найден в конфигурации pacman."
    echo "Доступные репозитории:"
    pacman-conf --repo-list
    exit 1
fi

# --- Определяем архитектуру системы ---
arch=$(uname -m)

# --- Шаг 1: Кэшируем список пакетов из указанного репозитория ---
echo "Загружаю список пакетов из репозитория '$repo'..."
mapfile -t repo_pkgs < <(pacman -Sl "$repo" | awk '{print $2}')

# --- Шаг 2: Собираем список установленных пакетов текущей архитектуры ---
mapfile -t installed_pkgs < <(pacman -Qi | awk -F': ' -v arch="$arch" '
    /^Name/ {name=$2}
    /^Architecture/ {if($2==arch) print name}
')

# --- Шаг 3: Проверяем каждый установленный пакет ---
for pkg in "${installed_pkgs[@]}"; do
    # Проверяем, есть ли пакет в указанном репозитории
    if printf '%s\n' "${repo_pkgs[@]}" | grep -qx "$pkg"; then
        # Получаем список зависимостей пакета из репозитория
        deps=$(pacman -Si "$repo"/"$pkg" | awk -F': ' '/^Depends On/{print $2}')

        # Пропускаем, если зависимостей нет
        if [[ -z "$deps" || "$deps" == "<none>" ]]; then
            continue
        fi

        # --- Шаг 4: Проверяем каждую зависимость ---
        missing_deps=()
        for dep in $deps; do
            dep=${dep%,*}   # убираем запятые
            dep=${dep%%=*}  # убираем версии =1.2.3
            dep=${dep%%<*}  # убираем версии <1.2.3
            dep=${dep%%>*}  # убираем версии >1.2.3

            [[ -z "$dep" ]] && continue

            # Если зависимость не установлена, добавляем
            if ! pacman -Qq "$dep" &>/dev/null; then
                missing_deps+=("$dep")
            fi
        done

        # --- Шаг 5: Выводим пакет и список недостающих зависимостей ---
        if [[ ${#missing_deps[@]} -gt 0 ]]; then
            printf "%-30s needed:%s\n" "$pkg" "$(IFS=,; echo "${missing_deps[*]}")"
        fi
    fi
done