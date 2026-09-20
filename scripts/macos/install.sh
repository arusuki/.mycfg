#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ]; then
  echo 'This installer requires macOS.' >&2
  exit 1
fi
if [ "$#" -ne 0 ]; then
  echo 'Usage: bash ~/scripts/install_packages.sh' >&2
  exit 1
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/../env.sh"

if ! command -v brew >/dev/null 2>&1; then
  installer=$(mktemp)
  trap 'rm -f "$installer"' EXIT
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
  /bin/bash "$installer"
  source "$script_dir/../env.sh"
fi

brew bundle install --file="$script_dir/Brewfile"
