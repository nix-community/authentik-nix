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
    mkEnableOption
    mkOption;

  settingsFormat = pkgs.formats.yaml {};
in
{
  options.services = {
    authentik = {
      enable = mkEnableOption "authentik";

      authentikComponents = {
        celery = mkOption { type = types.package; };
        staticWorkdirDeps = mkOption { type = types.package; };
        migrate = mkOption { type = types.package; };
        pythonEnv = mkOption { type = types.package; };
        frontend = mkOption { type = types.package; };
        gopkgs = mkOption { type = types.package; };
        docs = mkOption { type = types.package; };
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
            { name = "authentik"; ensurePermissions."DATABASE authentik" = "ALL PRIVILEGES"; }
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
          };
        };
        authentik-worker = {
          requiredBy = [ "authentik.service" ];
          before = [ "authentik.service" ];
          restartTriggers = [ config.environment.etc."authentik/config.yml".source ];
          serviceConfig = {
            RuntimeDirectory = "authentik";
            WorkingDirectory = "%t/authentik";
            DynamicUser = true;
            User = "authentik";
            # TODO maybe make this configurable
            ExecStart = "${cfg.authentikComponents.celery}/bin/celery -A authentik.root.celery worker -Ofair --max-tasks-per-child=1 --autoscale 3,1 -E -B -s /tmp/celerybeat-schedule -Q authentik,authentik_scheduled,authentik_events";
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
          };
        };
      };
    }))
  ];
}
