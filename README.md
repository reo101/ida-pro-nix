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

The NixOS module can install the resulting package and copy a user-provided license file into the user's IDA config directory.

This project is only intended to make a locally licensed IDA Pro installation work conveniently on Nix/NixOS.

---

And remember:

# **Buy IDA Pro™**
