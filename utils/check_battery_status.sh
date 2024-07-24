#!/bin/sh

# Путь к информации о батарее
BAT_PATH="/sys/class/power_supply/BAT0"

# Критический уровень заряда батареи (по умолчанию 15%, если не указано)
CRITICAL_LEVEL=${1:-15}

# Путь к файлу уведомлений
NOTIFIED_FILE="$HOME/.config/waybar/scripts/notified"

# Функция для проверки существования файла
file_exists() {
    [ -f "$1" ]
}

# Считываем статус и уровень заряда батареи
if [ -e "$BAT_PATH/status" ] && [ -e "$BAT_PATH/capacity" ]; then
    battery_status=$(cat "$BAT_PATH/status")
    battery_capacity=$(cat "$BAT_PATH/capacity")
else
    echo "Ошибка: Не удалось найти файлы с информацией о батарее."
    exit 1
fi

# Проверяем, если уровень заряда ниже критического и батарея разряжается
if [ "$battery_capacity" -le "$CRITICAL_LEVEL" ] && [ "$battery_status" = "Discharging" ]; then
    if ! file_exists "$NOTIFIED_FILE"; then
        notify-send --urgency=critical --icon=dialog-warning "Низкий уровень батареи" "Текущий заряд: $battery_capacity%"
        touch "$NOTIFIED_FILE"
    fi
elif file_exists "$NOTIFIED_FILE"; then
    rm "$NOTIFIED_FILE"
fi