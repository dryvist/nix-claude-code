_: {
  home = {
    username = "you";
    homeDirectory = "/Users/you";
    stateVersion = "26.05";
  };

  programs.claude = {
    enable = true;

    statusline = {
      enable = true;
      theme = "powerline";
    };

    hooks = {
      captureSessionOutput = true;
      refreshMarketplaces = true;
    };

    enabledPlugins = {
      "github@claude-plugins-official" = true;
      "plugin-dev@claude-plugins-official" = true;
    };
  };
}
