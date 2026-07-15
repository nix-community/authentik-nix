#!/usr/bin/env bash

set -x

nix-update --version=skip packages.x86_64-linux.docs --flake
nix-update --version=skip packages.x86_64-linux.frontend --flake
nix-update --version=skip packages.x86_64-linux.gopkgs --flake
nix-update --version=skip packages.x86_64-linux.rust --flake
nix-update packages.x86_64-linux.terraform-provider-authentik --flake
