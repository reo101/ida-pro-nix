{
  fetchFromGitHub,
  ...
}:

rec {
  pname = "ida-cyberchef";
  version = "0.2.0";

  drv = fetchFromGitHub {
    owner = "HexRaysSA";
    repo = "ida-cyberchef";
    rev = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-MzYIFSFytRQKxPV2aoCSw1uxaaDO11fU9GbGa/xEklM=";
  };

  neededPythonPackages = ps: with ps; [
    pydantic
    stpyv8
  ];
}
