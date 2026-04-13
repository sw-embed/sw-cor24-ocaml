#!/usr/bin/env bash
#
# vendor-fetch.sh -- materialize vendored toolchain artifacts from
# the manifests committed under vendor/<tool>/<version>/version.json.
#
# For the OCaml project, tools are a mix of:
#   - Host binaries (pa24r, pl24r, cor24-run) built with cargo
#   - COR24 artifacts (p24p.s, pvm.s, runtime.spc) copied as-is
#
# Usage:
#   ./scripts/vendor-fetch.sh           -- fetch all tools
#   ./scripts/vendor-fetch.sh --check   -- verify artifacts exist
#   ./scripts/vendor-fetch.sh --help
#
# Dependencies: bash, jq, git, cargo (for host binaries).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor"
ACTIVE_ENV="$VENDOR_DIR/active.env"

cd "$REPO_ROOT"

# --- Argument parsing -------------------------------------------------------

MODE="fetch"

while [ $# -gt 0 ]; do
    case "$1" in
        --check)
            MODE="check"
            shift
            ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

# --- Load active.env -------------------------------------------------------

if [ ! -f "$ACTIVE_ENV" ]; then
    echo "error: $ACTIVE_ENV not found" >&2
    exit 4
fi

# shellcheck source=/dev/null
. "$ACTIVE_ENV"

# --- Helpers ----------------------------------------------------------------

manifest_get() {
    jq -r "$2" "$1"
}

resolve_local_repo() {
    # $1=manifest path
    # repo_path_local is relative to the repo root
    local local_path abs
    local_path="$(manifest_get "$1" .repo_path_local)"
    if [ "$local_path" != "null" ] && [ "$local_path" != "TBD" ]; then
        abs="$(cd "$REPO_ROOT" && cd "$local_path" 2>/dev/null && pwd)"
        if [ -n "$abs" ] && [ -d "$abs/.git" ]; then
            echo "$abs"
            return 0
        fi
    fi
    echo ""
}

# --- Fetch Pascal compiler artifacts ---------------------------------------

fetch_pascal() {
    local version="$SW_PASCAL_VERSION"
    local dest="$VENDOR_DIR/sw-pascal/$version"
    local manifest="$dest/version.json"
    local upstream

    echo "--- sw-pascal $version ---"

    if [ ! -f "$manifest" ]; then
        echo "error: manifest not found: $manifest" >&2
        return 1
    fi

    upstream="$(resolve_local_repo "$manifest")"
    if [ -z "$upstream" ]; then
        echo "error: sw-pascal: cannot resolve upstream repo" >&2
        return 1
    fi

    local commit
    commit="$(manifest_get "$manifest" .commit)"

    # Pascal compiler is p24p.s (COR24 assembly, not a host binary)
    local p24p_src="$upstream/compiler/p24p.s"
    local runtime_spc_src="$upstream/runtime/runtime.spc"
    local runtime_spi_src="$upstream/runtime/runtime.spi"

    if [ "$MODE" = "check" ]; then
        local ok=0
        [ -f "$dest/bin/p24p.s" ] && echo "  p24p.s: ok" || { echo "  p24p.s: MISSING"; ok=1; }
        [ -f "$dest/bin/runtime.spc" ] && echo "  runtime.spc: ok" || { echo "  runtime.spc: MISSING"; ok=1; }
        return $ok
    fi

    echo "  upstream: $upstream (commit $commit)"

    if [ -f "$p24p_src" ]; then
        cp "$p24p_src" "$dest/bin/p24p.s"
        echo "  copied: p24p.s"
    else
        echo "  warning: p24p.s not found at $p24p_src" >&2
    fi

    if [ -f "$runtime_spc_src" ]; then
        cp "$runtime_spc_src" "$dest/bin/runtime.spc"
        echo "  copied: runtime.spc"
    else
        echo "  warning: runtime.spc not found at $runtime_spc_src" >&2
    fi

    if [ -f "$runtime_spi_src" ]; then
        cp "$runtime_spi_src" "$dest/bin/runtime.spi"
        echo "  copied: runtime.spi"
    else
        echo "  info: runtime.spi not found (optional)"
    fi

    # Pre-built runtime unit binary
    local rt_p24_src="$upstream/runtime/p24p_rt.p24"
    if [ -f "$rt_p24_src" ]; then
        cp "$rt_p24_src" "$dest/bin/p24p_rt.p24"
        echo "  copied: p24p_rt.p24"
    else
        echo "  info: p24p_rt.p24 not found (needed for unit mode)"
    fi
}

# --- Fetch P-code toolchain artifacts ---------------------------------------

