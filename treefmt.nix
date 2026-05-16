_: {
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    deadnix.enable = true;
    statix.enable = true;
    prettier.enable = true;
    shfmt.enable = true;
    taplo.enable = true;
  };
  settings.formatter.prettier.options = [
    "--print-width"
    "100"
  ];
  settings.formatter.shfmt.options = [
    "--indent"
    "2"
  ];
}
