{
  config,
  lib,
  niri,
  pkgs,
  wallpapers,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.niri;
  niriPackage = niri.packages.${pkgs.stdenv.hostPlatform.system}.niri.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../../patches/niri-minimize-request.patch ];
  });

  cage = pkgs.cage.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../../patches/cage-output-scale.patch ];
  });

  nwgHello = pkgs.nwg-hello.overridePythonAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../../patches/nwg-hello-cage-no-layer-shell.patch
      ../../../patches/nwg-hello-centered-login.patch
      ../../../patches/nwg-hello-compact-power-buttons.patch
      ../../../patches/nwg-hello-session-popover.patch
      ../../../patches/nwg-hello-user-popover.patch
      ../../../patches/nwg-hello-password-icon.patch
      ../../../patches/nwg-hello-error-message.patch
    ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace nwg_hello/ui.py \
        --replace-fail \
          '        self.combo_session.connect("changed", self.on_session_changed)' \
          $'        self.combo_session.set_popup_fixed_width(True)\n        self.combo_session.set_size_request(220, -1)\n        self.combo_session.connect("changed", self.on_session_changed)'

      substituteInPlace nwg_hello/ui.py \
        --replace-fail \
          '        selected_user = self.combo_user.get_active_id()' \
          '        selected_user = self.user_entry.get_text() if hasattr(self, "user_entry") else self.combo_user.get_active_id()'

      substituteInPlace nwg_hello/ui.py \
        --replace-fail \
          '            user = self.combo_user.get_active_id()' \
          '            user = self.user_entry.get_text()'

      substituteInPlace nwg_hello/ui.py \
        --replace-fail \
          '                if self.combo_user.get_active_id():' \
          '                if self.user_entry.get_text():'

      substituteInPlace nwg_hello/ui.py \
        --replace-fail \
          '                    self.cache["user"] = self.combo_user.get_active_id()' \
          '                    self.cache["user"] = self.user_entry.get_text()'

      substituteInPlace nwg_hello/ui.py \
        --replace-fail \
          $'        lbl_session.set_text(f\047{voc["session"]}:\047)' \
          $'        lbl_session.set_text(f\047{voc["session"]}\\uff1a\047)'
    '';
  });

  nwgHelloTemplate = pkgs.writeText "nwg-hello-template.glade" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <requires lib="gtk+" version="3.24"/>
      <object class="GtkWindow" id="main-window">
        <property name="can-focus">False</property>
        <child>
          <object class="GtkOverlay" id="main-overlay">
            <property name="visible">True</property>
            <child>
              <object class="GtkBox" id="main-box">
                <property name="visible">True</property>
                <property name="halign">center</property>
                <property name="valign">center</property>
                <property name="orientation">horizontal</property>
                <child>
                  <object class="GtkBox" id="form-wrapper">
                    <property name="visible">True</property>
                    <property name="orientation">vertical</property>
                    <child>
                      <object class="GtkBox" id="center-wrapper">
                        <property name="visible">True</property>
                        <property name="orientation">vertical</property>
                        <child>
                          <object class="GtkBox" id="login-content">
                            <property name="width-request">520</property>
                            <property name="visible">True</property>
                            <property name="can-focus">False</property>
                            <property name="halign">center</property>
                            <property name="valign">center</property>
                            <property name="margin-start">40</property>
                            <property name="margin-end">40</property>
                            <property name="orientation">vertical</property>
                            <child>
                              <object class="GtkBox" id="login-card">
                                <property name="visible">True</property>
                                <property name="orientation">vertical</property>
                                <property name="spacing">18</property>
                                <child>
                                  <object class="GtkBox" id="title-block">
                                    <property name="visible">True</property>
                                    <property name="margin-bottom">90</property>
                                    <property name="orientation">vertical</property>
                                    <property name="spacing">4</property>
                                    <child>
                                      <object class="GtkLabel" id="lbl-welcome">
                                        <property name="visible">False</property>
                                        <property name="label">Welcome!</property>
                                      </object>
                                    </child>
                                    <child>
                                      <object class="GtkLabel" id="lbl-clock">
                                        <property name="visible">True</property>
                                        <property name="label">00:00</property>
                                      </object>
                                    </child>
                                    <child>
                                      <object class="GtkLabel" id="lbl-date">
                                        <property name="visible">True</property>
                                        <property name="label">Monday, 13. January</property>
                                      </object>
                                    </child>
                                  </object>
                                </child>
                                <child>
                                  <object class="GtkGrid" id="login-fields">
                                    <property name="visible">True</property>
                                    <property name="hexpand">True</property>
                                    <property name="row-spacing">16</property>
                                    <property name="column-spacing">10</property>
                                    <child>
                                      <object class="GtkLabel" id="lbl-user">
                                        <property name="visible">False</property>
                                        <property name="halign">start</property>
                                        <property name="valign">center</property>
                                        <property name="label">User:</property>
                                      </object>
                                      <packing>
                                        <property name="left-attach">0</property>
                                        <property name="top-attach">0</property>
                                      </packing>
                                    </child>
                                    <child>
                                      <object class="GtkEntry" id="user-entry">
                                        <property name="visible">True</property>
                                        <property name="can-focus">True</property>
                                        <property name="hexpand">True</property>
                                      </object>
                                      <packing>
                                        <property name="left-attach">1</property>
                                        <property name="top-attach">0</property>
                                      </packing>
                                    </child>
                                    <child>
                                      <object class="GtkLabel" id="lbl-password">
                                        <property name="visible">False</property>
                                        <property name="halign">start</property>
                                        <property name="valign">center</property>
                                        <property name="label">Password:</property>
                                      </object>
                                      <packing>
                                        <property name="left-attach">0</property>
                                        <property name="top-attach">1</property>
                                      </packing>
                                    </child>
                                    <child>
                                      <object class="GtkEntry" id="entry-password">
                                        <property name="visible">True</property>
                                        <property name="can-focus">True</property>
                                        <property name="hexpand">True</property>
                                      </object>
                                      <packing>
                                        <property name="left-attach">1</property>
                                        <property name="top-attach">1</property>
                                      </packing>
                                    </child>
                                  </object>
                                </child>
                                <child>
                                  <object class="GtkComboBoxText" id="combo-user">
                                    <property name="visible">False</property>
                                  </object>
                                </child>
                                <child>
                                  <object class="GtkBox" id="login-actions">
                                    <property name="visible">True</property>
                                    <property name="orientation">vertical</property>
                                    <property name="spacing">8</property>
                                    <child>
                                      <object class="GtkBox" id="message-box">
                                        <property name="visible">True</property>
                                        <property name="halign">center</property>
                                        <child>
                                          <object class="GtkLabel" id="lbl-message">
                                            <property name="visible">True</property>
                                            <property name="halign">center</property>
                                            <property name="label"></property>
                                          </object>
                                        </child>
                                      </object>
                                    </child>
                                    <child>
                                      <object class="GtkButton" id="btn-login">
                                        <property name="label">Login</property>
                                        <property name="visible">True</property>
                                        <property name="can-focus">True</property>
                                        <property name="receives-default">True</property>
                                      </object>
                                    </child>
                                  </object>
                                </child>
                                <child>
                                  <object class="GtkBox" id="power-actions">
                                    <property name="visible">True</property>
                                    <property name="halign">center</property>
                                    <property name="margin-top">90</property>
                                    <property name="spacing">16</property>
                                    <child>
                                      <object class="GtkButton" id="btn-sleep">
                                        <property name="label">Sleep</property>
                                        <property name="visible">True</property>
                                        <property name="can-focus">True</property>
                                        <property name="receives-default">True</property>
                                      </object>
                                    </child>
                                    <child>
                                      <object class="GtkButton" id="btn-restart">
                                        <property name="label">Restart</property>
                                        <property name="visible">True</property>
                                        <property name="can-focus">True</property>
                                        <property name="receives-default">True</property>
                                      </object>
                                    </child>
                                    <child>
                                      <object class="GtkButton" id="btn-poweroff">
                                        <property name="label">Poweroff</property>
                                        <property name="visible">True</property>
                                        <property name="can-focus">True</property>
                                        <property name="receives-default">True</property>
                                      </object>
                                    </child>
                                  </object>
                                </child>
                                <child>
                                  <object class="GtkBox" id="session-panel">
                                    <property name="visible">True</property>
                                    <property name="halign">center</property>
                                    <property name="margin-top">24</property>
                                    <property name="spacing">8</property>
                                    <child>
                                      <object class="GtkLabel" id="lbl-session">
                                        <property name="visible">True</property>
                                        <property name="label">Session:</property>
                                      </object>
                                    </child>
                                    <child>
                                      <object class="GtkMenuButton" id="session-menu-button">
                                        <property name="visible">True</property>
                                        <property name="can-focus">True</property>
                                        <property name="direction">down</property>
                                        <property name="label">Session</property>
                                      </object>
                                    </child>
                                    <child>
                                      <object class="GtkComboBoxText" id="combo-session">
                                        <property name="visible">False</property>
                                      </object>
                                    </child>
                                  </object>
                                </child>
                              </object>
                            </child>
                          </object>
                        </child>
                      </object>
                    </child>
                  </object>
                </child>
              </object>
            </child>
          </object>
        </child>
      </object>
    </interface>
  '';

  nwgHelloConfig = pkgs.writeText "nwg-hello.json" (
    builtins.toJSON {
      session_dirs = [ ];
      custom_sessions = [
        {
          name = "Niri";
          exec = "niri-session";
        }
        {
          name = "Plasma";
          exec = "startplasma-wayland";
        }
      ];
      monitor_nums = [ ];
      form_on_monitors = [ ];
      delay_secs = 0;
      cmd-sleep = "systemctl suspend";
      cmd-reboot = "systemctl reboot";
      cmd-poweroff = "systemctl poweroff";
      gtk-theme = "Adwaita";
      gtk-icon-theme = "Papirus-Dark";
      gtk-cursor-theme = "Adwaita";
      prefer-dark-theme = true;
      template-name = "nwg-hello-template.glade";
      time-format = "%H:%M";
      date-format = "%m月%d日";
      layer = "overlay";
      keyboard-mode = "on_demand";
      lang = "zh_CN";
      avatar-show = false;
      avatar-size = 100;
      avatar-border-width = 1;
      avatar-border-color = "#8fe2d4";
      avatar-corner-radius = 18;
      avatar-circle = true;
      env-vars = [ ];
    }
  );

  nwgHelloCss = pkgs.writeText "nwg-hello.css" ''
    window {
      font-family: "Maple Mono NF CN";
      background-image: url("file://${wallpapers}/anime-girls_tea.jpg");
      background-size: cover;
      background-position: center;
    }

    #form-wrapper {
      background-color: transparent;
    }

    #form-wrapper label {
      color: #e8f5f2;
    }

    #login-card {
      min-width: 420px;
      padding: 30px 32px 26px;
      background-color: rgba(7, 18, 22, 0.9);
      background-image: none;
      border: none;
      border-radius: 24px;
      box-shadow: 0 30px 96px rgba(0, 0, 0, 0.56);
    }

    #welcome-label {
      color: #ffffff;
      font-size: 36px;
      font-weight: 700;
    }

    #clock-label {
      color: #ffffff;
      font-size: 92px;
      font-weight: 600;
    }

    #date-label {
      color: #c6e2dc;
      font-size: 22px;
      font-weight: 500;
    }

    #title-block {
      margin-bottom: 0;
    }

    #form-label {
      color: #d7ebe7;
      font-size: 13px;
      margin-bottom: 5px;
    }

    #login-fields #form-label {
      margin-bottom: 0;
    }

    #form-combo,
    #user-entry,
    #password-entry {
      min-height: 44px;
      padding: 0 14px;
      color: #f7fffd;
      background-color: rgba(228, 248, 244, 0.12);
      background-image: none;
      border: 1px solid rgba(198, 235, 228, 0.24);
      border-radius: 12px;
      box-shadow: none;
      text-shadow: none;
    }

    #user-entry:hover,
    #password-entry:hover {
      background-color: rgba(228, 248, 244, 0.14);
      border-color: #62d2bf;
    }

    #form-combo entry {
      color: #effaf7;
      background-color: transparent;
      border: none;
      box-shadow: none;
      padding: 0 8px;
    }

    #form-combo button,
    #form-combo button:hover,
    #form-combo button:active,
    #form-combo button:checked {
      min-width: 0;
      padding: 0 9px;
      color: #9dc8c0;
      background-color: transparent;
      background-image: none;
      border: none;
      box-shadow: none;
    }

    entry selection {
      color: #071412;
      background-color: #62d2bf;
    }

    #user-entry image,
    #password-entry image {
      min-width: 16px;
      min-height: 16px;
      color: #b9d9d3;
    }

    #user-entry image:hover,
    #password-entry image:hover {
      color: #ffffff;
    }

    #login-button {
      min-height: 44px;
      padding: 0 14px;
      color: #ffffff;
      background-color: #167d70;
      background-image: none;
      border: 1px solid #1a9182;
      border-radius: 12px;
      font-size: 15px;
      font-weight: 700;
      text-shadow: 0 1px 2px rgba(0, 0, 0, 0.32);
    }

    #login-button:hover {
      background-color: #1b9182;
      border-color: #25a99a;
    }

    #login-button:active {
      background-color: #116a60;
      border-color: #116a60;
      box-shadow: inset 0 3px 7px rgba(0, 0, 0, 0.34);
    }

    #message-box {
      min-height: 18px;
      padding: 10px 18px;
      background-color: transparent;
      border: 1px solid transparent;
      border-radius: 14px;
      font-size: 13px;
    }

    #message-box.error {
      color: #fff4f2;
      background-color: rgba(179, 38, 30, 0.38);
      border: 1px solid #ff7a70;
    }

    #message-box.error label {
      color: #fff4f2;
      font-weight: 600;
    }

    #power-button {
      color: #dcece9;
      min-width: 0;
      min-height: 0;
      padding: 2px 8px;
      background-color: transparent;
      background-image: none;
      border: none;
      border-radius: 8px;
      font-size: 12px;
    }

    #power-button:hover {
      color: #ffffff;
      background-color: rgba(228, 248, 244, 0.1);
      border: none;
    }

    #power-button:active {
      color: #ffffff;
      background-color: rgba(228, 248, 244, 0.16);
      border: none;
      box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.34);
    }

    #power-actions {
      min-width: 0;
    }

    #session-menu-button {
      min-width: 150px;
      min-height: 38px;
      padding: 0 16px;
      color: #dffdf7;
      background-color: rgba(228, 248, 244, 0.1);
      background-image: none;
      border: 1px solid rgba(198, 235, 228, 0.24);
      border-radius: 10px;
      box-shadow: none;
      font-size: 13px;
      font-weight: 500;
    }

    #session-menu-button:hover {
      background-color: rgba(228, 248, 244, 0.14);
      border-color: #62d2bf;
    }

    #session-menu-button:active,
    #session-menu-button:checked {
      background-color: rgba(98, 210, 191, 0.16);
      border-color: #62d2bf;
      box-shadow: inset 0 2px 5px rgba(0, 0, 0, 0.24);
    }

    #session-panel #form-label {
      margin-bottom: 0;
      color: #dffdf7;
      font-size: 14px;
    }

    popover,
    popover.background,
    popover.background > contents {
      background-color: rgba(9, 22, 26, 0.98);
    }

    popover.background > contents,
    #session-list {
      padding: 8px;
      background-color: rgba(7, 18, 22, 0.98);
      border: 1px solid rgba(143, 226, 212, 0.28);
      border-radius: 14px;
      box-shadow: 0 20px 52px rgba(0, 0, 0, 0.5);
    }

    .session-option {
      min-width: 160px;
      min-height: 42px;
      padding: 6px 14px;
      color: #dcece9;
      background-image: none;
      border: none;
      border-radius: 10px;
      font-size: 13px;
    }

    .session-option:hover,
    .session-option.selected,
    .session-option:checked {
      color: #ffffff;
      background-color: rgba(98, 210, 191, 0.2);
      box-shadow: inset 3px 0 0 #62d2bf;
    }

    window.popup {
      background-color: transparent;
    }

    window.popup menu {
      min-width: 190px;
      padding: 0;
      color: #dcece9;
      background-color: #102329;
      background-image: none;
      border: none;
      border-radius: 8px;
      box-shadow: 0 12px 32px rgba(0, 0, 0, 0.34);
    }

    window.popup menuitem {
      min-height: 44px;
      padding: 0 22px;
      color: #dcece9;
      background-color: transparent;
      background-image: none;
      border: none;
    }

    window.popup menuitem:hover,
    window.popup menuitem:selected {
      color: #ffffff;
      background-color: #285f59;
      border: none;
    }
  '';
