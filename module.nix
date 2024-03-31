{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    types;

  inherit (lib.attrsets)
    attrNames
    getAttrs
    mapAttrsToList;

  inherit (lib.lists)
    flatten
    toList;

  inherit (lib.modules)
    mkDefault
    mkIf
    mkMerge;

  inherit (lib.options)
    mdDoc
    mkEnableOption
    mkOption;

  inherit (lib.strings)
    concatStringsSep;

  inherit (lib.trivial)
    boolToString
    isBool;

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

    # RADIUS oupost
    authentik-radius = {
      enable = mkEnableOption "authentik RADIUS outpost";

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/authentik-radius/authentik-radius-env";
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

      # Passed to each service and to the `ak` wrapper using `systemd-run(1)`
      serviceDefaults = {
        DynamicUser = true;
        User = "authentik";
        EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
      };
      akOptions = flatten (mapAttrsToList
        # Map defaults for each authentik service (listed above) to command line parameters for
        # `systemd-run(1)` in order to spin up an environment with correct (dynamic) user,
        # state directory and environment to run `ak` inside.
        (k: vs: map
          (v: "--property ${k}=${if isBool v then boolToString v else toString v}")
          (toList vs))
        # Read serviceDefaults from `authentik.service`. That way, module system primitives (mk*)
        # can be used inside `serviceDefaults` and it doesn't need to be evaluated here again.
        (getAttrs (attrNames serviceDefaults) config.systemd.services.authentik.serviceConfig // {
          StateDirectory = "authentik";
        }));
    in
    {
      services = {
        authentik.settings = {
          blueprints_dir = mkDefault "${cfg.authentikComponents.staticWorkdirDeps}/blueprints";
          template_dir = mkDefault "${cfg.authentikComponents.staticWorkdirDeps}/templates";
          postgresql = mkIf cfg.createDatabase {
            user = mkDefault "authentik";
            name = mkDefault "authentik";
            host = mkDefault "";
          };
          cert_discovery_dir = mkIf (cfg.nginx.enable && cfg.nginx.enableACME) "env://CREDENTIALS_DIRECTORY";
          paths.media = mkDefault "/var/lib/authentik/media";
          media.enable_upload = mkDefault true;
        };
        redis.servers.authentik = {
          enable = true;
          port = 6379;
        };
        postgresql = mkIf cfg.createDatabase {
          enable = true;
          package = pkgs.postgresql_14;
          ensureDatabases = [ "authentik" ];
          ensureUsers = [
            { name = "authentik"; ensureDBOwnership = true; }
          ];
        };
      };

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "ak" ''
          exec ${config.systemd.package}/bin/systemd-run --pty --collect \
            ${concatStringsSep " \\\n" akOptions} \
            --working-directory /var/lib/authentik \
            -- ${cfg.authentikComponents.manage}/bin/manage.py "$@"
        '')
      ];

      # https://goauthentik.io/docs/installation/docker-compose#explanation
      time.timeZone = "UTC";

      environment.etc."authentik/config.yml".source = settingsFormat.generate "authentik.yml" cfg.settings;

      systemd.services = {
        authentik-migrate = {
          requiredBy = [ "authentik.service" ];
          requires = lib.optionals cfg.createDatabase [ "postgresql.service" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ] ++ lib.optionals cfg.createDatabase [ "postgresql.service" ];
          before = [ "authentik.service" ];
          restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
          serviceConfig = mkMerge [ serviceDefaults {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${cfg.authentikComponents.migrate}/bin/migrate.py";
            inherit (config.systemd.services.authentik.serviceConfig) StateDirectory;
          } ];
        };
        authentik-worker = {
          requiredBy = [ "authentik.service" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          before = [ "authentik.service" ];
          restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
          preStart = ''
            ln -svf ${config.services.authentik.authentikComponents.staticWorkdirDeps}/* /run/authentik/
          '';
          serviceConfig = mkMerge [ serviceDefaults {
            RuntimeDirectory = "authentik";
            WorkingDirectory = "%t/authentik";
            # TODO maybe make this configurable
            ExecStart = "${cfg.authentikComponents.manage}/bin/manage.py worker";
            LoadCredential = mkIf (cfg.nginx.enable && cfg.nginx.enableACME) [
              "${cfg.nginx.host}.pem:${config.security.acme.certs.${cfg.nginx.host}.directory}/fullchain.pem"
              "${cfg.nginx.host}.key:${config.security.acme.certs.${cfg.nginx.host}.directory}/key.pem"
            ];
          } ];
        };
        authentik = {
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "redis-authentik.service"
          ] ++ (lib.optionals cfg.createDatabase [ "postgresql.service" ]);
          restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
          preStart = ''
            ln -svf ${cfg.authentikComponents.staticWorkdirDeps}/* /var/lib/authentik/
            mkdir -p ${cfg.settings.paths.media}
          '';
          serviceConfig = mkMerge [ serviceDefaults {
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
            ExecStart = "${cfg.authentikComponents.gopkgs}/bin/server";
          } ];
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
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "authentik.service"
        ];
        serviceConfig = {
          RuntimeDirectory = "authentik-ldap";
          UMask = "0027";
          WorkingDirectory = "%t/authentik-ldap";
          DynamicUser = true;
          ExecStart = "${config.services.authentik.authentikComponents.gopkgs}/bin/ldap";
          EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
          Restart = "on-failure";
        };
      };
    }))

    # RADIUS outpost
    (mkIf config.services.authentik-radius.enable (let
      cfg = config.services.authentik-radius;
    in
    {
      systemd.services.authentik-radius = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "authentik.service"
        ];
        serviceConfig = {
          RuntimeDirectory = "authentik-radius";
          UMask = "0027";
          WorkingDirectory = "%t/authentik-radius";
          DynamicUser = true;
          ExecStart = "${config.services.authentik.authentikComponents.gopkgs}/bin/radius";
          EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
          Restart = "on-failure";
        };
      };
    }))
  ];
}
