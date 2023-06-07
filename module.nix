{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.services.authentik;

  inherit (lib)
    types;

  inherit (lib.modules)
    mkDefault
    mkIf;

  inherit (lib.options)
    mkEnableOption
    mkOption;

  inherit (pkgs.authentik)
    migrate
    gopkgs
    celery
    staticWorkdirDeps;

  settingsFormat = pkgs.formats.yaml {};
in
{
  options.services.authentik = {
    enable = mkEnableOption "authentik";

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

  config = mkIf cfg.enable {
    services = {
      authentik.settings = {
        blueprints_dir = mkDefault "${pkgs.authentik.staticWorkdirDeps}/blueprints";
        template_dir = mkDefault "${pkgs.authentik.staticWorkdirDeps}/templates";
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
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          DynamicUser = true;
          User = "authentik";
          ExecStart = "${pkgs.authentik.migrate}/bin/migrate.py";
        };
      };
      authentik-worker = {
        requiredBy = [ "authentik.service" ];
        before = [ "authentik.service" ];
        serviceConfig = {
          RuntimeDirectory = "authentik";
          WorkingDirectory = "%t/authentik";
          DynamicUser = true;
          User = "authentik";
          # TODO maybe make this configurable
          ExecStart = "${pkgs.authentik.celery}/bin/celery -A authentik.root.celery worker -Ofair --max-tasks-per-child=1 --autoscale 3,1 -E -B -s /tmp/celerybeat-schedule -Q authentik,authentik_scheduled,authentik_events";
        };
      };
      authentik = {
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "postgresql.service"
          "redis-authentik.service"
        ];
        preStart = ''
          ln -svf ${pkgs.authentik.staticWorkdirDeps}/* /var/lib/authentik/
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
          ExecStart = "${pkgs.authentik.gopkgs}/bin/server";
        };
      };
    };
  };
}
