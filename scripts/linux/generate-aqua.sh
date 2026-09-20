#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo 'Usage: bash ~/scripts/linux/generate-aqua.sh' >&2
  exit 1
fi
if [ "$(uname -s)" != Linux ]; then
  echo 'aqua config generation requires Linux.' >&2
  exit 1
fi
arch=$(uname -m)
case "$arch" in
  x86_64|aarch64|arm64) ;;
  *) printf 'Unsupported Linux architecture: %s\n' "$arch" >&2; exit 1 ;;
esac
libc=$(getconf GNU_LIBC_VERSION 2>/dev/null || true)
if [[ ! "$libc" =~ ^glibc\ ([0-9]+)\.([0-9]+)$ ]]; then
  echo 'Cannot detect glibc with getconf GNU_LIBC_VERSION; musl is not supported by this installer.' >&2
  exit 1
fi
glibc_major=${BASH_REMATCH[1]}
glibc_minor=${BASH_REMATCH[2]}
glibc_at_least() {
  [ "$glibc_major" -gt "$1" ] || { [ "$glibc_major" -eq "$1" ] && [ "$glibc_minor" -ge "$2" ]; }
}
if ! glibc_at_least 2 28; then
  printf 'Unsupported %s: Linux installation requires glibc >= 2.28.\n' "$libc" >&2
  exit 1
fi

# Recheck ELF requirements when updating the pinned releases.
nvim_registry=standard
tree_sitter_registry=standard
glibc_at_least 2 34 || nvim_registry=mycfg-compat
glibc_at_least 2 39 || tree_sitter_registry=mycfg-compat

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mycfg"
mkdir -p "$config_dir"
config_tmp=$(mktemp "$config_dir/.aqua.yaml.XXXXXX")
trap 'rm -f "$config_tmp"' EXIT
{
  printf '# Generated from ~/scripts/linux/aqua.yaml for %s (%s). Do not edit.\n' "$libc" "$arch"
  awk -v nvim_registry="$nvim_registry" -v tree_sitter_registry="$tree_sitter_registry" '
    { print }
    /^  - name: neovim\/neovim@/ { print "    registry: " nvim_registry }
    /^  - name: tree-sitter\/tree-sitter@/ { print "    registry: " tree_sitter_registry }
  ' "$script_dir/aqua.yaml"
} > "$config_tmp"
mv -f "$config_tmp" "$config_dir/aqua.yaml"
printf 'Generated %s/aqua.yaml (%s; nvim: %s; tree-sitter: %s).\n' \
  "$config_dir" "$libc" "$nvim_registry" "$tree_sitter_registry"
