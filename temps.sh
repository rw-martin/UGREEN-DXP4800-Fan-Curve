#!/usr/bin/env bash

echo "System Thermal Report - $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================================"

printf "%-4s %-6s %-18s %-14s %-6s %-6s\n" "BAY" "DEV" "MODEL" "SERIAL" "TEMP" "STATE"
echo "--------------------------------------------------------------------------------"

temps=()
output=()

for disk in sda sdb sdc sdd; do
    if [ -b "/dev/$disk" ]; then

        model=$(lsblk -dn -o MODEL /dev/$disk | xargs)
        serial=$(lsblk -dn -o SERIAL /dev/$disk | xargs)

        # --- BAY DETECTION ---
        bay=$(ls -l /dev/disk/by-path/ 2>/dev/null | grep "$disk" | sed -n 's/.*ata-\([0-9]\+\).*/\1/p' | head -n1)
        [ -z "$bay" ] && bay="?"

        # --- TEMP ---
        temp=$(smartctl -A /dev/$disk | awk '/Temperature_Celsius/ {print $10}')
        [ -z "$temp" ] && temp=$(smartctl -A /dev/$disk | awk '/Temperature:/ {print $2}')

        if [ -z "$temp" ]; then
            state="N/A"
            temp_val=0
        else
            temp_val=$temp
            if [ "$temp" -ge 55 ]; then
                state="HOT"
            elif [ "$temp" -ge 50 ]; then
                state="WARM"
            else
                state="OK"
            fi
        fi

        temps+=("$temp_val")
        output+=("$temp_val|$bay|/dev/$disk|$model|$serial|$temp|$state")
    fi
done

IFS=$'\n' sorted=($(sort -t'|' -k1 -nr <<<"${output[*]}"))
unset IFS

for line in "${sorted[@]}"; do
    IFS='|' read -r t bay dev model serial temp state <<< "$line"

    if [ "$t" -ge 55 ]; then
        color="\033[31m"
    elif [ "$t" -ge 50 ]; then
        color="\033[33m"
    else
        color="\033[32m"
    fi

    printf "${color}%-4s %-6s %-18s %-14s %-6s %-6s\033[0m\n" \
        "$bay" "$dev" "$model" "$serial" "${temp}°C" "$state"
done

echo "--------------------------------------------------------------------------------"

# Summary
if [ ${#temps[@]} -gt 0 ]; then
    max=$(printf "%s\n" "${temps[@]}" | sort -nr | head -n1)
    min=$(printf "%s\n" "${temps[@]}" | sort -n | head -n1)
    avg=$(printf "%s\n" "${temps[@]}" | awk '{sum+=$1} END {printf "%.1f", sum/NR}')
    delta=$((max - min))

    echo "Summary:"
    echo "  Max Disk Temp : ${max}°C"
    echo "  Min Disk Temp : ${min}°C"
    echo "  Avg Disk Temp : ${avg}°C"
    echo "  Delta         : ${delta}°C"
fi

echo "================================================================================"
