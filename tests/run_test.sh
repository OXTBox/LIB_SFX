#!/usr/bin/env bash
# LIB_SFX test: runs tests/sfx_test.txt in a real Windows LiveCode (LIB_MCP's standalone, port 8767).
# Needs build.bat to have run once (C:\xtsfx\extension). Silent: nothing is played.
# Prints the lines and ends with PASS or FAIL.
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
OUT="$("$HERE/../../LIB_MCP/tools/lcmcp" --standalone run - < "$HERE/sfx_test.txt" 2>&1)"
echo "$OUT"
if echo "$OUT" | grep -q "^names: " && ! echo "$OUT" | grep -qi "false\|error"; then
  echo "PASS: $(echo "$OUT" | grep -c ':') lines, none false"
else
  echo "FAIL"; exit 1
fi
