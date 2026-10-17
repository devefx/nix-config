{
  config,
  myvars,
  lib,
  pkgs,
  ...
}:
let
  # Build a CIFS mount for a server share. `cred` is the agenix-decrypted
  # credentials file path for that server.
  smbMount = server: cred: share: {
    device = "//${server}/${share}";
    fsType = "cifs";
    options = [
      "credentials=${cred}"
      # Mount lazily on first access instead of failing at boot before the
      # network/NAS is ready. `_netdev` alone did not add the needed
      # network-online ordering in the generated mount units.
      "x-systemd.automount"
      "noauto"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "x-systemd.idle-timeout=300"
      "nofail"
      "soft"
      "_netdev"
      "rw"
      "uid=1000"
      "gid=100"
      "iocharset=utf8"
    ];
  };
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "faex1";
  # local HTTP dev tools
  # 43128 is DSH Desktop's phone-pairing port. The packaged app runs the
  # development channel (see pkgs/dsh-desktop/default.nix), which moves the
  # bridge off production's 43127 onto 43128. DSH already binds it to 0.0.0.0
  # but still requires approving the device inside the desktop app; the harness
  # web UI itself stays on 127.0.0.1:43129 behind its token, not opened here.
  networking.firewall.allowedTCPPorts = [
    8080 # llama-server
    8088 # Claude Code Haha
    3000 # tele-desk backend
    5173 # tele-desk frontend (Vite dev server)
    43128 # DSH Desktop phone pairing
    30141 # Pi Web (pi-web)
  ];

  # Bluetooth — required for the KDE Bluetooth settings panel to show up.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  # External displays use DDC/CI for brightness control on this machine.
  hardware.i2c.enable = true;
  hardware.bluetooth.settings = {
    General.FastConnectable = true;
    Policy = {
      AutoEnable = true;
      ReconnectAttempts = 7;
      ReconnectIntervals = "1,2,4,8,16,32,64";
    };
  };
  hardware.bluetooth.input.General = {
    IdleTimeout = 0;
    UserspaceHID = true;
  };
  # BlueZ 5.86 fails to activate A2DP on some speakers with
  # "a2dp-sink profile connect failed: Device or resource busy".
  # Pin 5.84 until nixpkgs ships the fixed 5.87 release.
  # https://github.com/bluez/bluez/issues/1898
  hardware.bluetooth.package = lib.mkIf (lib.versionOlder pkgs.bluez.version "5.87") (
    (pkgs.bluez.override {
      bluez-headers = pkgs.bluez-headers.overrideAttrs (old: {
        version = "5.84";

        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/bluetooth/bluez-5.84.tar.xz";
          hash = "sha256-W6c9Aw97AAh9Z4ALDjIWAa7A+JKCfHLlosg5DYyIaxE=";
        };
      });
    }).overrideAttrs
      (_: {
        patches = [
          (pkgs.fetchurl {
            name = "static.patch";
            url = "https://lore.kernel.org/linux-bluetooth/20250703182908.2370130-1-hi@alyssa.is/raw";
            hash = "sha256-4Yz3ljsn2emJf+uTcJO4hG/YXvjERtitce71TZx5Hak=";
          })
        ];
      })
  );

  # Kernel 7.2 instead of the 6.18 default: on 6.18 the MT7925 Bluetooth half
  # (USB 0e8d:7925) intermittently fails the WMT firmware download --
  # "Wrong op received 6 expected 1" then "Failed to send wmt patch dwnld" --
  # and does not retry, leaving hci0 unusable until a power cycle; BlueZ then
  # reports "No default controller available". Measured over nine boots on
  # each kernel: five failed downloads on 6.18, one on 7.2.
  #
  # The 7.x btmtk driver resets the device and retries after a failed download
  # (upstream 679621a767, first in 7.1-rc) and disables the broken
  # remote-wakeup path for MT7922/MT7925 (upstream e31d761628), so the adapter
  # recovers on its own.
  boot.kernelPackages = pkgs.linuxPackages_7_2;

  # This machine was installed with GRUB and dual-boots Windows 11
  # (Windows boot files live on the same ESP). Override the framework
  # default of systemd-boot.
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev"; # UEFI-only: do not write to an MBR
    efiSupport = true;
    extraEntries = ''
      menuentry "Windows 11" --class windows {
        insmod part_gpt
        insmod fat
        insmod chain
        search --fs-uuid --set=root E28C-ED3A
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
  };
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot";
  };

  # GRUB theme — vinceliuice/grub2-themes via its NixOS module (README method).
  # Variants: tela / vimix / stylish / whitesur · icons: color / white / whitesur
  # · screens: 1080p / 2k / 4k / ultrawide / ultrawide2k.
  boot.loader.grub2-theme = {
    enable = true;
    theme = "tela";
    icon = "white";
    screen = "4k";
  };

  # Raise the Radeon 8060S GPU GTT cap from the default ~55 GiB to 96 GiB.
  # With UMA/VRAM set to 8 GiB in BIOS, the GPU sees 8 + 96 = 104 GiB of
  # unified memory. 96 GiB = 25165824 4KiB pages. Requires a reboot.
  boot.extraModprobeConfig = ''
    options ttm pages_limit=25165824
    options btusb enable_autosuspend=0
  '';

  # MT7925 can enter a zombie state where HCI stays up but BLE HID devices
  # no longer reconnect, often with "ACL packet for unknown connection
  # handle" in the kernel log (67 occurrences on this machine). It can also
  # fail its WMT firmware download. Try the trusted mouse at low frequency,
  # and reload the MediaTek USB driver after repeated failures.
  systemd.services.bluetooth-mouse-reconnect = {
    description = "Reconnect Logitech MX Anywhere 3S";
    after = [ "bluetooth.target" ];
    wants = [ "bluetooth.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "bluetooth-mouse-reconnect";
          runtimeInputs = with pkgs; [
            bluez
            coreutils
            gnugrep
            kmod
            systemd
          ];
          text = ''
            mouse="D4:EE:50:37:07:1C"
            state="/run/faex1-bt-mouse-reconnect.failures"

            is_connected() {
              bluetoothctl info "$mouse" 2>/dev/null | grep -q "Connected: yes"
            }

            reset_bluetooth_stack() {
              for interface in /sys/bus/usb/drivers/btusb/*:*; do
                [ -e "$interface" ] || continue
                printf '%s' "$(basename "$interface")" \
                  > /sys/bus/usb/drivers/btusb/unbind || true
              done

              sleep 2
              modprobe -r btusb >/dev/null 2>&1 || true
              modprobe -r btmtk >/dev/null 2>&1 || true
              sleep 2
              modprobe btusb >/dev/null 2>&1 || true
              sleep 5

              systemctl restart bluetooth.service >/dev/null 2>&1 || true
              sleep 8
            }

            if is_connected; then
              rm -f "$state"
              exit 0
            fi

            if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
              bluetoothctl power on >/dev/null 2>&1 || true
              sleep 2
            fi

            bluetoothctl --timeout 12 connect "$mouse" >/dev/null 2>&1 || true
            sleep 2
            if is_connected; then
              rm -f "$state"
              exit 0
            fi

            failures=0
            if [ -r "$state" ]; then
              failures="$(cat "$state")"
            fi
            failures=$((failures + 1))
            printf '%s\n' "$failures" > "$state"

            if [ "$failures" -lt 4 ]; then
              exit 0
            fi

            # Do not interrupt connected audio or other HID devices.
            if [ -z "$(bluetoothctl devices Connected 2>/dev/null)" ]; then
              reset_bluetooth_stack
              bluetoothctl power on >/dev/null 2>&1 || true
              bluetoothctl --timeout 15 connect "$mouse" >/dev/null 2>&1 || true
            fi

            printf '0\n' > "$state"
          '';
        }
      );
    };
  };

  systemd.timers.bluetooth-mouse-reconnect = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "2min";
      Unit = "bluetooth-mouse-reconnect.service";
    };
  };

  # Nix defaults to one job per CPU and gives every job all 32 cores. ROCm
  # builds then run hundreds of clang processes at once and push this 128 GiB
  # machine deep into swap. Cap both levels of parallelism so one build stays
  # within the memory budget of the shared CPU/GPU pool.
  nix.settings = {
    max-jobs = 2;
    cores = 8;
  };

  # The Sculptor DP monitor briefly drops HPD and reconnects ~3s after
  # DPMS-off. KWin only ignores reconnects within 2s by default, so it treats
  # the reconnect as a new output and turns the screen back on. Extend that
  # window to keep the screen off until a real wake event.
  environment.sessionVariables.KWIN_DPMS_WORKAROUND_TIMEOUT = "100000";

  # nixpkgs 26.11 has PyTorch 2.13 against AOTriton 0.11.1b, which does not
  # compile. Use ROCm's matching 0.12b binaries for the gfx1151 Strix Halo GPU
  # and patch PyTorch's configure-time helper shebang.
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        aotriton = prev.callPackage ../../pkgs/aotriton-0.12b { };
        rocmPackages = prev.rocmPackages.gfx1151.overrideScope (
          _rocmFinal: _rocmPrev: {
            inherit aotriton;
          }
        );
        patchTorchAttrs =
          torch:
          torch.overridePythonAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              patchShebangs --build aten/src/ATen/native/transformers/hip/flash_attn/ck/add_make_kernel_pt.sh
            '';
          });
      in
      {
        # Deliberately NOT `inherit rocmPackages` at the top level. Upstream
        # 2f0fc932d0c6 made magma prefer `clr.localGpuTargets` over the full
        # `clr.gpuTargets` list, and the gfx1151 scope sets it to exactly
        # [ "gfx1151" ] -- which is absent from magma's own supportedGpuTargets.
        # Promoting the scoped set to the top level therefore makes magma (and
        # magma-hip, torch's default effectiveMagma) throw
        # "No supported GPU targets specified. Requested GPU targets: 1151".
        # Only the torch packages below need the gfx1151 scope, so hand it to
        # them directly and leave the top-level rocmPackages unscoped.
        python3Packages = prev.python3Packages.overrideScope (
          _pythonFinal: pythonPrev: {
            torch = patchTorchAttrs (
              pythonPrev.torch.override {
                inherit rocmPackages;
              }
            );
            torchWithRocm = patchTorchAttrs (
              pythonPrev.torch.override {
                inherit rocmPackages;
                cudaSupport = false;
                rocmSupport = true;
                triton = pythonPrev.triton-no-cuda;
              }
            );
          }
        );
      }
    )
  ];
  nixpkgs.config.problems.handlers."composable_kernel-gfx1151".broken = "ignore";

  boot.supportedFilesystems = [
    "ntfs"
    "cifs"
  ];

  # Shared NTFS data partition, mounted with the in-kernel ntfs3 driver.
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/7C02CBA602CB642C";
    fsType = "ntfs3";
    options = [
      "rw"
      "uid=1000"
      "gid=100"
      "umask=022"
    ];
  };

  # SMB shares — TrueNAS (192.168.16.251) and Windows Server
  # (192.168.16.206). Credentials are decrypted by agenix
  # (see secrets/nixos.nix).
  fileSystems."/mnt/portable_apps" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "portable_apps";
  fileSystems."/mnt/media" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "media";
  fileSystems."/mnt/downloads" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "downloads";
  fileSystems."/mnt/archive" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "archive";
  fileSystems."/mnt/workspace" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "workspace";
  fileSystems."/mnt/wd_20t" =
    smbMount "192.168.16.206" config.age.secrets.smb-credentials-wd20t.path
      "wd_20t";

  # Pi Web is a systemd *user* service, and the user manager only exists
  # while someone is logged in. Linger keeps it — and therefore Pi Web —
  # running from boot, before and after any graphical login.
  users.users.${myvars.username}.linger = true;

  modules.secrets.enable = true;
  modules.secrets.smb.enable = true;
  modules.secrets.hf.enable = true;
  modules.desktop.plasma.enable = true;
  modules.desktop.gaming.enable = true;
  modules.desktop.fonts.enable = true;

  # Clash Verge with TUN mode: setuid wrapper + privilege service.
  # tunMode needs networking.firewall.checkReversePath to be loose (set automatically).
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };
  system.stateVersion = myvars.stateVersion;
}
