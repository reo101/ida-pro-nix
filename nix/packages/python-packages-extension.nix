pyFinal: pyPrev:

{
  stpyv8 = pyFinal.callPackage ./stpyv8.nix { };
  cdifflib = pyFinal.callPackage ./cdifflib.nix { };
}
