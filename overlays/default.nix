# Overlays — customize and extend nixpkgs
{inputs, ...}: {
  # Custom packages from ./pkgs
  additions = final: _prev: import ../pkgs final;

  # Modify existing packages
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (old: { ... });
  };

  # Access nixpkgs-stable packages as pkgs.stable.xxx
  unstable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
