{ pythonPackages, ... }:

let
  package = pythonPackages.idac;
in
{
  pname = "idac";
  inherit (package) version;

  drv = package.plugin;

  installEntries = [
    "idac_bridge"
    "idac_bridge_plugin.py"
    "idac"
  ];
}
