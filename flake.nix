{
  description = "Nix package, NixOS module and VM integration test for authentik";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    # nixos-unstable required for go 1.21 until 23.11 release
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    # explicitly required for go 1.18 (terraform-provider)
    nixpkgs-23-05.url = "github:NixOS/nixpkgs/nixos-23.05";
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
      url = "github:goauthentik/authentik/version/2023.10.4";
      flake = false;
    };
  };

  outputs = inputs@{
    self,
    nixpkgs,
    nixpkgs-23-05,
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
      authentik-version = "2023.10.4"; # to pass to the drvs of some components
    in {
      systems = [
        "x86_64-linux"
        "aarch64-linux" # not tested
      ];
      flake = {
        nixosModules.default = { pkgs, ... }: {
          imports = [ ./module.nix ];
          services.authentik.authentikComponents = pkgs.lib.mkDefault (withSystem pkgs.stdenv.hostPlatform.system (
            { config, ... }:
            { inherit (config.packages) celery staticWorkdirDeps migrate pythonEnv frontend gopkgs docs; }
          ));
        };
      };
      perSystem = { pkgs, system, self', ... }: let
        inherit (import inputs.poetry2nix { inherit pkgs; })
          mkPoetryEnv
          defaultPoetryOverrides;
        authentikComponents = {
          inherit (self'.packages) celery staticWorkdirDeps migrate pythonEnv frontend gopkgs docs; };
        authentikPoetryOverrides = import ./poetry2nix-python-overrides.nix pkgs;
      in {
        packages = {
          docs = pkgs.callPackage components/docs.nix {
            buildNapalmPackage = napalm.legacyPackages.${system}.buildPackage;
            inherit authentik-src authentik-version;
          };
          frontend = pkgs.callPackage components/frontend.nix {
            buildNapalmPackage = napalm.legacyPackages.${system}.buildPackage;
            inherit authentik-src authentik-version authentikComponents;
          };
          pythonEnv = pkgs.callPackage components/pythonEnv.nix {
            inherit authentik-src mkPoetryEnv defaultPoetryOverrides authentikPoetryOverrides;
          };
          # server + outposts
          gopkgs = pkgs.callPackage components/gopkgs.nix {
            inherit authentik-src authentik-version authentikComponents;
          };
          staticWorkdirDeps = pkgs.callPackage components/staticWorkdirDeps.nix {
            inherit authentik-src authentikComponents;
          };
          migrate = pkgs.callPackage components/migrate.nix {
            inherit authentik-src authentikComponents;
          };
          # worker
          celery = pkgs.callPackage components/celery.nix {
            inherit authentikComponents;
          };
          # terraform provider
          terraform-provider-authentik = inputs.nixpkgs-23-05.legacyPackages.${system}.buildGo118Module rec {
            pname = "terraform-provider-authentik";
            version = "2023.10.0";
            src = pkgs.fetchFromGitHub {
              owner = "goauthentik";
              repo = pname;
              rev = "v${version}";
              sha256 = "sha256-eyWpssvYe3KKr2vfMRBfE4W1xrZZFeP55VmAQoitamc=";
            };
            doCheck = false; # tests are run against authentik -> vm test
            vendorSha256 = "sha256-aDExL3uFLhCqFibrepb2zVOJ7aW5CWjuqtx73w7p1qc=";
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
          vmtest = (import tests/minimal-vmtest.nix {
            inherit pkgs authentik-version;
            inherit (self) nixosModules;
          });
        };
      };
    });
}
