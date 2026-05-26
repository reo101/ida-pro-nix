{
  fetchzip,
  ...
}:

rec {
  pname = "openlumina";
  version = "9.3.0";

  drv = fetchzip {
    url = "https://github.com/tomrus88/OpenLumina/releases/download/v${version}/openlumina-ida9.3.zip";
    stripRoot = false;
    hash = "sha256-5riN3e89AV3Ulq7DXFe8WBX8C48D5DqncGX0m3o8YBc=";
  };
}
