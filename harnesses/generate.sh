#!/usr/bin/env bash
#
# Generate AIR for every MSL harness so it can be inspected and documented.
#
# For each harnesses/**/<name>.metal this produces, under harnesses/**/air/:
#   <name>.air     -- AIR bitcode object (metal -c), the real compiler output
#   <name>.ll      -- human-readable AIR as LLVM IR text (-S -emit-llvm)
#   <name>.O0.ll   -- unoptimized IR, closer to a 1:1 view of the source
#
# The .ll files are the primary inspection artifact. .O0.ll is handy for seeing
# structure the optimizer would otherwise fold away.
#
# Usage:
#   ./generate.sh            # build everything
#   ./generate.sh compute    # only harnesses/compute
#   STD=metal3.2 ./generate.sh   # override the language standard
set -euo pipefail

cd "$(dirname "$0")"

STD="${STD:-metal3.2}"
FILTER="${1:-}"

compile_one() {
    local src="$1"
    local dir; dir="$(dirname "$src")"
    local base; base="$(basename "$src" .metal)"
    local out="$dir/air"
    mkdir -p "$out"

    # A harness may pin its own language standard with a `// STD: metalX.Y`
    # directive on any line (e.g. the Metal 4 tensor harnesses). Otherwise the
    # global $STD default applies.
    local std="$STD"
    local pinned; pinned="$(grep -oE '// *STD: *metal[0-9.]+' "$src" | grep -oE 'metal[0-9.]+' | head -1 || true)"
    if [[ -n "$pinned" ]]; then std="$pinned"; fi

    echo "  $src (std=$std)"
    xcrun metal -std="$std" -c                "$src" -o "$out/$base.air"
    xcrun metal -std="$std" -S -emit-llvm     "$src" -o "$out/$base.ll"
    xcrun metal -std="$std" -S -emit-llvm -O0 "$src" -o "$out/$base.O0.ll"
}

count=0
while IFS= read -r -d '' src; do
    if [[ -n "$FILTER" && "$src" != *"/$FILTER/"* ]]; then
        continue
    fi
    compile_one "$src"
    count=$((count + 1))
done < <(find . -name '*.metal' -print0 | sort -z)

echo "Generated AIR for $count harness(es)."
