{
  description = "Nix package, NixOS module and VM integration test for authentik";

  inputs = {
    systems.url = "github:nix-systems/default-linux";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    napalm = {
      url = "github:willibutz/napalm/avoid-foldl-stack-overflow";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    authentik-src = {
      # change version string in outputs as well when updating
      url = "github:goauthentik/authentik/version-2025.10";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      napalm,
      authentik-src,
      uv2nix,
      pyproject-build-systems,
      pyproject-nix,
      ...
    }:

    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        inputs,
        lib,
        withSystem,
        ...
      }:
      let
        authentik-version = "2025.10.3"; # to pass to the drvs of some components
      in
      {
        systems = import inputs.systems;
        flake =
          { self, ... }:
          {
            nixosModules.default =
              { pkgs, ... }:
              {
                imports = [ ./module.nix ];
                services.authentik.authentikComponents = pkgs.lib.mkDefault (
                  withSystem pkgs.stdenv.hostPlatform.system (
                    { config, ... }:
                    {
                      inherit (config.packages)
                        manage
                        staticWorkdirDeps
                        migrate
                        pythonEnv
                        frontend
                        gopkgs
                        docs
                        ;
                    }
                  )
                );
              };

            # returns a scope which includes the attrset `authentikComponents`
            #
            # the returned scope may be overridden using its `overrideScope` function to
            # create a new scope with patched versions of individual authentik components
            #
            # see ./tests/override-scope.nix for a usage example
            lib.mkAuthentikScope =
              let
                authentik-version' = authentik-version;
              in
              {
                pkgs,
                system ? pkgs.stdenv.hostPlatform.system,
                python ? pkgs.python313,
                authentik-version ? authentik-version',
                buildNapalmPackage ? napalm.legacyPackages.${system}.buildPackage,
              }:
              pkgs.lib.makeScope pkgs.newScope (final: {
                authentikComponents = {
                  docs = final.callPackage ./components/docs.nix { };
                  frontend = final.callPackage ./components/frontend.nix { };
                  pythonEnv = final.callPackage ./components/pythonEnv.nix { };
                  # server + outposts
                  gopkgs = final.callPackage ./components/gopkgs.nix { };
                  staticWorkdirDeps = final.callPackage ./components/staticWorkdirDeps.nix { };
                  migrate = final.callPackage ./components/migrate.nix { };
                  # worker
                  manage = final.callPackage ./components/manage.nix { };
                };

                # for uv2nix
                pythonOverlay = final.callPackage ./components/python-overrides.nix { };

                inherit
                  authentik-src
                  authentik-version
                  buildNapalmPackage
                  uv2nix
                  pyproject-build-systems
                  pyproject-nix
                  python
                  ;
              });
          };
        perSystem =
          {
            pkgs,
            system,
            self',
            ...
          }:
          let
            inherit (self.lib.mkAuthentikScope { inherit pkgs; }) authentikComponents;
          in
          {
            packages = {
              inherit (authentikComponents)
                docs
                frontend
                pythonEnv
                gopkgs
                staticWorkdirDeps
                migrate
                manage
                ;

              terraform-provider-authentik = inputs.nixpkgs.legacyPackages.${system}.buildGoModule rec {
                pname = "terraform-provider-authentik";
                version = "2025.10.0";
                src = pkgs.fetchFromGitHub {
                  owner = "goauthentik";
                  repo = pname;
                  rev = "v${version}";
                  sha256 = "sha256-w5XBAeUKGui4pnDikIWuN/dWLDqKXVsQ5glZX1o1934=";
                };
                doCheck = false; # tests are run against authentik -> vm test
                vendorHash = "sha256-jy+SBlbXnr+k03fJM8eA0DLN8LFqGIBrYIq9fPmqSaw=";
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
              vmtest = (
                import tests/minimal-vmtest.nix {
                  inherit pkgs authentik-version;
                  inherit (self) nixosModules;
                }
              );
              override-scope = (
                import tests/override-scope.nix {
                  inherit pkgs authentik-version;
                  inherit (self) nixosModules;
                  inherit (self.lib) mkAuthentikScope;
                }
              );
            };
          };
      }
    );
}
