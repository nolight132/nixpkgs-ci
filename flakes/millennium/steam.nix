{
  steam,
  openssl,
  pkgsi686Linux,
  lib,
  jq,
  millennium,
  extraPkgs ? (_: [ ]),
  extraLibraries ? (_: [ ]),
  extraEnv ? { },
  extraProfile ? "",
  ...
}@args:
let
  millenniumLibs = [
    millennium
    pkgsi686Linux.openssl
    openssl
  ];

  millenniumEnv = {
    # consumed by millennium internally.
    MILLENNIUM_RUNTIME_PATH = "${millennium}/lib/libmillennium_x86.so";
  };

  millenniumProfile = ''
    mkdir -p "$HOME/.local/share/Steam/ubuntu12_32" "$HOME/.local/share/Steam/ubuntu12_64"
    ln -sf ${millennium}/lib/libmillennium_bootstrap_x86.so "$HOME/.local/share/Steam/ubuntu12_32/libXtst.so.6"
    ln -sf ${millennium}/lib/libmillennium_bootstrap_hhx64.so "$HOME/.local/share/Steam/ubuntu12_64/libXtst.so.6"

    # Match DISTRO_NIX behavior: the flake manages updates to the read-only
    # package. Preserve the user's themes, plugins and all other preferences.
    millennium_config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/millennium"
    mkdir -p "$millennium_config_dir"
    millennium_config="$millennium_config_dir/config.json"
    if [ ! -f "$millennium_config" ]; then
      printf '%s\n' '{"general":{"checkForMillenniumUpdates":false}}' > "$millennium_config"
    elif ! ${jq}/bin/jq -e '.general.checkForMillenniumUpdates == false' "$millennium_config" >/dev/null; then
      millennium_config_tmp=$(mktemp "$millennium_config.XXXXXX")
      if ${jq}/bin/jq '.general.checkForMillenniumUpdates = false' "$millennium_config" > "$millennium_config_tmp"; then
        mv "$millennium_config_tmp" "$millennium_config"
      else
        rm -f "$millennium_config_tmp"
      fi
    fi
  '';

  upstreamArgs = removeAttrs args [
    "steam"
    "openssl"
    "pkgsi686Linux"
    "millennium"
    "jq"
  ];
in
steam.override (
  upstreamArgs
  // {
    extraPkgs = pkgs: extraPkgs pkgs;
    extraLibraries = pkgs: millenniumLibs ++ (extraLibraries pkgs);
    extraEnv = extraEnv // millenniumEnv;
    extraProfile = millenniumProfile + "\n" + extraProfile;
  }
)
