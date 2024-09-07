{ authentik-src
, authentik-version
, authentikComponents
, buildNapalmPackage
, nodejs_22
}:
buildNapalmPackage "${authentik-src}/web" rec {
  version = authentik-version; # 0.0.0 specified upstream in package.json
  NODE_ENV = "production";
  nodejs = nodejs_22;
  preBuild = ''
    ln -sv ${authentikComponents.docs} ../website
    ln -sv ${authentik-src}/package.json ../
  '';
  npmCommands = [
    "npm install --include=dev --nodedir=${nodejs}/include/node --loglevel verbose"
    "npm run build"
  ];
  installPhase = ''
    mkdir $out
    mv dist $out/dist
    cp -r authentik icons $out
  '';

  # upstream doesn't provide a fully resolved lock file
  # see issues:
  # - https://github.com/goauthentik/authentik/issues/6180
  # - https://github.com/goauthentik/authentik/issues/11169
  #
  # see npm issue for the underlying issue:
  # https://github.com/npm/cli/issues/4263
  packageLock = ./frontend-manually-resolved-package-lock.json;
}
