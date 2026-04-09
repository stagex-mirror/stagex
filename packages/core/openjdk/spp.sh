#!/bin/sh
# SPP (Source PreProcessor) for OpenJDK bootstrap
# Args can come from $@ OR from $SPP_ARGFILE (one per line, preserves quoting)
# Supports: -K key, -D key=val, -i input, -o output

TMPKEYS=$(mktemp)
TMPDEFS=$(mktemp)
TMPINPUT=$(mktemp)
INFILE=""
OUTFILE=""
NEXT=""

parse_arg() {
  if [ "$NEXT" = "in" ]; then INFILE="$1"; NEXT=""; return; fi
  if [ "$NEXT" = "out" ]; then OUTFILE="$1"; NEXT=""; return; fi
  case "$1" in
    -K*) printf '%s\n' "${1#-K}" >> "$TMPKEYS" ;;
    -D*=*) printf '%s\n' "${1#-D}" >> "$TMPDEFS" ;;
    -i) NEXT=in ;;
    -o) NEXT=out ;;
  esac
}

if [ -n "$SPP_ARGFILE" ] && [ -f "$SPP_ARGFILE" ]; then
  while IFS= read -r arg; do
    parse_arg "$arg"
  done < "$SPP_ARGFILE"
  rm -f "$SPP_ARGFILE"
else
  for arg in "$@"; do
    parse_arg "$arg"
  done
fi

# If -i was given, read from that file; else read from stdin
if [ -n "$INFILE" ] && [ -f "$INFILE" ]; then
  cat "$INFILE" > "$TMPINPUT"
else
  cat > "$TMPINPUT"
fi

# Process and write to OUTFILE if given, else stdout
process() {
python3 -c '
import sys, re

keys = set()
with open(sys.argv[1]) as f:
    for line in f:
        k = line.strip()
        if k: keys.add(k)

defs = {}
with open(sys.argv[2]) as f:
    for line in f:
        line = line.strip()
        if "=" in line:
            k, v = line.split("=", 1)
            defs[k] = v

depth = 0
skip = {0: False}

with open(sys.argv[3]) as inp:
    for line in inp:
        line = line.rstrip("\n")

        if line.lstrip().startswith("#warn"):
            continue

        m = re.match(r"^#if\[(\w+)\]", line)
        if m:
            depth += 1
            skip[depth] = skip.get(depth-1, False) or (m.group(1) not in keys)
            continue

        if re.match(r"^#else\[", line):
            if depth > 0: skip[depth] = not skip[depth]
            continue

        if re.match(r"^#end\[", line):
            if depth > 0: depth -= 1
            continue

        if depth > 0 and skip.get(depth, False):
            continue

        def replace_inline(m):
            key, true_val, false_val = m.group(1), m.group(2), m.group(3) or ""
            return true_val if key in keys else false_val
        line = re.sub(r"\{#if\[(\w+)\]\?([^:}]*)(?::([^}]*))?\}", replace_inline, line)

        for k, v in defs.items():
            line = line.replace("$" + k + "$", v)

        print(line)
' "$TMPKEYS" "$TMPDEFS" "$TMPINPUT"
}

if [ -n "$OUTFILE" ]; then
  mkdir -p "$(dirname "$OUTFILE")"
  process > "$OUTFILE"
else
  process
fi

rm -f "$TMPKEYS" "$TMPDEFS" "$TMPINPUT"
