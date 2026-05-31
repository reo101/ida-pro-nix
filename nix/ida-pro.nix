{ lib, ... }:

{
  perSystem =
    {
      self',
      pkgs,
      ...
    }:
    let
      autoPatchelfLibs = [
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
        pkgs.openssl
        pkgs.curl
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
          pkgs.autoPatchelfHook
          pkgs.patchelf
          pkgs.copyDesktopItems
        ];

        dontConfigure = true;
        dontBuild = true;

        unpackPhase = ''
          runHook preUnpack

          ${lib.getExe idaProFhs} -c ${
            lib.escapeShellArg (/* bash */ ''
              set -xeuo pipefail;

              cp "$src" 'install.run';
              chmod +x 'install.run';
              ./'install.run' --mode 'unattended' --prefix "$PWD/ida-pro";
            '')
          }

          sourceRoot="$PWD/ida-pro"

          runHook postUnpack
        '';

        patches = [
          ./patches/ida-python-extra-paths.patch
        ];

        installPhase = ''
          runHook preInstall

          cp -aT . "$out"

          mkdir -p "$out/bin";
          ln -s "$out/ida" "$out/bin/";

          install -Dm644 "$out/appico.png" "$out/share/pixmaps/${finalAttrs.pname}.png";

          runHook postInstall
        '';

        desktopItems = [
          (pkgs.makeDesktopItem {
            name = finalAttrs.pname;
            exec = finalAttrs.meta.mainProgram;
            icon = finalAttrs.pname;
            comment = finalAttrs.meta.description;
            desktopName = "IDA Pro";
            genericName = "Interactive Disassembler";
            categories = [ "Development" ];
            startupWMClass = "IDA";
          })
        ];

        buildInputs = lib.map lib.getLib autoPatchelfLibs;
        appendRunpaths = patchelfRpaths;

        preFixup = ''
          if [ -d "$out/plugins/platforms" ]; then
            addAutoPatchelfSearchPath --no-recurse "$out/plugins/platforms"
          fi
        '';

        meta = {
          description = "A powerful disassembler, decompiler and a versatile debugger. In one tool.";
          homepage = "https://hex-rays.com/ida-pro";
          license = lib.licenses.unfree;
          mainProgram = "ida";
        };
      });
    };
}
