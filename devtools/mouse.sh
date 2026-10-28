#!/usr/bin/env bash
F="$(dirname "$(readlink -f "$0")")/mouse.fifo"
send() { echo "$*" > "$F"; }
moveto() {
  local tx=$1 ty=$2
  for i in $(seq 1 25); do
    read cx cy < <(hyprctl cursorpos | tr -d ',')
    local dx=$((tx - cx)) dy=$((ty - cy))
    if [ ${dx#-} -le 1 ] && [ ${dy#-} -le 1 ]; then return 0; fi
    local sx=$(( dx > 60 ? 60 : (dx < -60 ? -60 : dx) ))
    local sy=$(( dy > 60 ? 60 : (dy < -60 ? -60 : dy) ))
    send rel $sx $sy; sleep 0.04
  done
}
case "$1" in
  move) moveto "$2" "$3" ;;
  click) moveto "$2" "$3"; sleep 0.15; send click "${4:-left}" ;;
  raw) shift; send "$@" ;;
esac
