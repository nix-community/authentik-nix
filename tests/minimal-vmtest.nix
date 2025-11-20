{
  pkgs,
  authentik-version,
  nixosModules,
}:
pkgs.testers.runNixOSTest {
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

    with subtest("metrics & worker"):
        machine.wait_for_open_port(9300)
        machine.wait_for_open_port(9301)

        print(machine.succeed("curl -L localhost:9300/metrics | grep authentik_outpost_connection | grep 'Embedded'"))
        print(machine.succeed("curl -L localhost:9301/metrics | grep authentik_tasks_total"))
  '';
}
