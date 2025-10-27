{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    types
    ;

  inherit (lib.attrsets)
    attrNames
    getAttrs
    mapAttrsToList
    ;

  inherit (lib.lists)
    flatten
    toList
    ;

  inherit (lib.modules)
    mkDefault
    mkIf
    mkMerge
    mkOverride
    ;

  inherit (lib.options)
    mkEnableOption
    mkOption
    ;

  inherit (lib.strings)
    concatStringsSep
    optionalString
    versionOlder
    ;

  inherit (lib.trivial)
    boolToString
    isBool
    ;

  settingsFormat = pkgs.formats.yaml { };

  pathToSecret = types.pathWith {
    inStore = false;
    absolute = true;
  };
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
          options = { };
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
          description = ''
            Specify the name for the server in {option}`services.nginx.virtualHosts` and
            for the associated Let's Encrypt certificate.
          '';
        };
      };

      environmentFile = mkOption {
        type = types.nullOr pathToSecret;
        default = null;
        example = "/run/secrets/authentik/authentik-env";
        description = ''
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

      worker = {
        listenHTTP = mkOption {
          type = types.str;
          default = "[::1]:9001";
          description = ''
            Listen address for the HTTP server of the worker.
            Overrides the default listen setting that's also used by the server.
          '';
        };
        listenMetrics = mkOption {
          type = types.str;
          default = "[::1]:9301";
          description = ''
            Listen address for the metrics server of the worker.
            Overrides the default listen setting that's also used by the server.
          '';
        };
      };
    };

    # LDAP oupost
    authentik-ldap = {
      enable = mkEnableOption "authentik LDAP outpost";

      listenMetrics = mkOption {
        type = types.str;
        default = "[::1]:9302";
        description = ''
          Listen address for the metrics server of the LDAP outpost.
          Overrides the default listen setting that's also used by the server.
        '';
      };

      environmentFile = mkOption {
        type = types.nullOr pathToSecret;
        default = null;
        example = "/run/secrets/authentik-ldap/authentik-ldap-env";
        description = ''
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

    # Proxy oupost
    authentik-proxy = {
      enable = mkEnableOption "authentik Proxy outpost";

      listenMetrics = mkOption {
        type = types.str;
        default = "[::1]:9303";
        description = ''
          Listen address for the metrics server of the proxy outpost.
          Overrides the default listen setting that's also used by the server.
        '';
      };
      listenHTTPS = mkOption {
        type = types.str;
        default = "[::1]:9004";
        description = ''
          Listen address for the HTTPS server of the proxy outpost.
          Overrides the default listen setting that's also used by the server.
        '';
      };
      listenHTTP = mkOption {
        type = types.str;
        default = "[::1]:9005";
        description = ''
          Listen address for the HTTP server of the proxy outpost.
          Overrides the default listen setting that's also used by the server.
        '';
      };

      environmentFile = mkOption {
        type = types.nullOr pathToSecret;
        default = null;
        example = "/run/secrets/authentik-proxy/authentik-proxy-env";
        description = ''
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

      listenMetrics = mkOption {
        type = types.str;
        default = "[::1]:9306";
        description = ''
          Listen address for the metrics server of the RADIUS outpost.
          Overrides the default listen setting that's also used by the server.
        '';
      };

      environmentFile = mkOption {
        type = types.nullOr pathToSecret;
        default = null;
        example = "/run/secrets/authentik-radius/authentik-radius-env";
        description = ''
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
    (mkIf config.services.authentik.enable (
      let
        cfg = config.services.authentik;

        # https://goauthentik.io/docs/installation/docker-compose#startup
        tz = "UTC";

        # Passed to each service and to the `ak` wrapper using `systemd-run(1)`
        environment.PROMETHEUS_MULTIPROC_DIR = "%S/authentik/prometheus";
        serviceDefaults = {
          DynamicUser = true;
          User = "authentik";
          EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
          ExecStartPre = [
            "${pkgs.coreutils}/bin/mkdir -p \${PROMETHEUS_MULTIPROC_DIR}"
          ];
        };
        akOptions = flatten (
          mapAttrsToList
            # Map defaults for each authentik service (listed above) to command line parameters for
            # `systemd-run(1)` in order to spin up an environment with correct (dynamic) user,
            # state directory and environment to run `ak` inside.
            (k: vs: map (v: "--property ${k}=${if isBool v then boolToString v else toString v}") (toList vs))
            # Read properties from `authentik.service`. That way, users can customize the properties using
            # module system primitives and the like.
            (
              removeAttrs config.systemd.services.authentik.serviceConfig [
                "ExecStart"
                "ExecStartPre"
                "Restart"
                "RestartSec"
                # systemd-run doesn't expand the %S specifier, so this is passed separately below.
                "WorkingDirectory"
              ]
            )
        );
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
            storage.media = {
              backend = mkDefault "file";
              file = mkDefault {
                path = "/var/lib/authentik/media";
              };
            };
            media.enable_upload = mkDefault true;
          };
          redis.servers.authentik = {
            enable = true;
            port = 6379;
          };
          postgresql = mkIf cfg.createDatabase {
            enable = true;
            ensureDatabases = [ "authentik" ];
            ensureUsers = [
              {
                name = "authentik";
                ensureDBOwnership = true;
              }
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

        environment.etc."authentik/config.yml".source =
          settingsFormat.generate "authentik.yml" cfg.settings;

        systemd.services = {
          authentik-migrate = {
            requires = lib.optionals cfg.createDatabase [ "postgresql.service" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ] ++ lib.optionals cfg.createDatabase [ "postgresql.service" ];
            before = [ "authentik.service" "authentik-migrate.service" ];
            restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
            environment = mkMerge [
              environment
              { TZ = tz; }
            ];
            serviceConfig = mkMerge [
              serviceDefaults
              {
                Type = "oneshot";
                RemainAfterExit = true;
                RuntimeDirectory = "authentik-migrate";
                WorkingDirectory = "%t/authentik-migrate";
                ExecStartPre = [
                  # needs access to "authentik/sources/schemas"
                  "${pkgs.coreutils}/bin/ln -svf ${cfg.authentikComponents.staticWorkdirDeps}/authentik"
                ];
                ExecStart = "${cfg.authentikComponents.migrate}/bin/migrate.py";
                Restart = "on-failure";
                RestartSec = "1s";
                inherit (config.systemd.services.authentik.serviceConfig) StateDirectory;
              }
            ];
          };
          authentik-worker = {
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            before = [ "authentik.service" ];
            restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
            preStart = ''
              ln -svf ${config.services.authentik.authentikComponents.staticWorkdirDeps}/* /run/authentik/
            '';
            environment = mkMerge [
              environment
              {
                TZ = tz;
                AUTHENTIK_LISTEN__HTTP = cfg.worker.listenHTTP;
                AUTHENTIK_LISTEN__METRICS = cfg.worker.listenMetrics;
              }
            ];
            serviceConfig = mkMerge [
              serviceDefaults
              {
                RuntimeDirectory = "authentik";
                WorkingDirectory = "%t/authentik";
                ExecStart = "${cfg.authentikComponents.manage}/bin/manage.py worker --pid-file %t/authentik/worker.pid";
                Restart = "on-failure";
                RestartSec = "1s";
                LoadCredential = mkIf (cfg.nginx.enable && cfg.nginx.enableACME) [
                  "${cfg.nginx.host}.pem:${config.security.acme.certs.${cfg.nginx.host}.directory}/fullchain.pem"
                  "${cfg.nginx.host}.key:${config.security.acme.certs.${cfg.nginx.host}.directory}/key.pem"
                ];
                # needs access to $StateDirectory/media/public
                inherit (config.systemd.services.authentik.serviceConfig) StateDirectory;
              }
            ];
          };
          authentik = {
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            requires = [
              "authentik-migrate.service"
              "authentik-worker.service"
            ];
            after = [
              "network-online.target"
              "redis-authentik.service"
            ]
            ++ (lib.optionals cfg.createDatabase [ "postgresql.service" ]);
            restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
            preStart = ''
              ln -svf ${cfg.authentikComponents.staticWorkdirDeps}/* /var/lib/authentik/
              ${optionalString (cfg.settings.storage.media.backend == "file") ''
                mkdir -p ${cfg.settings.storage.media.file.path}
              ''}
            '';
            environment = mkMerge [
              environment
              { TZ = tz; }
            ];
            serviceConfig = mkMerge [
              serviceDefaults
              {
                StateDirectory = "authentik";
                UMask = "0027";
                # TODO /run might be sufficient
                WorkingDirectory = "%S/authentik";
                ExecStart = "${cfg.authentikComponents.gopkgs}/bin/server";
                Restart = "on-failure";
                RestartSec = "1s";
              }
            ];
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
      }
    ))

    # LDAP outpost
    (mkIf config.services.authentik-ldap.enable (
      let
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
          environment.AUTHENTIK_LISTEN__METRICS = cfg.listenMetrics;
          serviceConfig = {
            RuntimeDirectory = "authentik-ldap";
            UMask = "0027";
            WorkingDirectory = "%t/authentik-ldap";
            DynamicUser = true;
            ExecStart = "${config.services.authentik.authentikComponents.gopkgs.ldap}/bin/ldap";
            EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
            Restart = "on-failure";
          };
        };
      }
    ))

    # Proxy outpost
    (mkIf config.services.authentik-proxy.enable (
      let
        cfg = config.services.authentik-proxy;
      in
      {
        systemd.services.authentik-proxy = {
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "authentik.service"
          ];
          environment = {
            AUTHENTIK_LISTEN__METRICS = cfg.listenMetrics;
            AUTHENTIK_LISTEN__HTTP = cfg.listenHTTP;
            AUTHENTIK_LISTEN__HTTPS = cfg.listenHTTPS;
          };
          serviceConfig = {
            RuntimeDirectory = "authentik-proxy";
            UMask = "0027";
            WorkingDirectory = "%t/authentik-proxy";
            DynamicUser = true;
            ExecStart = "${config.services.authentik.authentikComponents.gopkgs.proxy}/bin/proxy";
            EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
            Restart = "on-failure";
          };
        };
      }
    ))

    # RADIUS outpost
    (mkIf config.services.authentik-radius.enable (
      let
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
          environment.AUTHENTIK_LISTEN__METRICS = cfg.listenMetrics;
          serviceConfig = {
            RuntimeDirectory = "authentik-radius";
            UMask = "0027";
            WorkingDirectory = "%t/authentik-radius";
            DynamicUser = true;
            ExecStart = "${config.services.authentik.authentikComponents.gopkgs.radius}/bin/radius";
            EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
            Restart = "on-failure";
          };
        };
      }
    ))

    # This is an attempt to solve a rather ugly problem that was
    # caused by previously setting a default for the option
    # `services.postgresql.package` in this module.
    #
    # The problem is that some installations with a state version other than
    # 22.05, 22.11 or 23.05 may have used this module, meaning their postgresql
    # version was overridden by this module. Merely removing the setting here,
    # would cause their config to fall back to their respective default release,
    # resulting in a (temporarily) broken installation.
    #
    # While recovering from this is relatively easy, i.e. they would need to
    # override the posgresql package in their own config, it is not desirable
    # to break those installations.
    #
    # The idea is to no longer set a default value for the package for new
    # installations. Instead new installations use the sensible default provided
    # by nixpkgs. At the same time this should keep the previous default
    # for old installations.
    #
    # After postgresql_14 has been removed from nixpkgs, this workaround can be dropped.
    (mkIf (versionOlder config.system.stateVersion "24.05") {
      # The upstream postgresl module is using mkDefault
      # to specify the default value for the package option.
      # Unfortunately this forces us to specify this default with
      # a higher priority, i.e. lower number, than mkDefault which
      # has priority 1000
      services.postgresql.package = mkOverride 999 pkgs.postgresql_14;
    })
  ];
}
