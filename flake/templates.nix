_: {
  flake.templates = {
    minimal = {
      path = ../templates/minimal;
      description = "Standalone Claude Code on home-manager — the 95% answer";
    };
    flake-parts = {
      path = ../templates/flake-parts;
      description = "For users already on flake-parts";
    };
  };
}
