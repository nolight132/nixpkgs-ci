{
  description = "Official Millennium binaries packaged for NixOS";

  inputs = {
    nixpkgs.url = "github:nolight132/nixpkgs/personal";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      millennium = pkgs.callPackage ./package.nix { };
    in
    {
      overlays.default = final: prev: {
        millennium = self.packages.${prev.stdenv.hostPlatform.system}.millennium;
        millennium-bin = final.millennium;
        millennium-steam = final.callPackage ./steam.nix { };
      };
      packages.x86_64-linux = {
        inherit millennium;
        millennium-bin = millennium;
        millennium-steam = pkgs.callPackage ./steam.nix { inherit millennium; };
        default = millennium;
      };
    };
}
