{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    types;

  inherit (lib.modules)
    mkDefault
    mkIf
    mkMerge;

  inherit (lib.options)
    mdDoc
    mkEnableOption
    mkOption;

  settingsFormat = pkgs.formats.yaml {};
in
{
  options.services = {
    # authentik server
    authentik = {
      enable = mkEnableOption "authentik";

      authentikComponents = mkOption {
        type = types.attrsOf types.package;
      };

      settings = mkOption {
        type = types.submodule {
          freeformType = settingsFormat.type;
          options = {};
        };
      };

      createDatabase = mkOption {
        type = types.bool;
        default = true;
      };

      nginx = {
        enable = mkEnableOption "basic nginx configuration";
        enableACME = mkEnableOption "Let's Encrypt and certificate discovery";
        host = mkOption {
          type = types.str;
          example = "auth.example.com";
          description = mdDoc ''
            Specify the name for the server in {option}`services.nginx.virtualHosts` and
            for the associated Let's Encrypt certificate.
          '';
        };
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/authentik/authentik-env";
        description = mdDoc ''
          Environment file as defined in {manpage}`systemd.exec(5)`.

          Secrets may be passed to the service without adding them to the world-readable
          /nix/store, by specifying the desied secrets as environment variables according
          to the authentic documentation.

          ```
            # example content
            AUTHENTIK_SECRET_KEY=<secret key>
            AUTHENTIK_EMAIL__PASSWORD=<smtp password>
          ```
        '';
      };
    };

    # LDAP oupost
    authentik-ldap = {
      enable = mkEnableOption "authentik LDAP outpost";

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/authentik-ldap/authentik-ldap-env";
        description = mdDoc ''
          Environment file as defined in {manpage}`systemd.exec(5)`.

          Secrets may be passed to the service without adding them to the world-readable
          /nix/store, by specifying the desied secrets as environment variables according
          to the authentic documentation.

          ```
            # example content
            AUTHENTIK_TOKEN=<token from authentik for this outpost>
          ```
        '';
      };
    };
  };

  config = mkMerge [
    # authentik server
    (mkIf config.services.authentik.enable (let
      cfg = config.services.authentik;
    in
    {
      services = {
        authentik.settings = {
          blueprints_dir = mkDefault "${cfg.authentikComponents.staticWorkdirDeps}/blueprints";
          template_dir = mkDefault "${cfg.authentikComponents.staticWorkdirDeps}/templates";
          postgresql = {
            user = mkDefault "authentik";
            name = mkDefault "authentik";
            host = mkDefault "";
          };
          cert_discovery_dir = mkIf (cfg.nginx.enable && cfg.nginx.enableACME) "env://CREDENTIALS_DIRECTORY";
        };
        redis.servers.authentik = {
          enable = true;
          port = 6379;
        };
        postgresql = {
          enable = true;
          package = pkgs.postgresql_14;
          ensureDatabases = mkIf cfg.createDatabase [ "authentik" ];
          ensureUsers = mkIf cfg.createDatabase [
            { name = "authentik"; ensureDBOwnership = true; }
          ];
        };
      };

      # https://goauthentik.io/docs/installation/docker-compose#explanation
      time.timeZone = "UTC";

      environment.etc."authentik/config.yml".source = settingsFormat.generate "authentik.yml" cfg.settings;

      systemd.services = {
        authentik-migrate = {
          requiredBy = [ "authentik.service" ];
          requires = [ "postgresql.service" ];
          after = [ "postgresql.service" ];
          before = [ "authentik.service" ];
          restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            DynamicUser = true;
            User = "authentik";
            ExecStart = "${cfg.authentikComponents.migrate}/bin/migrate.py";
            EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
          };
        };
        authentik-worker = {
          requiredBy = [ "authentik.service" ];
          before = [ "authentik.service" ];
          restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
          preStart = ''
            ln -svf ${config.services.authentik.authentikComponents.staticWorkdirDeps}/* /run/authentik/
          '';
          serviceConfig = {
            RuntimeDirectory = "authentik";
            WorkingDirectory = "%t/authentik";
            DynamicUser = true;
            User = "authentik";
            # TODO maybe make this configurable
            ExecStart = "${cfg.authentikComponents.celery}/bin/celery -A authentik.root.celery worker -Ofair --max-tasks-per-child=1 --autoscale 3,1 -E -B -s /tmp/celerybeat-schedule -Q authentik,authentik_scheduled,authentik_events";
            EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
            LoadCredential = mkIf (cfg.nginx.enable && cfg.nginx.enableACME) [
              "${cfg.nginx.host}.pem:${config.security.acme.certs.${cfg.nginx.host}.directory}/fullchain.pem"
              "${cfg.nginx.host}.key:${config.security.acme.certs.${cfg.nginx.host}.directory}/key.pem"
            ];
          };
        };
        authentik = {
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
            "postgresql.service"
            "redis-authentik.service"
          ];
          restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
          preStart = ''
            ln -svf ${cfg.authentikComponents.staticWorkdirDeps}/* /var/lib/authentik/
          '';
          serviceConfig = {
            Environment = [
              "AUTHENTIK_ERROR_REPORTING__ENABLED=false"
              "AUTHENTIK_DISABLE_UPDATE_CHECK=true"
              "AUTHENTIK_DISABLE_STARTUP_ANALYTICS=true"
              "AUTHENTIK_AVATARS=initials"
            ];
            StateDirectory = "authentik";
            UMask = "0027";
            # TODO /run might be sufficient
            WorkingDirectory = "%S/authentik";
            DynamicUser = true;
            ExecStart = "${cfg.authentikComponents.gopkgs}/bin/server";
            EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
          };
        };
      };

      services.nginx = mkIf cfg.nginx.enable {
        enable = true;
        recommendedTlsSettings = true;
        recommendedProxySettings = true;
        virtualHosts.${cfg.nginx.host} = {
          inherit (cfg.nginx) enableACME;
          forceSSL = cfg.nginx.enableACME;
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "https://localhost:9443";
          };
        };
      };
    }))

    # LDAP outpost
    (mkIf config.services.authentik-ldap.enable (let
      cfg = config.services.authentik-ldap;
    in
    {
      systemd.services.authentik-ldap = {
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "authentik.service"
        ];
        restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
        serviceConfig = {
          RuntimeDirectory = "authentik-ldap";
          UMask = "0027";
          WorkingDirectory = "%t/authentik-ldap";
          DynamicUser = true;
          ExecStart = "${config.services.authentik.authentikComponents.gopkgs}/bin/ldap";
          EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
        };
      };
    }))
  ];
}
