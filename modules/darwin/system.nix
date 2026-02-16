# macOS system preferences and settings
{
  pkgs,
  myvars,
  ...
}: {
  # System-level packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  # macOS system preferences (System Settings equivalent)
  system.defaults = {
    # Dock
    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false;
    };

    # Finder
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv"; # Column view
    };

    # Global
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      # Key repeat speed
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };

    # Trackpad
    trackpad = {
      Clicking = true; # Tap to click
      TrackpadRightClick = true;
    };
  };

  # Enable Touch ID for sudo
  security.pam.enableSudoTouchIdAuth = true;
}
