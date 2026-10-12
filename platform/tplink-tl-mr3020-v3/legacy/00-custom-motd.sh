#!/bin/sh

# --- Цвета ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Сбор информации ---
UPTIME=$(uptime | sed 's/.*up //' | sed 's/,.*//')
LOAD=$(cut -d ' ' -f1 /proc/loadavg)
IP=$(ip addr show br-lan 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
[ -z "$IP" ] && IP=$(ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
KERNEL=$(uname -r)

# Память из /proc/meminfo
MEM_TOTAL=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
MEM_FREE=$(awk '/MemFree/ {print int($2/1024)}' /proc/meminfo)
MEM_USED=$((MEM_TOTAL - MEM_FREE))
MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))

# Диск
DISK_TOTAL=$(df -k / | awk 'NR==2 {print $2}')
DISK_FREE=$(df -k / | awk 'NR==2 {print $4}')
DISK_PERC=$(df -k / | awk 'NR==2 {print $5}')

DISK_FREE_FMT=$(awk "BEGIN {
  if ($DISK_FREE < 1024)
    printf \"%dКБ\", $DISK_FREE
  else
    printf \"%.1fМБ\", $DISK_FREE/1024
}")
DISK_TOTAL_FMT=$(awk "BEGIN {
  if ($DISK_TOTAL < 1024)
    printf \"%dКБ\", $DISK_TOTAL
  else
    printf \"%.1fМБ\", $DISK_TOTAL/1024
}")

# USB, видео и аудио устройства
# USB устройства — считаем все кроме Linux Foundation (внутренние контроллеры)
USB_COUNT=$(lsusb 2>/dev/null | grep -v 'Linux Foundation' | wc -l)

# ACM устройства (BluePill, Arduino и т.д.)
ACM_TTY=$(ls /dev/ttyACM* 2>/dev/null | wc -l)
USB_TTY=$(ls /dev/ttyUSB* 2>/dev/null | wc -l)

# Видео и аудио
VIDEO_DEV=$(ls /dev/video* 2>/dev/null | wc -l)
AUDIO_DEV=$(ls /dev/snd/pcm* 2>/dev/null | wc -l)

# Положение переключателя
SWITCH=$(cat /tmp/switch_position 2>/dev/null || echo "unknown")

# --- ASCII-арт ---
printf "${GREEN}"
printf "    __  _______ _____ ____ ___   ____       _____  \n"
printf "   /  |/  / __ \__  // __ \__ \ / __ \_   _|__  /  \n"
printf "  / /|_/ / /_/ //_ </ / / /_/ // / / / | / //_ <   \n"
printf " / /  / / _, _/__/ / /_/ / __// /_/ /| |/ /__/ /   \n"
printf "/_/  /_/_/ |_/____/\____/____/\____/ |___/____/    \n"
printf "${NC}\n"

# --- Приветствие ---
printf " Welcome to ${GREEN}OpenWrt 19.07.9${NC} on ${YELLOW}MR3020 v3${NC}\n"
printf " Kernel: ${YELLOW}%s${NC}\n" "$KERNEL"
printf "\n"
# --- Статистика ---
# Ширина метки 16, значения 20 — двоеточия выровнены в обеих колонках
printf " ${CYAN}%16s${NC} ${GREEN}%-20s${NC} ${CYAN}%16s${NC} ${GREEN}%s${NC}\n"  "System load:" "$LOAD" "Uptime:" "$UPTIME"
printf " ${CYAN}%16s${NC} ${GREEN}%-20s${NC} ${CYAN}%16s${NC} ${GREEN}%s${NC}\n"  "Memory usage:" "$MEM_PERC% of ${MEM_TOTAL}MB" "IP address:" "$IP"
printf " ${CYAN}%16s${NC} ${GREEN}%s${NC}\n"  "Usage of /:" "$DISK_FREE_FMT free of $DISK_TOTAL_FMT ($DISK_PERC used)"
printf " ${CYAN}%16s${NC} ${GREEN}%-20s${NC} ${CYAN}%16s${NC} ${GREEN}%s${NC}\n"  "Video devices:" "$VIDEO_DEV" "Audio devices:" "$AUDIO_DEV"
printf " ${CYAN}%16s${NC} ${GREEN}%-20s${NC} ${CYAN}%16s${NC} ${GREEN}%s${NC}\n"  "USB devices:" "$USB_COUNT" "ACM/USB tty:" "${ACM_TTY}/${USB_TTY}"
printf " ${CYAN}%16s${NC} ${GREEN}%s${NC}\n"  "Switch mode:" "$SWITCH"
printf "\n"
