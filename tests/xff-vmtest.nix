{
  pkgs,
  nixosModules,
}:
# authentik behind the module's nginx, which appends to X-Forwarded-For
# (recommendedProxySettings). A client-supplied leftmost entry must not become
# the client IP: authentik has to record the address nginx saw.
let
  # outside the default trusted_proxy_cidrs (RFC1918, loopback): a client on the
  # test network's 192.168.1.0/24 would itself count as a trusted proxy
  serverIp = "198.51.100.1";
  clientIp = "198.51.100.2";
  ipv4Only = address: {
    networking.interfaces.eth1.ipv4.addresses = pkgs.lib.mkForce [
      {
        inherit address;
        prefixLength = 24;
      }
    ];
  };
in
pkgs.testers.runNixOSTest {
  name = "authentik-x-forwarded-for";
  nodes = {
    server = {
      virtualisation = {
        cores = 3;
        memorySize = 3072;
      };
      imports = [
        nixosModules.default
        (ipv4Only serverIp)
      ];

      # see minimal-vmtest.nix: not how secrets should be handled outside a test
      systemd.tmpfiles.rules = [
        "f /etc/authentik.env 0700 root root - AUTHENTIK_SECRET_KEY=notastorepath"
      ];

      services.authentik = {
        enable = true;
        environmentFile = "/etc/authentik.env";
        nginx = {
          enable = true;
          host = "server";
        };
        settings.disable_update_check = true;
      };

      networking.firewall.allowedTCPPorts = [ 80 ];
    };

    client = {
      imports = [ (ipv4Only clientIp) ];
    };
  };

  testScript = ''
    import json

    start_all()

    server.wait_for_unit("authentik.service")
    server.wait_for_open_port(9000)
    server.wait_until_succeeds("curl -fs http://localhost:9000/-/health/ready/")
    server.wait_for_unit("nginx.service")

    client_ip = "${clientIp}"
    forged = "203.0.113.7"


    def get(marker, headers=""):
        client.succeed(
            f"curl -fs -o /dev/null -H 'Host: server' {headers} "
            f"'http://${serverIp}/api/v3/root/config/?xfftest={marker}'"
        )


    def remote_for(marker):
        """remote field of authentik's request log line for a unique query marker"""
        server.wait_until_succeeds(f"journalctl -u authentik.service -o cat | grep -q 'xfftest={marker}'")
        for line in server.succeed("journalctl -u authentik.service -o cat").splitlines():
            if f"xfftest={marker}" not in line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if "remote" in entry:
                return entry["remote"]
        raise Exception(f"no request log line with a remote field for marker {marker}")


    with subtest("without X-Forwarded-For from the client"):
        get("plain")
        remote = remote_for("plain")
        assert remote == client_ip, f"expected {client_ip}, got {remote}"

    with subtest("client-supplied X-Forwarded-For is not the client IP"):
        get("forged", f"-H 'X-Forwarded-For: {forged}'")
        remote = remote_for("forged")
        assert remote != forged, f"authentik recorded the forged address {forged}"
        assert remote == client_ip, f"expected {client_ip}, got {remote}"
  '';
}
