{ lib, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (import ./helpers.nix { inherit lib pkgs system; }) mkRawDerivation fetchHiddenTorrent;

      mkLicense =
        let
          n = "93AF7A8E3A6EB93D1B4D1FB7EC29299D2BC8F3CE5F84BFE88E47DDBDD5550C3CE3D2B16A2E2FBD0FBD919E8038BB05752EC92DD1498CB283AA087A93184F1DD9DD5D5DF7857322DFCD70890F814B58448071BBABB0FC8A7868B62EB29CC2664C8FE61DFBC5DB0EE8BF6ECF0B65250514576C4384582211896E5478F9CB42FDED";
          d = "7498027049140B81158DBAB99F7ED002D1B9980EB732E85947E7E4F42F2832151FA6562B67D4D8A0A3221ED1045DC0F0B9258FF611A4F8B8C99AE78199ED9E4DAEC2F9579F3FF31C79C4A219B6EAA4002F8235D8634E1C7A01D332571D710D64DD64D44D814126B7BF8D60167845A5B1BE47FF687B79364413BBF3B7BB6AC877";

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
            let
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

              licenseUnsigned = lib.toFile "hexlic-unsigned.json" (
                lib.toJSON {
                  header.version = 1;
                  inherit payload;
                }
              );

              licensePayloadHash = lib.pipe { inherit payload; } [
                lib.toJSON
                (lib.hashString "sha256")
                (h: lib.strings.replicate 33 "42" + h + lib.strings.replicate 63 "00")
                lib.toUpper
              ];
            in
            derivation {
              inherit system;

              name = "idapro.hexlic";
              builder = lib.getExe pkgs.bash;
              PATH = lib.makeBinPath [
                pkgs.bc
                pkgs.coreutils
                pkgs.jq
              ];
              args = [
                "-c"
                /* bash */ ''
                  set -euo pipefail;

                  signature="$(printf '16o 16i %s ${d} ${n} | p\n' '${licensePayloadHash}' \
                    | DC_LINE_LENGTH=0 dc \
                    | tr -d '\n' \
                    | fold -w '2' \
                    | tac \
                    | tr -d '\n')";

                  jq -cj --arg signature "$signature" '. + { signature: $signature }' \
                    '${licenseUnsigned}' \
                    > "$out";
                ''
              ];
            };
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

              perl -0777 -pi - $out/libida{,32}${libext} <<'PERL';
                s/\xED\xFD\x42\K\x5C(?=\xF9\x78)/\xCB/
              PERL

              cp "$hexlic" "$out/idapro.hexlic";

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

          passthru = { inherit fetchHiddenTorrent mkLicense; };
        }
      );
    };
}
