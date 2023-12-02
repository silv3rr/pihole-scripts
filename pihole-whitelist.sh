#!/bin/sh

# Removes comments etc from source so pihole can add to whitelist
# Example "pihole-whitelist.txt" is included

# Sources:
#   https://discourse.pi-hole.net/t/commonly-whitelisted-domains/212
#   https://firebog.net/

WL_FILE="pihole-whitelist.txt"

l=0
s=0

if echo "$@" | grep -iq '\-h'; then
  printf "Run './%s' to clean up \"%s\" and add to pihole\n" "$(basename "$0")" "$WL_FILE"
  printf "Options: [-l] list/display only, [-s] add single domain\n"
  exit 0
elif echo "$@" | grep -iq '\-l'; then
  l=1
  shift
elif echo "$@" | grep -iq '\-s'; then
  s=1
  shift
fi
if [ -s "$WL_FILE" ]; then
  while read -r i; do
    if [ "$s" -eq 1 ]; then
      set -x
      pihole -w -nr -q "$i"
      set +x
    else
      wl="$wl $i"
    fi
  done <<-EOF
    $( grep -v '^#' "$WL_FILE" | sed -e 's/pihole -w//g' -e 's/ [(-].*//' )
EOF
  wl="$( echo "$wl" | sed -e 's/^ *//' -e 's/  */ /g')"
  if [ "$l" -eq 0 ]; then
    set -x
    pihole -w "$wl"
    set +x
  else
    echo "$wl"
  fi
else
  printf "%s not found\n" "$WL_FILE"
fi
