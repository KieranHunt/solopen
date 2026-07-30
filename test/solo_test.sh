#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOLO="$ROOT/solo"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0 fail=0

t() {
  local name="$1" want_exit="$2" want_substr="$3"
  shift 3
  local out got
  out="$("$@" 2>&1)"
  got=$?
  if [[ $got -eq $want_exit && "$out" == *"$want_substr"* ]]; then
    pass=$((pass + 1))
    echo "ok - $name"
  else
    fail=$((fail + 1))
    echo "FAIL - $name"
    echo "    want exit $want_exit containing: $want_substr"
    echo "    got exit $got, output:"
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
}

# --- usage / argument validation ---

t "bare invocation prints usage, exits non-zero" 1 "Usage:" "$SOLO"
t "-h prints usage, exits non-zero" 1 "Usage:" "$SOLO" -h
t "--help prints usage, exits non-zero" 1 "Usage:" "$SOLO" --help

t "nonexistent path errors with usage" 1 "Usage:" "$SOLO" /path/that/does/not/exist
t "nonexistent path names the problem" 1 "no such directory" "$SOLO" /path/that/does/not/exist
touch "$TMP/afile"
t "existing file errors with usage" 1 "Usage:" "$SOLO" "$TMP/afile"
t "existing file names the problem" 1 "not a directory" "$SOLO" "$TMP/afile"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
