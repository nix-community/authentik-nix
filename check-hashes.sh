#!/usr/bin/env bash
set -xe

fodcheck() {
  nix build "${1}" --no-link
  nix build "${1}" --rebuild --no-link
}

fodcheck .#frontend.pnpmDeps

fodcheck .#rust.cargoDeps
fodcheck .#gopkgs.goModules

fodcheck .#terraform-provider-authentik.src
fodcheck .#terraform-provider-authentik.goModules
