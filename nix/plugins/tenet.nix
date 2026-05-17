{
  fetchFromGitHub,
  runCommand,
  ...
}:

let
  version = "0.2.0";
  srcRoot = fetchFromGitHub {
    owner = "gaasedelen";
    repo = "tenet";
    rev = "v${version}";
    hash = "sha256-lTPSfEpv6EbXwz/unmoxOTekjuqcoYH1sG6n6zmNltE=";
  };
in
rec {
  pname = "tenet";
  inherit version;

  src = srcRoot + "/plugins";
}
