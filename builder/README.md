# Nix builder

A persistent x86_64-linux builder for Coolify. Each pass builds the newline-separated
`FLAKES` list, uploads new outputs and build dependencies to `nixpkgs-nolight`,
and retries failed targets on the next pass. i686-linux dependencies run natively
on the same host.

## Coolify

Create a Docker Compose application from this repository, with the base directory
`/builder` and Compose file `/compose.yaml`. Set `CACHIX_AUTH_TOKEN` as a secret
environment variable with write access to `nixpkgs-nolight`.

Set `FLAKES` to one installable per line, for example:

```text
github:nolight132/nixpkgs-ci?dir=flakes/millennium#millennium
git+https://git.nolight.dev/nolight/dotfiles.git#nixosConfigurations.desktop.pkgs.vicinae
```

The default list builds Millennium using the wrapper in `flakes/millennium`.
Its lock initially matches the desktop's nixpkgs and upstream Millennium inputs.
Updating that lock is intentional: `--refresh` refreshes remote references but
never silently updates a flake's locked dependencies.

For an exact match to a committed desktop configuration, use its package directly:

```text
git+https://git.nolight.dev/nolight/dotfiles.git#nixosConfigurations.desktop.pkgs.millennium
```

The current uncommitted desktop lock may differ from the published dotfiles.
Keep the wrapper lock aligned with desktop, or use this wrapper as the desktop's
Millennium input and make its `nixpkgs` input follow the desktop's `nixpkgs`.

`INTERVAL_SECONDS` defaults to 900, `NIX_MAX_JOBS` and `NIX_CORES` to 2. The
container is limited to 4 CPUs and 10 GiB RAM. `/nix` and `/state` are persistent
volumes. Logs are rotated and available in Coolify. There are no exposed ports.

The container runs Nix without its additional sandbox inside Docker and needs no
privileged mode or host Docker socket. Only list flakes you trust.

## Local

```sh
export CACHIX_AUTH_TOKEN=...
docker compose up -d --build
docker compose logs -f
```

To refresh the wrapper deliberately:

```sh
nix flake update --flake flakes/millennium
```

Commit and push the lock so desktop and builder can consume the same revisions.
