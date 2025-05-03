{
  authentik-src,
  authentik-version,
  buildNapalmPackage,
  nodejs_22,
}:

buildNapalmPackage "${authentik-src}/website" {
  version = authentik-version; # 0.0.0 specified upstream in package.json
  NODE_ENV = "production";
  nodejs = nodejs_22;
  npmCommands = [
    "cp -v ${authentik-src}/SECURITY.md ../SECURITY.md"
    "cp -vr ${authentik-src}/blueprints ../blueprints"
    "cp -v ${authentik-src}/schema.yml ../schema.yml"
    "npm install --include=dev"
    "npm run build-bundled"
  ];
  installPhase = ''
    rm -f ../website/static/blueprints
    mv -v ../website $out
    cp -vr ../blueprints $out/static/blueprints
  '';

  # These are lockfiles with extra deps that are required to successfully build
  # the module `paloaltonetworks/postman-code-generators`, that is getting
  # pulled in by `docusaurus-theme-openapi-doc`.
  #
  # (see the repo at https://github.com/PaloAltoNetworks/postman-code-generators)
  #
  # The vendored $name-package-lock.json files here are just the package-lock or
  # npm-shrinkwrap files of each subdirectory in the `/codegens` directory of
  # the above repo at npm version "1.1.15-patch.2".
  #
  # Note that the dependency on that postman-code-generators repo is no longer
  # present on authentik's main, but unfortunately still included in the
  # 2024.6 releases.
  #
  # (╯°□°）╯︵ ┻━┻)
  #
  # ---
  # update 2024.8.0:
  #
  # The issue remains. However, now another package source  is used, namely
  # https://github.com/postmanlabs/postman-code-generators at version v1.10.1
  #
  # Note:
  # Alternatively it would be possible to drop this problematic dependency
  # entirely, as is done in nixpkgs for the authentik build:
  # https://github.com/NixOS/nixpkgs/blob/0037d6fe7143674afdfb35d1aad315605d883973/pkgs/by-name/au/authentik/package.nix#L53
  # But this would differ from the upstream build and it's unclear what the impact is:
  # https://github.com/goauthentik/authentik/blob/version/2024.8.1/Dockerfile#L20
  additionalPackageLocks =
    let
      files = builtins.readDir ./docs-extra-package-locks;
    in
    builtins.concatMap (
      f: if files.${f} == "regular" then [ (./docs-extra-package-locks + "/${f}") ] else [ ]
    ) (builtins.attrNames files);
}
