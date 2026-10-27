#!/bin/sh
# check-result.sh <expected.txt> <challenge.log> -- compare a submitted seed-challenge hash log with the
# published table (aien-dev/omega-mv seed/challenge/expected.txt at the commit in omega.ref).
# Prints RESULT ACCEPTED (exit 0) or RESULT REFUSED with each reason (exit 1); exit 2 = usage.
# What this proves: the log is complete and every hash in it equals the published value. It cannot
# prove that the run happened on the machine the log names; anyone can type a log. The Actions run in
# this repository is the run you can watch.
# Host glue (POSIX sh + awk), kept outside the chain it checks on purpose; no .om successor planned.
set -u
[ $# -eq 2 ] && [ -r "$1" ] && [ -r "$2" ] || { echo "usage: check-result.sh <expected.txt> <challenge.log>" >&2; exit 2; }
exp=$1
log=$(mktemp) || exit 2
trap 'rm -f "$log"' EXIT
tr -d '\r' < "$2" > "$log"
bad=0
no() { printf 'REFUSED %s\n' "$*"; bad=$((bad+1)); }
has() { grep -qxF -- "$1" "$log" || grep -qx -- "$(printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g') [0-9]*ms" "$log"; }

pin=$(awk '$1=="pin"{print $2}' "$exp")
[ -n "$pin" ] || { echo "usage: $exp names no pin" >&2; exit 2; }
grep -qxF "pin $pin" "$log" || no "log does not name pin $pin"
grep -q '^host .*aarch64' "$log" || no "host line does not say aarch64"

while read -r kind name sha bytes; do
  case $kind in
    input) grep -qxF "PASS input $name $sha $bytes" "$log" || no "input $name: no PASS line with $sha $bytes" ;;
    rung)
      if [ "$name" = omc ]; then
        for st in 1 2 3; do has "stage$st PASS rung omc $sha $bytes" || no "omc stage$st: no PASS line with $sha $bytes"; done
        omc=$sha
      else
        has "PASS rung $name $sha $bytes" || no "rung $name: no PASS line with $sha $bytes"
      fi ;;
  esac
done < "$exp"

if grep -qE '(^|^stage[123] )(FAIL|NOT_RUN) ' "$log"; then no "log contains FAIL or NOT_RUN lines"; fi
last=$(grep '^CHALLENGE ' "$log" | tail -n 1)
[ "$last" = "CHALLENGE PASS pin=$pin omc=${omc:-}" ] || no "final line is '$last', not CHALLENGE PASS pin=$pin omc=${omc:-}"

if [ "$bad" = 0 ]; then echo "RESULT ACCEPTED pin=$pin omc=$omc"; exit 0; fi
echo "RESULT REFUSED reasons=$bad"
exit 1
