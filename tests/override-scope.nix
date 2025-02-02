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
  # use a root-owned EnvironmentFile in production instead (services.authentik.environmentFile)
  authentik-env = pkgs.writeText "authentik-test-secret-env" ''
    AUTHENTIK_SECRET_KEY=thissecretwillbeinthenixstore
  '';

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
pkgs.nixosTest {
  name = "authentik";
  nodes = {
    authentik = {
      virtualisation = {
        cores = 3;
        memorySize = 2048;
      };
      imports = [
        nixosModules.default
        "${pkgs.path}/nixos/tests/common/user-account.nix"
        "${pkgs.path}/nixos/tests/common/x11.nix"
      ];

      services.authentik = {
        enable = true;
        environmentFile = authentik-env;
        nginx = {
          enable = true;
          host = "localhost";
        };
        # pass authentikComponents with patched pythonEnv and staticWorkdirDeps
        inherit (customScope) authentikComponents;
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
    authentik.wait_for_unit("redis-authentik.service")
    authentik.wait_for_unit("authentik-migrate.service")
    authentik.wait_for_unit("authentik-worker.service")
    authentik.wait_for_unit("authentik.service")
    authentik.wait_for_open_port(9000)
    authentik.wait_until_succeeds("curl -fL http://localhost:9000/if/flow/initial-setup/ >&2")

    with subtest("Frontend renders"):
        machine.succeed("su - alice -c 'firefox http://localhost:9000/if/flow/initial-setup/' >&2 &")
        machine.wait_for_text("${customWelcome}")
        machine.screenshot("1_rendered_frontend")

    with subtest("admin account setup works"):
        machine.send_key("tab")
        machine.send_key("tab")
        machine.send_chars("akadmin@localhost")
        machine.send_key("tab")
        machine.send_chars("foobar")
        machine.send_key("tab")
        machine.send_chars("foobar")
        machine.send_key("ret")
        machine.wait_for_text("My applications")
        machine.send_key("esc")
        machine.screenshot("2_initial_setup_successful")

    with subtest("admin settings render and version as expected"):
        machine.succeed("su - alice -c 'firefox http://localhost:9000/if/admin/' >&2 &")
        machine.wait_for_text("General system status")
        machine.screenshot("3_rendered_admin_interface")
        machine.succeed("su - alice -c 'xdotool click 1' >&2")
        machine.succeed("su - alice -c 'xdotool key --delay 100 Page_Down' >&2")
        # sometimes the cursor covers the version string
        machine.succeed("su - alice -c 'xdotool mousemove_relative 50 50' >&2")
        machine.wait_for_text("${builtins.replaceStrings [ "." ] [ ".?" ] authentik-version}")
        machine.screenshot("4_correct_version_in_admin_interface")

    with subtest("nginx proxies to authentik"):
        machine.succeed("su - alice -c 'firefox http://localhost/' >&2 &")
        machine.wait_for_text("authentik")
        machine.screenshot("5_nginx_proxies_requests")
  '';
}
