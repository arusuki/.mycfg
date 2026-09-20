#!/usr/bin/env bash
# Offline; leaves user files untouched.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
cat > "$test_dir/bin/getconf" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$MYCFG_TEST_LIBC"
EOF
cat > "$test_dir/bin/uname" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -s) printf '%s\n' "${MYCFG_TEST_OS:-Linux}" ;;
  -m) printf '%s\n' "${MYCFG_TEST_ARCH:-x86_64}" ;;
esac
EOF
chmod +x "$test_dir/bin/"*
export PATH="$test_dir/bin:$PATH"
export XDG_CONFIG_HOME="$test_dir/config with spaces"
export AQUA_ROOT_DIR="$test_dir/aqua"
export MYCFG_TEST_LIBC='glibc 2.31'
generated="$XDG_CONFIG_HOME/mycfg/aqua.yaml"

check_registry() {
  local actual
  actual=$(awk -v package="$1" '$2 == "name:" && index($3, package "@") == 1 { getline; print $2 }' "$generated")
  [ "$actual" = "$2" ] || { printf '%s: expected %s, got %s\n' "$1" "$2" "$actual" >&2; exit 1; }
}
for MYCFG_TEST_ARCH in x86_64 aarch64; do
  export MYCFG_TEST_ARCH
  while read -r version nvim tree_sitter; do
    export MYCFG_TEST_LIBC="glibc $version"
    bash "$script_dir/linux/generate-aqua.sh" > "$test_dir/output" 2> "$test_dir/errors"
    check_registry neovim/neovim "$nvim"
    check_registry tree-sitter/tree-sitter "$tree_sitter"
    grep -q 'name: nodejs/node@v' "$generated"
  done <<'EOF'
2.28 mycfg-compat mycfg-compat
2.31 mycfg-compat mycfg-compat
2.33 mycfg-compat mycfg-compat
2.34 standard mycfg-compat
2.38 standard mycfg-compat
2.39 standard standard
2.40 standard standard
2.100 standard standard
3.0 standard standard
EOF
done

# Failed detection must preserve the previous config.
cp "$generated" "$test_dir/previous.yaml"
for MYCFG_TEST_LIBC in 'glibc 2.16' 'glibc 2.17' 'glibc 2.27' 'musl 1.2.5' ''; do
  export MYCFG_TEST_LIBC
  if bash "$script_dir/linux/generate-aqua.sh" > "$test_dir/output" 2>&1; then
    echo "Unexpected success for libc: $MYCFG_TEST_LIBC" >&2; exit 1
  fi
  cmp "$generated" "$test_dir/previous.yaml"
done
export MYCFG_TEST_LIBC='glibc 2.31' MYCFG_TEST_ARCH=riscv64
if bash "$script_dir/linux/generate-aqua.sh" > "$test_dir/output" 2>&1; then exit 1; fi
export MYCFG_TEST_ARCH=x86_64 MYCFG_TEST_OS=Darwin
if bash "$script_dir/linux/generate-aqua.sh" > "$test_dir/output" 2>&1; then exit 1; fi
unset MYCFG_TEST_OS

# Stop bootstrap at its first Git operation, before any writes.
cat > "$test_dir/bin/git" <<'EOF'
#!/usr/bin/env bash
touch "$MYCFG_TEST_GIT_LOG"
exit 97
EOF
chmod +x "$test_dir/bin/git"
export MYCFG_TEST_GIT_LOG="$test_dir/git.log"
for MYCFG_TEST_LIBC in 'glibc 2.17' 'glibc 2.27' 'glibc 2.28' 'glibc 2.31' 'glibc 3.0' 'musl 1.2.5' ''; do
  export MYCFG_TEST_LIBC
  rm -f "$MYCFG_TEST_GIT_LOG"
  result=0
  bash "$script_dir/bootstrap.sh" --without-uv > "$test_dir/output" 2>&1 || result=$?
  case "$MYCFG_TEST_LIBC" in
    'glibc 2.28'|'glibc 2.31'|'glibc 3.0')
      [ "$result" -eq 97 ] && [ -f "$MYCFG_TEST_GIT_LOG" ] ;;
    *)
      [ "$result" -eq 1 ] && [ ! -e "$MYCFG_TEST_GIT_LOG" ]
      grep -q 'glibc >= 2.28' "$test_dir/output" ;;
  esac
done
export MYCFG_TEST_LIBC='glibc 2.31'

# Sourcing twice must not duplicate global entries.
for test_shell in bash zsh; do
  command -v "$test_shell" >/dev/null 2>&1 || continue
  AQUA_GLOBAL_CONFIG="$HOME/scripts/linux/aqua.yaml:/tmp/other-aqua.yaml:$generated" \
    AQUA_POLICY_CONFIG=/tmp/other-policy.yaml \
    "$test_shell" -c '
      set -eu
      source "$1/env.sh"
      source "$1/env.sh"
      [ "$AQUA_GLOBAL_CONFIG" = "$MYCFG_AQUA_CONFIG:/tmp/other-aqua.yaml" ]
      [ "$AQUA_POLICY_CONFIG" = "$HOME/scripts/linux/aqua-policy.yaml:/tmp/other-policy.yaml" ]
    ' test "$script_dir"
done

# First-run fallback, before a generated config exists.
mv "$generated" "$test_dir/generated.yaml"
for test_shell in bash zsh; do
  command -v "$test_shell" >/dev/null 2>&1 || continue
  AQUA_GLOBAL_CONFIG=/tmp/other-aqua.yaml "$test_shell" -c '
    set -eu
    source "$1/env.sh"
    source "$1/env.sh"
    [ "$AQUA_GLOBAL_CONFIG" = "$HOME/scripts/linux/aqua.yaml:/tmp/other-aqua.yaml" ]
  ' test "$script_dir"
done
mv "$test_dir/generated.yaml" "$generated"

cat > "$test_dir/bin/aqua" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MYCFG_TEST_AQUA_LOG"
EOF
chmod +x "$test_dir/bin/aqua"
export MYCFG_TEST_AQUA_LOG="$test_dir/aqua.log"
for MYCFG_TEST_LIBC in 'glibc 2.17' 'glibc 2.27'; do
  export MYCFG_TEST_LIBC
  if bash "$script_dir/linux/install.sh" > "$test_dir/output" 2>&1; then exit 1; fi
  [ ! -e "$MYCFG_TEST_AQUA_LOG" ]
done
export MYCFG_TEST_LIBC='glibc 2.31'
MYCFG_WITH_UV=0 bash "$script_dir/linux/install.sh" > "$test_dir/output"
[ "$(cat "$MYCFG_TEST_AQUA_LOG")" = "-c $generated install" ]
check_registry neovim/neovim mycfg-compat
check_registry tree-sitter/tree-sitter mycfg-compat
: > "$MYCFG_TEST_AQUA_LOG"
MYCFG_WITH_UV=1 bash "$script_dir/linux/install.sh" > "$test_dir/output"
[ "$(wc -l < "$MYCFG_TEST_AQUA_LOG")" -eq 2 ]
grep -Fx -- "-c $script_dir/linux/uv.yaml install" "$MYCFG_TEST_AQUA_LOG" >/dev/null
echo 'aqua configuration tests passed.'
