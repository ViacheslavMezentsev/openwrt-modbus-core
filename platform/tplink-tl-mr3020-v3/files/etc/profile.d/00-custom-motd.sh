#!/bin/sh
# Sourced by profile: isolate variables/functions and remain silent for automation.
(
case $- in
 *i*) ;;
 *) [ "${1-}" = "--show" ] || exit 0 ;;
esac
board=$(cat /tmp/sysinfo/board_name 2>/dev/null)
case "$board" in tplink,tl-mr3020-v3|tplink_tl-mr3020-v3) ;; *) exit 0 ;; esac
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
if [ ! -t 1 ] || [ "${TERM:-dumb}" = dumb ]; then GREEN=''; CYAN=''; NC=''; fi
section() { printf '\n %b%s%b\n' "$CYAN" "$1" "$NC"; }
row() { printf '   %-16s %s\n' "$1" "$2"; }
[ ! -r /etc/openwrt_release ] || . /etc/openwrt_release
printf '\n'
printf "${GREEN}"
printf "    __  _______ _____ ____ ___   ____       _____  \n"
printf "   /  |/  / __ \__  // __ \__ \ / __ \_   _|__  /  \n"
printf "  / /|_/ / /_/ //_ </ / / /_/ // / / / | / //_ <   \n"
printf " / /  / / _, _/__/ / /_/ / __// /_/ /| |/ /__/ /   \n"
printf "/_/  /_/_/ |_/____/\____/____/\____/ |___/____/    \n"
printf "${NC}\n"


model=$(cat /tmp/sysinfo/model 2>/dev/null)
printf ' %s / %s\n' "${DISTRIB_DESCRIPTION:-OpenWrt (version unavailable)}" "${model:-TP-Link TL-MR3020 v3}"
printf ' Kernel %s\n' "$(uname -r)"
section System
row 'Uptime:' "$(uptime | sed 's/.*up //;s/, *load average.*//')"
row 'Load (1/5/15m):' "$(awk '{print $1 " / " $2 " / " $3}' /proc/loadavg)"
row 'RAM available:' "$(awk '/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2;seen=1}END{if(seen)printf "%.1f / %.1f MiB",a/1024,t/1024;else print "unavailable"}' /proc/meminfo)"
row 'Overlay free:' "$(df -k /overlay | awk 'NR==2{printf "%.1f / %.1f MiB",$4/1024,$2/1024}')"
section Network
for iface in br-lan eth0 eth1; do
 addr=$(ip -4 addr show dev "$iface" 2>/dev/null | awk '/inet /{print $2}')
 [ -z "$addr" ] || row "$iface:" "$addr"
done
if command -v iw >/dev/null 2>&1 && iw_info=$(iw dev 2>/dev/null); then
 ap=$(printf '%s\n' "$iw_info" | awk '$1=="type" && $2=="AP"{n++}END{print n+0}')
 row 'Wi-Fi AP ifaces:' "$ap (interface count)"
else row 'Wi-Fi AP:' 'unavailable'; fi
row 'Switch:' "$(cat /tmp/switch_position 2>/dev/null || printf unknown)"
row 'Profile:' 'not managed (mr3020-modes planned)'
section Peripherals
count_nodes() { n=0; for f in "$@"; do [ ! -e "$f" ] || n=$((n+1)); done; printf '%s' "$n"; }
if command -v lsusb >/dev/null 2>&1; then
 row 'USB devices:' "$(lsusb | grep -v 'Linux Foundation' | wc -l) (excluding root hubs)"
else row 'USB devices:' 'unavailable (lsusb missing)'; fi
row 'Serial ACM/USB:' "$(count_nodes /dev/ttyACM*) / $(count_nodes /dev/ttyUSB*)"
row 'Audio nodes:' "$(count_nodes /dev/snd/pcm*)"
row 'Video nodes:' "$(count_nodes /dev/video*)"
mounts=$(awk '$1 ~ /^\/dev\/sd/ {print $2}' /proc/mounts)
row 'SD/USB mounts:' "${mounts:-none}"
section Applications
now=$(date +%s)
field() { value=$(jsonfilter -i "$1" -e "$2" 2>/dev/null); printf '%s' "${value:-unknown}"; }
age() { case "$1" in ''|*[!0-9]*) printf unknown;; *) if [ "$1" -gt "$now" ]; then printf 'clock mismatch'; else printf '%ss' "$((now-$1))"; fi;; esac; }
if command -v jsonfilter >/dev/null 2>&1; then
 cache=/tmp/modbus/cache.json; demo=/tmp/modbus/demo-status.json
 # Lua programs may appear under interpreter names: status freshness is separate.
 row 'Core reported:' "$(field "$cache" '@.meta.status') / heartbeat age: $(age "$(field "$cache" '@.meta.last_tick')")"
 row 'Demo reported:' "$(field "$demo" '@.status') / update age: $(age "$(field "$demo" '@.updated_at')")"
 row 'Transport:' "$(field "$cache" '@.meta.transport_status') / valid: $(field "$cache" '@.meta.data_valid')"
 error=$(field "$cache" '@.meta.transport_error')
 [ "$error" = unknown ] || row 'Transport error:' "$error"
else row 'Status:' 'unavailable (jsonfilter missing)'; fi
printf '\n'

)
