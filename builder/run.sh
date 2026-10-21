#!/usr/bin/env bash
set -euo pipefail

: "${CACHIX_CACHE:?Set CACHIX_CACHE}"
: "${CACHIX_AUTH_TOKEN:?Set CACHIX_AUTH_TOKEN}"
: "${FLAKES:?Set FLAKES to newline-separated flake installables}"

interval=${INTERVAL_SECONDS:-900}
max_jobs=${NIX_MAX_JOBS:-2}
cores=${NIX_CORES:-2}
state_dir=${STATE_DIR:-/state}
for value in "$interval" "$max_jobs" "$cores"; do
  if [[ ! $value =~ ^[1-9][0-9]*$ ]]; then
    echo "Interval, job count and core count must be positive integers" >&2
    exit 1
  fi
done

mkdir -p "$state_dir/roots"
cachix use "$CACHIX_CACHE"
touch "$state_dir/ready"

log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }

active_pid=
trap 'if [[ -n $active_pid ]]; then kill "$active_pid" 2>/dev/null || true; fi; exit 0' TERM INT

while true; do
  while IFS= read -r target || [[ -n $target ]]; do
    target=${target%$'\r'}
    [[ -z $target || $target == \#* ]] && continue
    if [[ $target == -* || $target =~ [[:space:]] ]]; then
      log "Invalid installable: $target"
      continue
    fi

    key=$(printf '%s' "$target" | sha256sum)
    key=${key%% *}
    log "Building $target"

    # Watch the build itself: headers and other build-only dependencies must
    # reach Cachix too, even if the final package does not reference them.
    cachix watch-exec "$CACHIX_CACHE" -- \
      nix build "$target" \
        --refresh --no-write-lock-file --keep-going \
        --max-jobs "$max_jobs" --cores "$cores" \
        --out-link "$state_dir/roots/$key" &
    active_pid=$!
    if wait "$active_pid"; then
      # Retry uploads on later passes even when Nix already has the result.
      if for result in "$state_dir/roots/$key"*; do readlink -f "$result"; done \
        | cachix push "$CACHIX_CACHE"; then
        log "Cached $target"
      else
        log "Upload failed for $target; will retry on the next pass"
      fi
    else
      log "Build or upload failed for $target; continuing with the list"
    fi
    active_pid=
  done <<< "$FLAKES"

  # Nix's automatic GC (min-free/max-free) can reclaim old build inputs;
  # result links keep the current successful target outputs alive.
  log "Next pass in ${interval}s"
  sleep "$interval" &
  active_pid=$!
  wait "$active_pid" || true
  active_pid=
done
