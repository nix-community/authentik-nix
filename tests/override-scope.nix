{
  pkgs,
  authentik-version,
  nixosModules,
  mkAuthentikScope,
}:

/*
  This is just meant as a demonstration on how to override the scope which includes the
  authentik components. This is an extended version of ./minimal-vmtest.nix

  First, a new scope is created from the default one using `overrideScope` on the result
  from `mkAuthentikScope`.
  Components with overrides in that scope are used by their dependents, i.e. dependents
  of `pythonEnv` (e.g. gopkgs) also pull in that overridden `pythonEnv`
  Then, that scope is passed to the module via the `services.authentik.authentikComponents` option
  And finally, the test script checks if the patched welcome string is present.
*/

let
  customWelcome = "Welcome to custom authentik";

  # creates a new scope using python 3.12 for mkPoetryEnv
  # and overrides the welcome string for the default oobe intial-setup flow
  customScope = (mkAuthentikScope { inherit pkgs; }).overrideScope (
    final: prev: {
      authentikComponents = prev.authentikComponents // {
        pythonEnv = prev.authentikComponents.pythonEnv.overrideAttrs (_: {
          python = pkgs.python312;
        });
        staticWorkdirDeps = prev.authentikComponents.staticWorkdirDeps.overrideAttrs (oA: {
          buildCommand =
            oA.buildCommand
            + ''
              rm -v $out/blueprints
              cp -vr ${prev.authentik-src}/blueprints $out/blueprints
              substituteInPlace $out/blueprints/default/flow-oobe.yaml \
                --replace "Welcome to authentik" "${customWelcome}"
            '';
        });
      };
    }
  );
in
pkgs.testers.runNixOSTest {
  name = "authentik";
  nodes = {
    authentik = {
      virtualisation = {
        cores = 6;
        memorySize = 8192;
      };
      imports = [
        nixosModules.default
        "${pkgs.path}/nixos/tests/common/user-account.nix"
        "${pkgs.path}/nixos/tests/common/x11.nix"
      ];

      # Keep in mind that the secret still ends up in the store and is world-readable because the
      # systemd-tmpfiles config lands in the store.
      # This is just a trick to not pass a store-path (which is prohibited) to `environmentFile`
      # without having to integrate secret managers like agenix or sops-nix into the test.
      # Don't do this in production.
      systemd.tmpfiles.rules = [
        "f /etc/authentik.env 0700 root root - AUTHENTIK_SECRET_KEY=notastorepath"
      ];

      services.authentik = {
        enable = true;
        environmentFile = "/etc/authentik.env";
        nginx = {
          enable = true;
          host = "localhost";
        };
        # pass authentikComponents with patched pythonEnv and staticWorkdirDeps
        inherit (customScope) authentikComponents;
        settings.disable_update_check = true;
      };

      services.xserver.enable = true;
      test-support.displayManager.auto.user = "alice";
      environment.systemPackages = with pkgs; [
        firefox
        xdotool
      ];
    };
  };

  enableOCR = true;

  # TODO maybe use bootstrap env vars instead of testing manual workflow?
  testScript = ''
    start_all()

    authentik.wait_for_unit("postgresql.service")
    authentik.wait_for_unit("authentik-migrate.service")
    authentik.wait_for_unit("authentik-worker.service")
    authentik.wait_for_unit("authentik.service")
    authentik.wait_for_open_port(9000)
    authentik.wait_until_succeeds("curl -fL http://localhost:9000 >&2")

    with subtest("Frontend renders"):
        authentik.succeed("su - alice -c 'firefox --kiosk http://localhost:9000' >&2 &")
        authentik.wait_for_text("${customWelcome}")
        authentik.screenshot("1_rendered_frontend")

    with subtest("admin account setup works"):
        authentik.send_key("tab")
        authentik.send_key("tab")
        authentik.send_chars("akadmin@localhost")
        authentik.send_key("tab")
        authentik.send_chars("foobar")
        authentik.send_key("tab")
        authentik.send_chars("foobar")
        authentik.send_key("ret")
        authentik.wait_for_text("No Applications available.")
        authentik.send_key("esc")
        authentik.screenshot("2_initial_setup_successful")

    with subtest("admin settings render and version as expected"):
        authentik.succeed("su - alice -c 'firefox --kiosk http://localhost:9000/if/admin/' >&2 &")
        authentik.wait_for_text("General system status")
        authentik.screenshot("3_rendered_admin_interface")
        authentik.succeed("su - alice -c 'xdotool click 1' >&2")
        authentik.succeed("su - alice -c 'xdotool key --delay 100 Page_Down' >&2")
        # sometimes the cursor covers the version string
        authentik.succeed("su - alice -c 'xdotool mousemove_relative 50 50' >&2")
        authentik.wait_for_text("${builtins.replaceStrings [ "." ] [ ".?" ] authentik-version}")
        authentik.screenshot("4_correct_version_in_admin_interface")

    with subtest("nginx proxies to authentik"):
        authentik.succeed("su - alice -c 'firefox --kiosk http://localhost/' >&2 &")
        authentik.wait_for_text("authentik")
        authentik.screenshot("5_nginx_proxies_requests")
  '';
}
