{ pkgs
, overlays
, nixosModules
}:
let
  # use a root-owned EnvironmentFile in production instead (systemd.services.<name>.serviceConfig.EnvironmentFile)
  secrets = {
    authentiksecret = "thissecretwillbeinthenixstore";
    postgresql = "dontusethisinproduction";
  };
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
      nixpkgs.overlays = [ overlays.default ];

      services.authentik.enable = true;

      services.postgresql.initialScript = pkgs.writeText "psql-init.sql" ''
        CREATE DATABASE authentik;
        CREATE USER authentik WITH PASSWORD '${secrets.postgresql}';
        GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik
      '';
      systemd.services.authentik-migrate.serviceConfig.Environment = [
        "AUTHENTIK_POSTGRESQL__PASSWORD=${secrets.postgresql}"
        "AUTHENTIK_SECRET_KEY=${secrets.authentiksecret}"
      ];
      systemd.services.authentik-worker.serviceConfig.Environment = [
        "AUTHENTIK_POSTGRESQL__PASSWORD=${secrets.postgresql}"
        "AUTHENTIK_SECRET_KEY=${secrets.authentiksecret}"
      ];
      systemd.services.authentik.serviceConfig.Environment = [
        "AUTHENTIK_POSTGRESQL__PASSWORD=${secrets.postgresql}"
        "AUTHENTIK_SECRET_KEY=${secrets.authentiksecret}"
      ];

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
    authentik.wait_until_succeeds("curl -fL http://localhost:9000/if/flow/initial-setup >&2")

    with subtest("Frontend renders"):
        machine.succeed("su - alice -c 'firefox http://localhost:9000/if/flow/initial-setup' >&2 &")
        machine.wait_for_text("Welcome to authentik")
        machine.screenshot("initial-setup_1")

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
        machine.screenshot("initial-setup_2")
  '';
}
