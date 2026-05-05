{
  lib,
  pkgs,
  system,
  ...
}:
let
  mkRawDerivation =
    let
      mk =
        base:
        let
          attrs = base final;
          outputs = attrs.outputs or [ "out" ];
          stripped = removeAttrs attrs [
            "extend"
            "meta"
            "passthru"
            "overrideAttrs"
          ];
          drv = derivation (stripped // { inherit outputs; });

          overrideAttrs =
            overlay:
            mk (
              newFinal:
              let
                prev = base newFinal;
              in
              prev // (lib.toExtension overlay newFinal prev)
            );

          final =
            lib.lazyDerivation {
              derivation = drv;
              inherit outputs;
              meta = attrs.meta or { };
              passthru = attrs.passthru or { };
            }
            // attrs
            // (attrs.passthru or { })
            // {
              inherit overrideAttrs;
              passthru = attrs.passthru or { };
              extend = overrideAttrs;
              all = drv.all;
            };
        in
        final;
    in
    attrs: mk (lib.toFunction attrs);

  fetchHiddenTorrent =
    {
      name ? lib.last (lib.split "/" url),
      outputHash,
      url,
      file,
    }:
    derivation {
      inherit system name outputHash;

      builder = lib.getExe pkgs.bash;
      args = [
        "-c"
        /* bash */ ''
          set -xeu pipefail;
          shopt -s extglob;

          ${lib.getExe pkgs.tor} \
            --DataDirectory "$TMPDIR/tor" \
            --RunAsDaemon '1';

          ${lib.getExe pkgs.aria2} \
            --seed-time '0' \
            --select-file '${file}' \
            --index-out "${file}=''${PWD//+([^\/])/..}$out" \
            --torrent-file \
            <(${lib.getExe pkgs.curl} ${
              lib.escapeShellArgs [
                "--proxy"
                "socks5h://localhost:9050"
                url
              ]
            });
        ''
      ];
    };
in
{
  inherit mkRawDerivation fetchHiddenTorrent;
}
