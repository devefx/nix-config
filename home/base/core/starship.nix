{
  programs.starship = {
    enable = true;

    enableBashIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;

    # https://starship.rs/config/
    settings = {
      # Get editor completions based on the config schema
      "$schema" = "https://starship.rs/config-schema.json";
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
      # Defaults are noisy — disable unless you rely on them.
      # Prefer explicit --project / --region flags in gcloud / aws commands.
      aws.disabled = true;
      gcloud.disabled = true;

      kubernetes = {
        symbol = "⛵";
        disabled = false;
      };
      os.disabled = false;
    };
  };
}
