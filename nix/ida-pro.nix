{ lib, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (import ./helpers.nix { inherit lib pkgs system; }) mkRawDerivation fetchHiddenTorrent;

      mkLicense =
        let
          mkSignature =
            let
              chop = n: l: lib.genList (k: lib.substring (k * n) n l) (lib.stringLength l / n);

              # HACK: using IFD for the exponentiation
              pow =
                base: exponent: module:
                let
                  drv = pkgs.runCommand "mod-exp" { nativeBuildInputs = [ pkgs.bc ]; } ''
                    echo '16o 16i ${base} ${exponent} ${module} | p' \
                    | DC_LINE_LENGTH=0 dc \
                    | tr -d '\n' \
                    > $out
                  '';
                in
                lib.readFile drv;

              n = "93AF7A8E3A6EB93D1B4D1FB7EC29299D2BC8F3CE5F84BFE88E47DDBDD5550C3CE3D2B16A2E2FBD0FBD919E8038BB05752EC92DD1498CB283AA087A93184F1DD9DD5D5DF7857322DFCD70890F814B58448071BBABB0FC8A7868B62EB29CC2664C8FE61DFBC5DB0EE8BF6ECF0B65250514576C4384582211896E5478F9CB42FDED";
              d = "7498027049140B81158DBAB99F7ED002D1B9980EB732E85947E7E4F42F2832151FA6562B67D4D8A0A3221ED1045DC0F0B9258FF611A4F8B8C99AE78199ED9E4DAEC2F9579F3FF31C79C4A219B6EAA4002F8235D8634E1C7A01D332571D710D64DD64D44D814126B7BF8D60167845A5B1BE47FF687B79364413BBF3B7BB6AC877";
            in
            lib.flip lib.pipe [
              (payload: { inherit payload; })
              lib.toJSON
              (lib.hashString "sha256")
              lib.toUpper
              (h: lib.strings.replicate 33 "42" + h + lib.strings.replicate 63 "00")
              (m: pow m d n)
              (chop 2)
              lib.reverseList
              lib.concatStrings
            ];

          mkAddon =
            {
              owner,
              id-prefix ? "48-1337-B00B",
            }:
            i: code: {
              id = "${id-prefix}-${lib.fixedWidthString 2 "0" (lib.toString i)}";
              inherit code owner;
              start_date = "2025-07-20 00:00:00";
              end_date = "2033-12-31 23:59:59";
            };

          addons = [
            "LUMINA"
            "TEAMS"
            "HEXX86"
            "HEXX64"
            "HEXARM"
            "HEXARM64"
            "HEXMIPS"
            "HEXMIPS64"
            "HEXPPC"
            "HEXPPC64"
            "HEXRV"
            "HEXRV64"
            "HEXARC"
            "HEXARC64"
            "HEXV850"
          ];

          mkAddons = id: lib.imap (mkAddon { owner = id; }) addons;

          mkHexlic =
            {
              name,
              email,
              id,
              version,
            }:
            pkgs.writeText "idapro.hexlic" (
              lib.toJSON rec {
                header.version = 1;
                payload = {
                  inherit name email;
                  licenses = lib.singleton {
                    description = "license";
                    edition_id = "ida-pro";
                    inherit id;
                    license_type = "named";
                    product = "IDA";
                    seats = 1;
                    start_date = "2024-08-10 00:00:00";
                    end_date = "2033-12-31 23:59:59";
                    issued_on = "2025-07-20 00:00:00";
                    owner = name;
                    product_id = "IDAPRO";
                    product_version = lib.versions.pad 2 version;
                    add_ons = mkAddons id;
                    features = [ ];
                  };
                };
                signature = mkSignature payload;
              }
            );
        in
        let
          defaults = {
            name = "auth";
            email = "admin@hex-rays.com";
            id = "14-0000-FFFF-88";
          };

          make = args: lib.makeOverridable mkHexlic (defaults // args);
        in
        {
          __functor = _: make;
          override = args: make (if lib.isFunction args then args defaults else args);
        };

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

          hexlic = mkLicense.override { inherit (final) version; };

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
          args = [
            "-c"
            /* bash */ ''
              set -xeuo pipefail

              cp "$src" 'install.run';
              chmod +x 'install.run';
              ./'install.run' --mode 'unattended' --prefix "$out";

              ${lib.getExe pkgs.perl} -0777 -pi - $out/libida{,32}${libext} <<'PERL'
                s/\xED\xFD\x42\K\x5C(?=\xF9\x78)/\xCB/
              PERL

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

              cp "$hexlic" "$out/idapro.hexlic";
            ''
          ];

          passthru = {
            inherit fetchHiddenTorrent mkLicense;
            withRuntimeLibs =
              libs:
              final.overrideAttrs (
                _: prev: {
                  runtimeLibs = prev.runtimeLibs ++ libs;
                }
              );
          };
        }
      );
    };
}
