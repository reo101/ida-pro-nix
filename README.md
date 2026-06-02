# ida-pro-nix

Nix packaging glue for running IDA Pro on Nix/NixOS.

## Legal notice

This repository does **not** provide, redistribute, mirror or download IDA Pro, Hex-Rays products, installers, binaries, or license files.

You must provide your own legally obtained IDA Pro installer and a valid license from Hex-Rays. By using this flake/module, you are responsible for complying with the Hex-Rays EULA and any other applicable license terms.

## Usage

The package intentionally requires the IDA installer source to be supplied by the user:

```nix
inputs.ida-pro.packages.${system}.ida-pro.override {
  src = /path/to/your/legally-obtained/ida-installer.run;
}
```

The Home-Manager module can install the resulting package, copy a user-provided license file into the user's IDA config directory, install plugins, and install declarative CSS themes:

```nix
programs.ida-pro = {
  enable = true;
  package = inputs.ida-pro.packages.${system}.ida-pro.override {
    src = /path/to/your/legally-obtained/ida-installer.run;
  };
  hexlic = /path/to/idapro.hexlic;

  plugins = ps: [
    ps.diaphora
    ps.ida-cyberchef
  ];

  # Additional packages to expose to IDAPython.
  extraPythonPackages = ps: [ ps.requests ];

  # Either select a named theme...
  themes = inputs.ida-pro.legacyPackages.${system}.themes;
  theme = "dark";

  # ...or provide a CSS file directly. `themeFile` imports `dark` first by
  # default; set `themeFileImports = [ ];` for a complete standalone theme.
  # themeFile = ./ida-theme.css;

  # Declarative IDA registry settings. Attrsets become subkeys; strings,
  # integers, booleans, null, string lists, and byte lists (0..255) are supported.
  settings.MyPlugin.Enabled = true;
};
```

Plugin definitions are selected like Python packages with `plugins = ps: [ ... ];`. Use `plugins = ps: ps.allPlugins;` to install every plugin in the scope. The `ps` scope is extensible with `programs.ida-pro.pluginPackageExtensions`; it also exposes `ida-pro` as the selected IDA package and `ida-sdk` as the matching SDK source for plugins that need them.

If Stylix is enabled, the module also exposes `stylix.targets.ida-pro.enable` and will generate/select a `stylix` IDA theme by default.

This project is only intended to make a locally licensed IDA Pro installation work conveniently on Nix/NixOS.

---

And remember:

# **Buy IDA Pro™**
