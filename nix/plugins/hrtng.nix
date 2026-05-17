{
  fetchzip,
  ...
}:

rec {
  pname = "hrtng";
  version = "3.8.94";

  src = fetchzip {
    url = "https://github.com/KasperskyLab/hrtng/releases/download/v${version}/hrtng-ida9.3.zip";
    stripRoot = false;
    hash = "sha256-bpz3pQICvd8cOIaR4UxkCNN54ATbW5knUBk4S8siHco=";
  };
}
