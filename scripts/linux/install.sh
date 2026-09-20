#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Linux ]; then
  echo 'This installer requires Linux.' >&2
  exit 1
fi
if [ "$#" -ne 0 ]; then
  echo 'Usage: bash ~/scripts/install_packages.sh' >&2
  exit 1
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bash "$script_dir/generate-aqua.sh"
source "$script_dir/../env.sh"

if ! command -v aqua >/dev/null 2>&1; then
  installer=$(mktemp)
  trap 'rm -f "$installer"' EXIT
  curl -fsSL https://raw.githubusercontent.com/aquaproj/aqua-installer/v4.0.5/aqua-installer -o "$installer"
  printf '451028d56959cc738564885b1dbebc2691ea038ffde04e2472e4d486a3591146  %s\n' "$installer" | sha256sum -c -
  bash "$installer" -v "${AQUA_VERSION:-v2.62.3}"
fi

aqua -c "$MYCFG_AQUA_CONFIG" install
if [ "${MYCFG_WITH_UV:-0}" = 1 ]; then
  aqua -c "$script_dir/uv.yaml" install
fi
