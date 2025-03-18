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
        type = types.nullOr types.path;
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
    };

    # LDAP oupost
    authentik-ldap = {
      enable = mkEnableOption "authentik LDAP outpost";

      environmentFile = mkOption {
        type = types.nullOr types.path;
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

      environmentFile = mkOption {
        type = types.nullOr types.path;
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

      environmentFile = mkOption {
        type = types.nullOr types.path;
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
        serviceDefaults = {
          DynamicUser = true;
          User = "authentik";
          EnvironmentFile = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
        };
        akOptions = flatten (
          mapAttrsToList
            # Map defaults for each authentik service (listed above) to command line parameters for
            # `systemd-run(1)` in order to spin up an environment with correct (dynamic) user,
            # state directory and environment to run `ak` inside.
            (k: vs: map (v: "--property ${k}=${if isBool v then boolToString v else toString v}") (toList vs))
            # Read serviceDefaults from `authentik.service`. That way, module system primitives (mk*)
            # can be used inside `serviceDefaults` and it doesn't need to be evaluated here again.
            (
              getAttrs (attrNames serviceDefaults) config.systemd.services.authentik.serviceConfig
              // {
                StateDirectory = "authentik";
              }
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
            requiredBy = [ "authentik.service" ];
            requires = lib.optionals cfg.createDatabase [ "postgresql.service" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ] ++ lib.optionals cfg.createDatabase [ "postgresql.service" ];
            before = [ "authentik.service" ];
            restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
            environment.TZ = tz;
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
            requiredBy = [ "authentik.service" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            before = [ "authentik.service" ];
            restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
            preStart = ''
              ln -svf ${config.services.authentik.authentikComponents.staticWorkdirDeps}/* /run/authentik/
            '';
            environment.TZ = tz;
            serviceConfig = mkMerge [
              serviceDefaults
              {
                RuntimeDirectory = "authentik";
                WorkingDirectory = "%t/authentik";
                ExecStart = "${cfg.authentikComponents.manage}/bin/manage.py worker";
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
            after = [
              "network-online.target"
              "redis-authentik.service"
            ] ++ (lib.optionals cfg.createDatabase [ "postgresql.service" ]);
            restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
            preStart = ''
              ln -svf ${cfg.authentikComponents.staticWorkdirDeps}/* /var/lib/authentik/
              ${optionalString (cfg.settings.storage.media.backend == "file") ''
                mkdir -p ${cfg.settings.storage.media.file.path}
              ''}
            '';
            environment.TZ = tz;
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
          serviceConfig = {
            RuntimeDirectory = "authentik-proxy";
            UMask = "0027";
            WorkingDirectory = "%t/authentik-proxy";
            DynamicUser = true;
            ExecStart = "${config.services.authentik.authentikComponents.gopkgs}/bin/proxy";
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
