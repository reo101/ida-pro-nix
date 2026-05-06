{ lib, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    let
      mkAddons = id: lib.imap (mkAddon { owner = id; }) addons;

      idaFhsEnv = pkgs.buildFHSEnv {
        name = "ida-pro-fhs";
        targetPkgs = pkgs: [ pkgs.python3 ];
      };

      libext = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
    in
    {
      legacyPackages.ida-pro = (mkRawDerivation { }).extend (
        final: _: {
          inherit system;

          name = "ida-pro";
          version = "9.3.260327";

          src = throw "Provide the source yourself, :クルーレス:";

          pythonRuntime = pkgs.python3;
          pythonLibraryName = "libpython${final.pythonRuntime.pythonVersion}${libext}.1.0";

          coreRuntimeLibs = [
            pkgs.glibc
            pkgs.libxcrypt-legacy
            pkgs.stdenv.cc.cc.lib
            final.pythonRuntime
            pkgs.zlib
          ];

          guiRuntimeLibs = [
            pkgs.at-spi2-core
            pkgs.cairo
            pkgs.dbus
            pkgs.fontconfig
            pkgs.freetype
            pkgs.gdk-pixbuf
            pkgs.glib
            pkgs.gtk3
            pkgs.libdrm
            pkgs.libglvnd
            pkgs.libx11
            pkgs.libxcb
            pkgs.libxcb-cursor
            pkgs.libxcb-image
            pkgs.libxcb-keysyms
            pkgs.libxcb-render-util
            pkgs.libxcb-wm
            pkgs.libxkbcommon
            pkgs.pango
            pkgs.wayland
          ];

          runtimeLibs = final.coreRuntimeLibs ++ final.guiRuntimeLibs;
          runtimeLibraryPath = lib.makeLibraryPath final.runtimeLibs;
          runtimeRpath = lib.concatStringsSep ":" [
            "$out"
            "$out/plugins"
            "$out/loaders"
            "$out/procs"
            "$out/python"
            "$out/python/lib"
            "$out/python/3"
            "$out/python/3/lib"
            "$out/python/PySide6"
            "$out/python/shiboken6"
            "\\$ORIGIN"
            "\\$ORIGIN/.."
            "\\$ORIGIN/../.."
            final.runtimeLibraryPath
          ];

          builder = lib.getExe idaFhsEnv;
          PATH = lib.makeBinPath [
            pkgs.auto-patchelf
            pkgs.patchelf
            pkgs.perl
          ];
          args = [
            "-c"
            /* bash */ ''
              set -xeuo pipefail;

              cp "$src" 'install.run';
              chmod +x 'install.run';
              ./'install.run' --mode 'unattended' --prefix "$out";

              if [ -e "$out/plugins/idapython3.so" ]; then
                chmod u+w "$out/plugins/idapython3.so"
                case "$(${lib.getExe pkgs.patchelf} --print-needed "$out/plugins/idapython3.so")" in
                  *"${final.pythonLibraryName}"*) ;;
                  *) ${lib.getExe pkgs.patchelf} --add-needed "${final.pythonLibraryName}" "$out/plugins/idapython3.so" ;;
                esac
              fi

              runtime_rpath="${final.runtimeRpath}"

              while IFS= read -r -d "" elf; do
                if ${lib.getExe pkgs.patchelf} --print-needed "$elf" >/dev/null 2>&1; then
                  chmod u+w "$elf"

                  if ${lib.getExe pkgs.patchelf} --print-interpreter "$elf" >/dev/null 2>&1; then
                    ${lib.getExe pkgs.patchelf} --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" "$elf"
                  fi

                  old_rpath="$(${lib.getExe pkgs.patchelf} --print-rpath "$elf" 2>/dev/null || true)"
                  if [ -n "$old_rpath" ]; then
                    rpath="$runtime_rpath:$old_rpath"
                  else
                    rpath="$runtime_rpath"
                  fi

                  # Keep this in the IDA process, not in LD_LIBRARY_PATH inherited by debug inferiors.
                  ${lib.getExe pkgs.patchelf} --force-rpath --set-rpath "$rpath" "$elf"
                fi
              done < <(${lib.getExe' pkgs.findutils "find"} "$out" -type f -print0)

              auto-patchelf \
                --paths "$out" \
                --libs "$out" "$out/plugins/platforms" '${
                  lib.replaceStrings [ ":" ] [ "' '" ] (
                    lib.makeLibraryPath [
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
                    ]
                  )
                }';
            ''
          ];
        }
      );
    };
}
