{ authentik-src
, authentik-version
, authentikComponents
, buildNapalmPackage
, nodejs_20
}:
buildNapalmPackage "${authentik-src}/web" rec {
  version = authentik-version; # 0.0.0 specified upstream in package.json
  NODE_ENV = "production";
  nodejs = nodejs_20;
  preBuild = ''
    ln -sv ${authentikComponents.docs} ../website
  '';
  npmCommands = [
    "npm install --include=dev --nodedir=${nodejs}/include/node --loglevel verbose --ignore-scripts"
    "npm run build"
  ];
  installPhase = ''
    mkdir $out
    mv dist $out/dist
    cp -r authentik icons $out
  '';
}
