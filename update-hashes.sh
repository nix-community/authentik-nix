#!/usr/bin/env bash

set -x

nix flake update client-ts-generator-src

nix-update --version=skip packages.x86_64-linux.frontend --flake
nix-update --version=skip packages.x86_64-linux.gopkgs --flake
nix-update --version=skip packages.x86_64-linux.rust --flake
nix-update packages.x86_64-linux.terraform-provider-authentik --flake
