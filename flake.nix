{
  description = "Nix package, NixOS module and VM integration test for authentik";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    # nixos-unstable required for go 1.22, until 24.05 release
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
      url = "github:goauthentik/authentik/version/2024.6.1";
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
      authentik-version = "2024.6.1"; # to pass to the drvs of some components
    in {
      systems = [
        "x86_64-linux"
        "aarch64-linux" # not tested
      ];
      flake = { self, ... }: {
        nixosModules.default = { pkgs, ... }: {
          imports = [ ./module.nix ];
          services.authentik.authentikComponents = pkgs.lib.mkDefault (withSystem pkgs.stdenv.hostPlatform.system (
            { config, ... }:
            { inherit (config.packages) manage staticWorkdirDeps migrate pythonEnv frontend gopkgs docs; }
          ));
        };

        # returns a scope which includes the attrset `authentikComponents`
        #
        # the returned scope may be overridden using its `overrideScope` function to
        # create a new scope with patched versions of individual authentik components
        #
        # see ./tests/override-scope.nix for a usage example
        lib.mkAuthentikScope = let authentik-version' = authentik-version; in {
          pkgs,
          system ? pkgs.stdenv.hostPlatform.system,
          authentik-version ? authentik-version',
          mkPoetryEnv ? (import inputs.poetry2nix { inherit pkgs; }).mkPoetryEnv,
          defaultPoetryOverrides ? (import inputs.poetry2nix { inherit pkgs; }).defaultPoetryOverrides,
          authentikPoetryOverrides ? import ./poetry2nix-python-overrides.nix pkgs,
          buildNapalmPackage ? napalm.legacyPackages.${system}.buildPackage
        }:
          import ./components {
            inherit pkgs authentik-src authentik-version mkPoetryEnv defaultPoetryOverrides authentikPoetryOverrides buildNapalmPackage;
          };
      };
      perSystem = { pkgs, system, self', ... }: let
        inherit (self.lib.mkAuthentikScope { inherit pkgs; }) authentikComponents;
      in {
        packages = {
          inherit (authentikComponents)
            docs
            frontend
            pythonEnv
            gopkgs
            staticWorkdirDeps
            migrate
            manage;

          terraform-provider-authentik = inputs.nixpkgs.legacyPackages.${system}.buildGo121Module rec {
            pname = "terraform-provider-authentik";
            version = "2024.4.1";
            src = pkgs.fetchFromGitHub {
              owner = "goauthentik";
              repo = pname;
              rev = "v${version}";
              sha256 = "sha256-+9egBupMRqAICzmw83gH9jg2nr7rBsfA3b7jRogKuPc=";
            };
            doCheck = false; # tests are run against authentik -> vm test
            vendorHash = "sha256-8MD4yy5F9svqtc/i+skCiPtiLnVN8lXW2nvIEH30n2E=";
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
        # override-scope = (import tests/override-scope.nix {
        #   inherit pkgs authentik-version;
        #   inherit (self) nixosModules;
        #   inherit (self.lib) mkAuthentikScope;
        # });
        };
      };
    });
}
