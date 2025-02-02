{
  pkgs,
  authentik-version,
  nixosModules,
}:
let
  # use a root-owned EnvironmentFile in production instead (services.authentik.environmentFile)
  authentik-env = pkgs.writeText "authentik-test-secret-env" ''
    AUTHENTIK_SECRET_KEY=thissecretwillbeinthenixstore
  '';
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
        machine.wait_for_text("Welcome to authentik")
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