fetch_pcode() {
    local version="$SW_PCODE_VERSION"
    local dest="$VENDOR_DIR/sw-pcode/$version"
    local manifest="$dest/version.json"
    local upstream

    echo "--- sw-pcode $version ---"

    if [ ! -f "$manifest" ]; then
        echo "error: manifest not found: $manifest" >&2
        return 1
    fi

    upstream="$(resolve_local_repo "$manifest")"
    if [ -z "$upstream" ]; then
        echo "error: sw-pcode: cannot resolve upstream repo" >&2
        return 1
    fi

    local commit
    commit="$(manifest_get "$manifest" .commit)"

    if [ "$MODE" = "check" ]; then
        local ok=0
        [ -f "$dest/bin/pvm.s" ] && echo "  pvm.s: ok" || { echo "  pvm.s: MISSING"; ok=1; }
        [ -f "$dest/bin/pa24r" ] && echo "  pa24r: ok" || { echo "  pa24r: MISSING"; ok=1; }
        [ -f "$dest/bin/pl24r" ] && echo "  pl24r: ok" || { echo "  pl24r: MISSING"; ok=1; }
        return $ok
    fi

    echo "  upstream: $upstream (commit $commit)"

    # pvm.s is a COR24 assembly file, copy directly
    local pvm_src="$upstream/vm/pvm.s"
    if [ -f "$pvm_src" ]; then
        cp "$pvm_src" "$dest/bin/pvm.s"
        echo "  copied: pvm.s"
    else
        echo "  warning: pvm.s not found at $pvm_src" >&2
    fi

    # pa24r and pl24r are host Rust binaries
    local pa24r_src="$upstream/target/release/pa24r"
    local pl24r_src="$upstream/target/release/pl24r"

    if [ -f "$pa24r_src" ]; then
        cp "$pa24r_src" "$dest/bin/pa24r"
        chmod +x "$dest/bin/pa24r"
        echo "  copied: pa24r"
    else
        echo "  warning: pa24r not found at $pa24r_src (run 'cargo build --release' in sw-cor24-pcode)" >&2
    fi

    if [ -f "$pl24r_src" ]; then
        cp "$pl24r_src" "$dest/bin/pl24r"
        chmod +x "$dest/bin/pl24r"
        echo "  copied: pl24r"
    else
        echo "  warning: pl24r not found at $pl24r_src (run 'cargo build --release' in sw-cor24-pcode)" >&2
    fi

    # p24-load linker for multi-unit images
    local p24load_src="$upstream/target/release/p24-load"
    if [ -f "$p24load_src" ]; then
        cp "$p24load_src" "$dest/bin/p24-load"
        chmod +x "$dest/bin/p24-load"
        echo "  copied: p24-load"
    else
        echo "  warning: p24-load not found at $p24load_src (run 'cargo build --release' in sw-cor24-pcode)" >&2
    fi
}

# --- Fetch emulator ---------------------------------------------------------

fetch_em24() {
    local version="$SW_EM24_VERSION"
    local dest="$VENDOR_DIR/sw-em24/$version"
    local manifest="$dest/version.json"

    echo "--- sw-em24 $version ---"

    if [ ! -f "$manifest" ]; then
        echo "error: manifest not found: $manifest" >&2
        return 1
    fi

    if [ "$MODE" = "check" ]; then
        # cor24-run can be system-installed or vendored
        if [ -f "$dest/bin/cor24-run" ] || command -v cor24-run >/dev/null 2>&1; then
            echo "  cor24-run: ok"
            return 0
        else
            echo "  cor24-run: MISSING"
            return 1
        fi
    fi

    # Try system-installed cor24-run first
    if command -v cor24-run >/dev/null 2>&1; then
        echo "  cor24-run: using system-installed $(which cor24-run)"
        return 0
    fi

    local upstream
    upstream="$(resolve_local_repo "$manifest")"
    if [ -z "$upstream" ]; then
        echo "error: sw-em24: cannot resolve upstream repo" >&2
        return 1
    fi

    local cor24_src="$upstream/target/release/cor24-run"
    if [ -f "$cor24_src" ]; then
        cp "$cor24_src" "$dest/bin/cor24-run"
        chmod +x "$dest/bin/cor24-run"
        echo "  copied: cor24-run"
    else
        echo "  warning: cor24-run not found at $cor24_src (run 'cargo build --release' in sw-cor24-emulator)" >&2
    fi
}

# --- Main -------------------------------------------------------------------

echo "vendor-fetch: mode=$MODE"
echo ""

fetch_pascal
echo ""
fetch_pcode
echo ""
fetch_em24
echo ""

echo "vendor-fetch: done"
