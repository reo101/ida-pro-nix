{ lib }:

pyFinal: pyPrev:

let
  entries = builtins.readDir ./.;
  ignored = [
    "default.nix"
    "extension.nix"
  ];

  isPackage =
    name:
    let
      type = entries.${name};
    in
    !builtins.elem name ignored
    && (type == "directory" || (type == "regular" && lib.hasSuffix ".nix" name));
in
builtins.listToAttrs (
  builtins.map (name: {
    name = lib.removeSuffix ".nix" name;
    value = pyFinal.callPackage (./. + "/${name}") { };
  }) (builtins.filter isPackage (builtins.attrNames entries))
)
