#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"
shellcheck -x scripts/bootstrap.sh scripts/install_packages.sh scripts/tests/validate.sh
luacheck --config .config/nvim/.luacheckrc .config/nvim
lua5.1 scripts/tests/keymaps.lua .config/nvim/lua
bash scripts/tests/aqua.sh

# Test state (e.g. Harpoon lists) must not affect the user's Neovim data.
test_state=$(mktemp -d)
trap 'rm -rf "$test_state"' EXIT
if [ -z "${MYCFG_TEST_PLUGIN_DIR:-}" ]; then
  MYCFG_TEST_PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
fi
export MYCFG_TEST_PLUGIN_DIR
export XDG_DATA_HOME="$test_state/data"
export XDG_STATE_HOME="$test_state/state"
export XDG_CACHE_HOME="$test_state/cache"
cd .config/nvim
nvim --clean -l tests/util.lua
nvim --clean -l tests/plugins.lua
nvim --clean -l tests/tab-lsp.lua
