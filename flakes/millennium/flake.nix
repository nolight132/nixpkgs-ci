{
  description = "Millennium built with nolight's personal nixpkgs";

  inputs = {
    nixpkgs.url = "github:nolight132/nixpkgs/personal";
    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, millennium, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ millennium.overlays.default ];
      };
    in {
      # Keep the expensive Millennium build on this flake's locked nixpkgs.
      # The Steam wrapper can still use the consuming system's package set.
      overlays.default = final: prev:
        (millennium.overlays.default final prev) // {
          millennium = self.packages.${prev.stdenv.hostPlatform.system}.millennium;
        };
      packages.x86_64-linux = {
        inherit (pkgs) millennium millennium-steam;
        default = pkgs.millennium;
        nlohmann-json-32 = pkgs.pkgsi686Linux.nlohmann_json;
      };
    };
}
