#!/usr/bin/env bash
set -euo pipefail

worker=$(realpath "$(dirname "$0")/run.sh")
test_dir=$(mktemp -d)
worker_pid=
cleanup() {
  if [[ -n $worker_pid ]]; then
    kill "$worker_pid" 2>/dev/null || true
    wait "$worker_pid" 2>/dev/null || true
  fi
  rm -rf "$test_dir"
}
trap cleanup EXIT

mkdir -p "$test_dir/bin" "$test_dir/result"
cat > "$test_dir/bin/cachix" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  use) ;;
  watch-exec) shift 3; exec "$@" ;;
  push) cat >> "$TEST_DIR/pushed" ;;
  *) exit 99 ;;
esac
MOCK
cat > "$test_dir/bin/nix" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$2" >> "$TEST_DIR/built"
[[ $2 != *broken* ]] || exit 42
while [[ $1 != --out-link ]]; do shift; done
ln -sfn "$TEST_DIR/result" "$2"
MOCK
chmod +x "$test_dir/bin/"*

export TEST_DIR=$test_dir
export PATH="$test_dir/bin:$PATH"
export CACHIX_CACHE=test CACHIX_AUTH_TOKEN=test STATE_DIR="$test_dir/state"
export INTERVAL_SECONDS=1
export FLAKES=$'# comment\ngithub:example/broken#default\n--invalid\ngithub:example/working#default\n'
bash "$worker" > "$test_dir/log" 2>&1 &
worker_pid=$!

for _ in {1..100}; do
  if [[ -f $test_dir/pushed ]] && [[ $(wc -l < "$test_dir/pushed") -ge 2 ]]; then
    break
  fi
  sleep 0.05
done
kill "$worker_pid"
wait "$worker_pid"
worker_pid=

[[ $(grep -c broken "$test_dir/built") -ge 2 ]]
[[ $(grep -c working "$test_dir/built") -ge 2 ]]
if grep -q invalid "$test_dir/built"; then
  echo 'Invalid installable reached nix build' >&2
  exit 1
fi
[[ $(wc -l < "$test_dir/pushed") -ge 2 ]]
[[ $(sort -u "$test_dir/pushed") == "$test_dir/result" ]]
grep -q 'Build or upload failed' "$test_dir/log"
grep -q 'Invalid installable' "$test_dir/log"

if INTERVAL_SECONDS=invalid bash "$worker" > /dev/null 2>&1; then
  echo 'Invalid interval was accepted' >&2
  exit 1
fi

echo 'PASS: failed targets retry, later targets build, outputs upload, arguments validate, and SIGTERM stops the loop'
