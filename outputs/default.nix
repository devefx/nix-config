{
  self,
  nixpkgs,
  pre-commit-hooks,
  ...
}@inputs:
let
  inherit (inputs.nixpkgs) lib;
  mylib = import ../lib { inherit lib; };
  myvars = import ../vars;

  godotYoke =
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    pkgs.godot_4_7.overrideAttrs (old: {
      version = "4.7.2-yoke";
      src = inputs.godot-yoke;
      sconsFlags = (old.sconsFlags or [ ]) ++ [
        "system_certs_path=/etc/ssl/certs/ca-certificates.crt"
      ];
    });

  genSpecialArgs =
    system:
    inputs
    // {
      inherit mylib myvars;
      godotYoke = godotYoke system;
      # Upstream flakes whose outputs modules need; injected here so modules
      # never reach for the whole `inputs` attrset (which also carries the
      # private secrets repo).
      inherit (inputs) gufo;

      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    };

  args = {
    inherit
      inputs
      lib
      mylib
      myvars
      genSpecialArgs
      ;
  };

  nixosSystems = {
    x86_64-linux = import ./x86_64-linux (args // { system = "x86_64-linux"; });
  };
  allSystems = nixosSystems;
  allSystemNames = builtins.attrNames allSystems;
  nixosSystemValues = builtins.attrValues nixosSystems;

  forAllSystems = func: (nixpkgs.lib.genAttrs allSystemNames func);
in
{
  nixosConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.nixosConfigurations or { }) nixosSystemValues
  );

  packages = forAllSystems (
    system:
    {
      godot-yoke = godotYoke system;
    }
    // (allSystems.${system}.packages or { })
  );

  checks = forAllSystems (system: {
    pre-commit-check = pre-commit-hooks.lib.${system}.run {
      src = mylib.relativeToRoot ".";
      hooks = {
        nixfmt = {
          enable = true;
          settings.width = 100;
        };
        typos = {
          enable = true;
          settings = {
            write = true;
            configPath = ".typos.toml";
          };
        };
        prettier = {
          enable = true;
          settings = {
            write = true;
            configPath = ".prettierrc.yaml";
          };
        };
      };
    };
  });

  devShells = forAllSystems (
    system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      androidEnv = pkgs.androidenv.override { licenseAccepted = true; };
      ndkVersion = "29.0.14206865";

      androidSdk =
        (androidEnv.composeAndroidPackages {
          includeNDK = true;
          inherit ndkVersion;
          platformVersions = [ "36" ];
          buildToolsVersions = [ "36.1.0" ];
          platformToolsVersion = "37.0.1";
          cmdLineToolsVersion = "latest";
          includeCmake = true;
          cmakeVersions = [ "3.10.2" ];
        }).androidsdk;

      jdk = pkgs.openjdk17;
      androidSdkPath = "${androidSdk}/libexec/android-sdk";
    in
    {
      default = pkgs.mkShell {
        packages = with pkgs; [
          bashInteractive
          gcc
          cargo-ndk
          androidSdk
          android-tools
          jdk
          nixfmt
          deadnix
          statix
          typos
          prettier
        ];

        ANDROID_HOME = androidSdkPath;
        ANDROID_SDK_ROOT = androidSdkPath;
        ANDROID_NDK_HOME = "${androidSdkPath}/ndk/${ndkVersion}";
        ANDROID_NDK_ROOT = "${androidSdkPath}/ndk/${ndkVersion}";
        JAVA_HOME = jdk.home;

        name = "nix-config";
        inherit (self.checks.${system}.pre-commit-check) shellHook;
      };
    }
  );

  formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
}
