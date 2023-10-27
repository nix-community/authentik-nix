{
  description = "Nix package, NixOS module and VM integration test for authentik";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    napalm = {
      url = "github:nix-community/napalm";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    authentik-src = { # change version string in outputs as well when updating
      url = "github:goauthentik/authentik/version/2023.10.1";
      flake = false;
    };
  };

  outputs = inputs@{
    self,
    nixpkgs,
    flake-parts,
    poetry2nix,
    napalm,
    authentik-src,
    ...
  }:

  flake-parts.lib.mkFlake
    { inherit inputs; }
    ({ inputs, lib, withSystem, ... }:
    let
      authentik-version = "2023.10.1"; # to pass to the drvs of some components
    in {
      systems = [
        "x86_64-linux"
        "aarch64-linux" # not tested
      ];
      flake = {
        nixosModules.default = { pkgs, ... }: {
          imports = [ ./module.nix ];
          services.authentik.authentikComponents = withSystem pkgs.stdenv.hostPlatform.system (
            { config, ... }:
            { inherit (config.packages) celery staticWorkdirDeps migrate pythonEnv frontend gopkgs docs; }
          );
        };
      };
      perSystem = { pkgs, system, ... }: let
        inherit (import inputs.poetry2nix { inherit pkgs; })
          mkPoetryEnv
          defaultPoetryOverrides;
      in {
        packages = rec {
          docs = napalm.legacyPackages.${system}.buildPackage "${authentik-src}/website" {
            version = authentik-version; # 0.0.0 specified upstream in package.json
            NODE_ENV = "production";
            nodejs = pkgs.nodejs_20;
            npmCommands = [
              "cp -v ${authentik-src}/SECURITY.md ../SECURITY.md"
              "cp -vr ${authentik-src}/blueprints ../blueprints"
              "npm install --include=dev"
              "npm run build-docs-only"
            ];
            installPhase = ''
              rm -r ../website/node_modules/.cache
              mv -v ../website $out
            '';
          };
          frontend = napalm.legacyPackages.${system}.buildPackage "${authentik-src}/web" rec {
            version = authentik-version; # 0.0.0 specified upstream in package.json
            NODE_ENV = "production";
            nodejs = pkgs.nodejs_21;
            preBuild = ''
              ln -sv ${docs} ../website
            '';
            npmCommands = [
              "npm install --include=dev --nodedir=${nodejs}/include/node --loglevel verbose --ignore-scripts"
              "npm run build"
            ];
            installPhase = ''
              mkdir $out
              mv dist $out/dist
              cp -r authentik icons $out
            '';
          };
          pythonEnv = mkPoetryEnv {
            projectDir = authentik-src;
            python = pkgs.python311;
            overrides = [ defaultPoetryOverrides ] ++ (import ./poetry2nix-python-overrides.nix pkgs);
            # workaround to remove dev-dependencies for the current combination of legacy pyproject.toml format
            # used by authentik and poetry2nix's behavior
            groups = [];
            checkGroups = [];
            pyproject = pkgs.runCommandLocal "patched-pyproject.toml" {} ''
              sed -e 's,tool.poetry.dev-dependencies,tool.poetry.group.dev.dependencies,' ${authentik-src}/pyproject.toml > $out
            '';
          };
          # server + outposts
          gopkgs = pkgs.buildGo121Module {
            pname = "authentik-gopkgs";
            version = authentik-version;
            prePatch = ''
              sed -i"" -e 's,./web/dist/,${frontend}/dist/,' web/static.go
              sed -i"" -e 's,./web/dist/,${frontend}/dist/,' internal/web/static.go
              sed -i"" -e 's,./lifecycle/gunicorn.conf.py,${staticWorkdirDeps}/lifecycle/gunicorn.conf.py,' internal/gounicorn/gounicorn.go
            '';
            src = pkgs.lib.cleanSourceWith {
              src = authentik-src;
              filter = (path: _:
                (builtins.any (x: x) (
                  (map (infix: pkgs.lib.hasInfix infix path) [
                    "/authentik"
                    "/cmd"
                    "/internal"
                  ])
                  ++
                  (map (suffix: pkgs.lib.hasSuffix suffix path) [
                    "/web"
                    "/web/static.go"
                    "/web/robots.txt"
                    "/web/security.txt"
                    "go.mod"
                    "go.sum"
                  ])
                ))
              );
            };
            subPackages = [
              "cmd/ldap"
              "cmd/server"
              "cmd/proxy"
              "cmd/radius"
            ];
            vendorSha256 = "sha256-JQRGlQ7iYrB5nKli3hoIAJHG9UeGqVD+dMupMUDZ2Zo=";
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postInstall = ''
              wrapProgram $out/bin/server --prefix PATH : ${pythonEnv}/bin
              wrapProgram $out/bin/server --prefix PYTHONPATH : ${staticWorkdirDeps}
            '';
          };
          staticWorkdirDeps = pkgs.linkFarm "authentik-static-workdir-deps" [
            { name = "authentik"; path = "${authentik-src}/authentik"; }
            { name = "locale"; path = "${authentik-src}/locale"; }
            { name = "blueprints"; path = "${authentik-src}/blueprints"; }
            { name = "internal"; path = "${authentik-src}/internal"; }
            { name = "lifecycle"; path = "${authentik-src}/lifecycle"; }
            { name = "schemas"; path = "${authentik-src}/schemas"; }
            { name = "web"; path = frontend; }
          ];
          migrate = pkgs.runCommandLocal "authentik-migrate.py" {
            nativeBuildInputs = [ pkgs.makeWrapper ];
          } ''
            mkdir -vp $out/bin
            cp ${authentik-src}/lifecycle/migrate.py $out/bin/migrate.py
            chmod +w $out/bin/migrate.py
            patchShebangs $out/bin/migrate.py
            substituteInPlace $out/bin/migrate.py \
              --replace \
              'migration_path in Path(__file__).parent.absolute().glob("system_migrations/*.py")' \
              'migration_path in Path("${staticWorkdirDeps}/lifecycle").glob("system_migrations/*.py")'
            wrapProgram $out/bin/migrate.py \
              --prefix PATH : ${pythonEnv}/bin \
              --prefix PYTHONPATH : ${staticWorkdirDeps}
          '';
          # worker
          celery = pkgs.runCommandLocal "authentik-celery" {
            nativeBuildInputs = [ pkgs.makeWrapper ];
          } ''
            mkdir -vp $out/bin
            ln -sv ${pythonEnv}/bin/celery $out/bin/celery
            wrapProgram $out/bin/celery \
              --prefix PYTHONPATH : ${staticWorkdirDeps}
          '';
          # terraform provider
          terraform-provider-authentik = pkgs.buildGo118Module rec {
            pname = "terraform-provider-authentik";
            version = "2023.8.0";
            src = pkgs.fetchFromGitHub {
              owner = "goauthentik";
              repo = pname;
              rev = "v${version}";
              sha256 = "sha256-AIf+l26TqFS8Nfe/Qu0rZtCEHzWO1Jao8/KIY1IrriQ=";
            };
            doCheck = false; # tests are run against authentik -> vm test
            vendorSha256 = "sha256-U4dYBFPQodmVyIXsapsstSe50G3HmBv9bvPfJq84CDU=";
            postInstall = ''
              path="$out/libexec/terraform-providers/registry.terraform.io/goauthentik/authentik/${version}/''${GOOS}_''${GOARCH}/"
              mkdir -p "$path"
              mv $out/bin/${pname} $path/${pname}_v${version}
              rmdir $out/bin
            '';
          };
        };
        checks = {
          default = self.checks.${system}.vmtest;
          vmtest = (import ./test.nix {
            inherit pkgs authentik-version;
            inherit (self) nixosModules;
          });
        };
        devShells.default = pkgs.mkShell {
          packages = [
            # to generate a v2 lockfile from the v3 lockfile provided by upstream:
            # npm install --lockfile-version 2 --package-lock-only
            pkgs.nodejs
          ];
        };
      };
    });
}
