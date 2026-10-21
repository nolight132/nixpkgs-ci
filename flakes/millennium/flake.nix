{
  description = "Millennium built with nolight's personal nixpkgs";

  inputs = {
    nixpkgs.url = "github:nolight132/nixpkgs/personal";
    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, millennium, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ millennium.overlays.default ];
      };
    in {
      overlays.default = millennium.overlays.default;
      packages.x86_64-linux = {
        inherit (pkgs) millennium millennium-steam;
        default = pkgs.millennium;
        nlohmann-json-32 = pkgs.pkgsi686Linux.nlohmann_json;
      };
    };
}
