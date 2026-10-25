{
  lib,
  autoPatchelfHook,
  bashInteractive,
  buildNpmPackage,
  electron_43,
  fetchFromGitHub,
  fetchurl,
  makeDesktopItem,
  makeWrapper,
  nodejs_24,
  stdenv,
}:

let
  version = "0.10.0";

  # The harness reaches Node's internals through `node-addon-require-builtin`,
  # which probes the running executable by disassembling
  # `node::PrincipalRealm::builtin_module_require` and reading the V8 realm
  # field offset out of its machine code. The matcher only accepts the exact
  # instruction sequence Node's official x86-64 builds emit and fails closed
  # otherwise. nixpkgs' Node build has an extra `xor edi, edi` in that getter,
  # so host preparation dies with
  # "node-addon-require-builtin unsupported: Unsupported/no-getter" and the
  # harness never starts ("Another instance is already running" was only the
  # stale window of the previous launch). 0.9.x never ran the probe at boot.
  #
  # Node's official Linux build satisfies the probe, so the harness runs on it
  # instead of nixpkgs' Node. autoPatchelfHook points the binary at nixpkgs'
  # glibc and libstdc++, so nothing depends on an FHS layout at runtime. The
  # version tracks the `nodejs_24` used to build the app, keeping the runtime
  # ABI in step with the prebuilt native addons in the bundle.
  nodeRuntime = stdenv.mkDerivation (finalAttrs: {
    pname = "dsh-desktop-node";
    # Tracks the nixpkgs `nodejs_24` this flake pins rather than nodejs.org's
    # latest 24.x: the whole point of shipping a runtime is that it matches the
    # ABI of the prebuilt native addons already in the bundle, and those were
    # compiled against nixpkgs' Node.
    version = "24.21.0";

    src = fetchurl {
      url = "https://nodejs.org/dist/v${finalAttrs.version}/node-v${finalAttrs.version}-linux-x64.tar.xz";
      hash = "sha256-/Y5Z1aURUQ9qKYr7VI8Yx9KxvkBNi0on2U++SfVsstY=";
    };

    sourceRoot = "node-v${finalAttrs.version}-linux-x64";

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -a bin include lib share "$out/"
      runHook postInstall
    '';

    meta = {
      description = "Official Node.js runtime for the DSH Desktop harness";
      homepage = "https://nodejs.org";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  });

  app = buildNpmPackage {
    pname = "dsh-desktop";
    inherit version;

    src = fetchFromGitHub {
      owner = "dataelement";
      repo = "dsh-desktop";
      rev = "c12911a9b510add7fb2d7467e85cc9ababbdfca6";
      hash = "sha256-cgNVon+ufsmJFB8ySCEtqtsHrV3uqjFCPEfXuIoRr1I=";
    };

    npmDepsHash = "sha256-K3EnTNyBpQSam2COyQJYW0GLS7zmP72hySprdcJCqds=";
    makeCacheWritable = true;
    nodejs = nodejs_24;
    nativeBuildInputs = [ makeWrapper ];

    # The upstream lockfile points at npmmirror, which is impractically slow
    # for Nix's full dependency fetcher. The package tarballs are identical on
    # the canonical registry; only the resolved URLs change.
    postPatch = ''
      substituteInPlace package-lock.json \
        --replace-fail "https://registry.npmmirror.com/" "https://registry.npmjs.org/"
      substituteInPlace package.json \
        --replace-fail '"version": "0.1.1"' '"version": "0.10.0"'
      substituteInPlace src/main/index.ts \
        --replace-fail "if (!app.isPackaged) return true" "if (!app.isPackaged) return false"
    '';

    # The upstream lockfile installs native helpers at postinstall time.
    # Their prebuilt Linux artifacts are complete; run only the pure-JS
    # source patches and build steps below.
    npmRebuildFlags = [ "--ignore-scripts" ];

    preBuild = ''
      npx patch-package
      node scripts/install-brand-assets.mjs
      node node_modules/@deepseek-ai/dsh-subprocess-local/scripts/ensure-spawn-helper.mjs
    '';

    # NixOS does not provide a guaranteed /bin/bash or /bin/sh. The upstream
    # defaults therefore make every persistent shell and script fallback fail
    # before the PTY readiness handshake begins.
    postBuild = ''
      substituteInPlace node_modules/@deepseek-ai/dsh-terminal-bash/lib/index.js \
        --replace-fail 'const DEFAULT_BASH_SHELL = "/bin/bash";' \
        'const DEFAULT_BASH_SHELL = "${lib.getExe bashInteractive}";'

      substituteInPlace node_modules/@deepseek-ai/dsh-subprocess-local/lib/runner.js \
        --replace-fail '"/bin/sh"' '"${lib.getExe bashInteractive}"'
    '';

    # `isDevelopmentBuild()` in out/main/index.js is
    # `app.isPackaged ? package.json.dshDesktopChannel === "development" : true`.
    # Electron only sets `app.isPackaged` for a `resources/app.asar` layout or a
    # renamed executable; this wrapper execs the stock binary named `electron`
    # with the app directory as a positional argument, so it is always false and
    # the metadata branch is unreachable. Setting `dshDesktopChannel` here would
    # therefore be dead code.
    #
    # Patching the guard directly is what actually decides the branch, so the app
    # runs with the dev-channel values the phone pairing is configured for:
    # `userData` becomes `dsh-desktop-dev` and the mobile bridge listens on 43128
    # instead of 43127. The firewall opens the matching 43128. Read `app.isPackaged`
    # elsewhere as a proxy for "packaged" only with this in mind.
    preInstall = ''
      substituteInPlace package.json \
        --replace-fail '"name": "dsh-desktop"' '"name": "dsh-desktop", "dshDesktopChannel": "development"'
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/dsh-desktop"
      cp -a package.json out build node_modules packages "$out/share/dsh-desktop/"

      mkdir -p "$out/share/dsh-desktop/node_modules/node/bin"
      ln -sf ${nodeRuntime}/bin/node "$out/share/dsh-desktop/node_modules/node/bin/node"

      # Electron disables Chromium's native Wayland text-input bridge by
      # default. Without these switches the app never exposes an input
      # context to fcitx5, so Pinyin appears dead even though fcitx5 is
      # running. The same flags are used by the other Electron wrappers in
      # this repo; they are harmless on X11.
      makeWrapper ${lib.getExe electron_43} "$out/bin/dsh-desktop" \
        --add-flags "--ozone-platform-hint=auto" \
        --add-flags "--enable-wayland-ime=true" \
        --add-flags "--wayland-text-input-version=3" \
        --add-flags "$out/share/dsh-desktop"

      install -Dm0644 build/icon.png \
        "$out/share/icons/hicolor/512x512/apps/dsh-desktop.png"
      install -Dm0644 ${desktopItem}/share/applications/dsh-desktop.desktop \
        "$out/share/applications/dsh-desktop.desktop"

      runHook postInstall
    '';

    meta = {
      description = "DeepSeek Harness desktop application";
      homepage = "https://github.com/dataelement/dsh-desktop";
      license = lib.licenses.mit;
      mainProgram = "dsh-desktop";
      platforms = [ "x86_64-linux" ];
    };
  };

  desktopItem = makeDesktopItem {
    name = "dsh-desktop";
    desktopName = "DSH Desktop";
    comment = "Desktop shell for DeepSeek Harness";
    icon = "dsh-desktop";
    exec = "dsh-desktop %U";
    startupWMClass = "dsh-desktop";
    categories = [ "Development" ];
  };
in
app
