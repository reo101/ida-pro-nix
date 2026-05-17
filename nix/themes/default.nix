{ ... }:

{
  perSystem =
    { ... }:
    {
      legacyPackages.themes = {
        _base = {
          imports = [ ];
          source = ./_base.css;
        };
        default = {
          imports = [ ];
          source = ./default.css;
        };
        dark = {
          imports = [ ];
          source = ./dark.css;
        };
      };
    };
}
