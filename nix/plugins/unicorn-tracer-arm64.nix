{
  lib,
  fetchFromGitHub,
  ...
}:

rec {
  pname = "unicorn-tracer-arm64";
  version = "0.4.0";

  drv = fetchFromGitHub {
    owner = "chenxvb";
    repo = "Unicorn-Trace";
    rev = "v${lib.versions.pad 2 version}";
    hash = "sha256-o1dJESPUK9TOY+HPlglH7RGsTvxGeT4otzOAZ1rajpI=";
  };

  neededPythonPackages =
    ps: with ps; [
      capstone
      unicorn
    ];
}
