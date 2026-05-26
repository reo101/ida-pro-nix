{
  fetchzip,
  runCommand,
  ...
}:

let
  version = "0.3.7";
  srcRoot = fetchzip {
    url = "https://github.com/illera88/Ponce/releases/download/v${version}/ponce-v${version}-linux.zip";
    stripRoot = false;
    hash = "sha256-OsOJT8LxNtcVYRC+9c8HvU8NCCQYkSQjnvekMaCmHUQ=";
  };
in
rec {
  pname = "ponce";
  inherit version;

  # Package the Linux binary set targeting IDA 8.1.
  drv = runCommand "ponce-ida81-${version}" { } ''
    mkdir -p "$out"
    cp -a "${srcRoot}/Ponce_ida81/." "$out/"
  '';
}
