FROM nixos/nix:2.34.9

# Pin the builder tools independently of the flakes being built.
RUN nix --extra-experimental-features 'nix-command flakes' profile add \
    github:NixOS/nixpkgs/c5c4a43b0e8056328ec4529f735cabdb8f1942bb#cachix

COPY run.sh /usr/local/bin/nix-builder
RUN chmod +x /usr/local/bin/nix-builder

ENTRYPOINT ["/usr/local/bin/nix-builder"]
