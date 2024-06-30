{ authentik-src
, authentik-version
, buildNapalmPackage
, nodejs_22
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
    rm -r ../website/node_modules/.cache
    mv -v ../website $out
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
  additionalPackageLocks =
    let
      files = builtins.readDir ./docs-extra-package-locks;
    in
    builtins.concatMap (f:
      if files.${f} == "regular"
      then [ (./docs-extra-package-locks + "/${f}") ] else []
    ) (builtins.attrNames files);
}
