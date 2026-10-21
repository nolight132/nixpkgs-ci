{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  patchelf,
  glibc,
  pkgsi686Linux,
}:

let
  runtime32 = lib.makeLibraryPath [
    pkgsi686Linux.glibc
    pkgsi686Linux.stdenv.cc.cc.lib
    pkgsi686Linux.openssl
  ];
  runtime64 = lib.makeLibraryPath [
    glibc
    stdenv.cc.cc.lib
  ];
  loader32 = "${lib.getLib pkgsi686Linux.glibc}/lib/ld-linux.so.2";
  loader64 = "${lib.getLib glibc}/lib/ld-linux-x86-64.so.2";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "millennium-bin";
  version = "3.6.2";

  src = fetchurl {
    url = "https://github.com/SteamClientHomebrew/Millennium/releases/download/v${finalAttrs.version}/millennium-v${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-lb2kAYTdZDfaFmgGDsWWHHYvPB5Zkj9TOA5D1Ocg81k=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ patchelf ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib"
    install -m755 usr/lib/millennium/* "$out/lib/"
    install -Dm644 ${./LICENSE.md} "$out/share/licenses/millennium/LICENSE.md"

    for file in libmillennium_x86.so libmillennium_bootstrap_x86.so libmillennium_luavm_x86; do
      patchelf --force-rpath --set-rpath "$out/lib:${runtime32}" "$out/lib/$file"
    done
    for file in libmillennium_hhx64.so libmillennium_bootstrap_hhx64.so libmillennium_pvs64; do
      patchelf --force-rpath --set-rpath "$out/lib:${runtime64}" "$out/lib/$file"
    done
    patchelf --set-interpreter ${loader32} "$out/lib/libmillennium_luavm_x86"
    patchelf --set-interpreter ${loader64} "$out/lib/libmillennium_pvs64"
    runHook postInstall
  '';

  # Check both architectures with their loaders without running Steam or the
  # libraries' constructors. Missing libraries and symbol versions fail here.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    for file in libmillennium_x86.so libmillennium_bootstrap_x86.so libmillennium_luavm_x86; do
      ${loader32} --list "$out/lib/$file"
    done
    for file in libmillennium_hhx64.so libmillennium_bootstrap_hhx64.so libmillennium_pvs64; do
      ${loader64} --list "$out/lib/$file"
    done
    runHook postInstallCheck
  '';

  meta = {
    description = "Steam themes and plugins using official prebuilt Millennium binaries";
    homepage = "https://steambrew.app/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
