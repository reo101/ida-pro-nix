{ lib, ... }:

{
  perSystem =
    {
      self',
      pkgs,
      system,
      ...
    }:
    let
      libext = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;

      patchelfLibs = lib.map (pkg: "${lib.getLib pkg}/lib") [
        pkgs.at-spi2-core
        pkgs.cairo
        pkgs.dbus
        pkgs.fontconfig
        pkgs.freetype
        pkgs.gdk-pixbuf
        pkgs.glib
        pkgs.gtk3
        pkgs.libgcc
        pkgs.libglvnd
        pkgs.libx11
        pkgs.libxcrypt-legacy
        pkgs.libxkbcommon
        pkgs.pango
        pkgs.qt6.qtbase
        pkgs.qt6.qtwayland
        pkgs.stdenv.cc.cc.lib
      ];

      patchelfRpaths = lib.map (pkg: "${lib.getLib pkg}/lib") [
        pkgs.libsecret
      ];
    in
    {
      packages.default = self'.packages.ida-pro;
      packages.ida-pro =
        lib.flip pkgs.callPackage
          {
            src = throw "Provide the source yourself, :クルーレス:";
          }
          (
            {
              # HACK: default `throw` value not set here because guess what `pkgs.src` yields...
              src,
              version ? "9.3.260327",
            }:
            derivation {
              inherit system;

              name = "ida-pro";
              inherit version;

              inherit src;

              builder = lib.getExe (pkgs.buildFHSEnv { name = "ida-pro-fhs"; });
              PATH = lib.makeBinPath [
                pkgs.auto-patchelf
                pkgs.patchelf
              ];
              args = [
                "-c"
                /* bash */ ''
                  set -xeuo pipefail;

                  cp "$src" 'install.run';
                  chmod +x 'install.run';
                  ./'install.run' --mode 'unattended' --prefix "$out";

                  auto-patchelf \
                    --paths "$out" \
                    --libs "$out" "$out/plugins/platforms" ${lib.escapeShellArgs patchelfLibs} \
                    --append-rpaths ${lib.escapeShellArgs patchelfRpaths};

                  mkdir -p "$out/bin";
                  ln -s "$out/ida" "$out/bin/";
                ''
              ];
            }
            // {
              passthru = {
                meta.mainProgram = "ida";
              };
            }
          );
    };
}
