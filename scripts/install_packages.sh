#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo 'Usage: install_packages.sh [--with-uv|--without-uv]' >&2
  exit 1
fi
case "${1:---without-uv}" in
  --with-uv) export MYCFG_WITH_UV=1 ;;
  --without-uv) export MYCFG_WITH_UV=0 ;;
  --help|-h)
    echo 'Usage: install_packages.sh [--with-uv|--without-uv]'
    exit 0
    ;;
  *) echo 'Usage: install_packages.sh [--with-uv|--without-uv]' >&2; exit 1 ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case "$(uname -s)" in
  Linux) exec bash "$script_dir/linux/install.sh" ;;
  Darwin) exec bash "$script_dir/macos/install.sh" ;;
  *) printf 'Unsupported OS: %s\n' "$(uname -s)" >&2; exit 1 ;;
esac
