#!/bin/sh

# Removes comments etc from source so pihole can add to whitelist
# Example "pihole-whitelist.txt" is included

# Sources:
#   https://discourse.pi-hole.net/t/commonly-whitelisted-domains/212
#   https://firebog.net/

whitelst="pihole-whitelist.txt"

l=0; s=0
if echo "$@" | grep -iq '\-h'; then
  printf "%s [-l] list/display only, [-s] add single domain\n" "$(basename "$0")"
  printf "cleans up %s and adds to pihole\n" "$whitelst"; exit 0
elif echo "$@" | grep -iq '\-l'; then l=1; shift
elif echo "$@" | grep -iq '\-s'; then s=1; shift; fi
if [ -s "$whitelst" ]; then
  while read -r i; do
    if [ "$s" -eq 1 ]; then set -x; pihole -w -nr -q "$i"; set +x
    else wl="$wl $i"; fi
  done <<-EOF
    $( grep -v '^#' "$whitelst" | sed 's/pihole -w //g' | cut -d\( -f1 )
EOF
  if [ "$l" -eq 0 ]; then
   set -x; pihole -w "${wl# }"; set +x
  else
    echo "${wl# }"
  fi
else
  printf "%s not found\n" "$whitelst"
fi
