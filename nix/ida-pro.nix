{ lib, ... }:

{
  perSystem =
    {
      self',
      pkgs,
      ...
    }:
    let
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

      idaProFhs = pkgs.buildFHSEnv { name = "ida-pro-fhs"; };
    in
    {
      packages.default = self'.packages.ida-pro;
      packages.ida-pro = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "ida-pro";
        version = "9.3.260327";

        src = throw "Provide the source yourself, :クルーレス:";

        nativeBuildInputs = [
          pkgs.auto-patchelf
          pkgs.patch
          pkgs.patchelf
        ];

        dontUnpack = true;

        installPhase = ''
          runHook preInstall

          ${lib.getExe idaProFhs} -c ${
            lib.escapeShellArg (/* bash */ ''
              set -xeuo pipefail;

              cp "$src" 'install.run';
              chmod +x 'install.run';
              ./'install.run' --mode 'unattended' --prefix "$out";
            '')
          }

          mkdir -p "$out/bin";
          ln -s "$out/ida" "$out/bin/";

          runHook postInstall
        '';

        preFixup = ''
          patch "$out/python/init.py" ${./patches/ida-python-extra-paths.patch};

          auto-patchelf \
            --paths "$out" \
            --libs "$out" "$out/plugins/platforms" ${lib.escapeShellArgs patchelfLibs} \
            --append-rpaths ${lib.escapeShellArgs patchelfRpaths};
        '';

        meta.mainProgram = "ida";
      });
    };
}