in
{
  options.modules.desktop.niri = {
    enable = mkEnableOption "Niri Wayland compositor";
  };

  config = mkIf cfg.enable {
    # Niri's NixOS module supplies the session package, portals, polkit and
    # GNOME Keyring integration. X11 applications run through
    # xwayland-satellite on demand, so an Xorg server is not required.
    programs.niri.enable = true;
    programs.niri.package = niriPackage;

    # nwg-hello presents username, password and session selection together.
    # Its custom template keeps the session chooser at the bottom-left.
    services.greetd = {
      enable = true;
      settings.default_session = {
        user = "greeter";
        command = "${pkgs.dbus}/bin/dbus-run-session ${pkgs.coreutils}/bin/env CAGE_OUTPUT_SCALE=2 GDK_SCALE=2 XCURSOR_SIZE=48 ${cage}/bin/cage -s -d -- ${nwgHello}/bin/nwg-hello --config /etc/nwg-hello/nwg-hello.json --stylesheet /etc/nwg-hello/nwg-hello.css";
      };
    };

    environment.etc = {
      "nwg-hello/nwg-hello.json".source = nwgHelloConfig;
      "nwg-hello/nwg-hello.css".source = nwgHelloCss;
      "nwg-hello/nwg-hello-template.glade".source = nwgHelloTemplate;
    };

    environment.pathsToLink = [
      "/share/wayland-sessions"
      "/share/xsessions"
    ];

    systemd.tmpfiles.rules = [
      "d '/var/cache/nwg-hello' 0700 greeter greeter - -"
    ];

    environment.systemPackages = with pkgs; [
      papirus-icon-theme
    ];

    hardware.graphics.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;

    services.printing.enable = true;

    # Thunar as the graphical file manager, matching the reference config.
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    programs.thunar = {
      enable = true;
      plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    # Unlock the login keyring through greetd, matching the Plasma login path.
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
