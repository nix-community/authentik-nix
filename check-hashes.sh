#!/usr/bin/env bash
set -xe

fodcheck() {
  nix build "${1}" --no-link
  nix build "${1}" --rebuild --no-link
}

fodcheck .#docs.pnpmDeps 
fodcheck .#frontend.pnpmDeps 

fodcheck .#rust.cargoDeps 
fodcheck .#gopkgs.goModule 

fodcheck .#terraform-provider-authentik.src
fodcheck .#terraform-provider-authentik.goModules 
