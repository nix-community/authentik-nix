{
  authentik-src,
  authentik-version,
  authentikComponents,
  buildNapalmPackage,
  nodejs_24,
}:
buildNapalmPackage "${authentik-src}/web" rec {
  version = authentik-version; # 0.0.0 specified upstream in package.json
  NODE_ENV = "production";
  nodejs = nodejs_24;
  preBuild = ''
    ln -sv ${authentikComponents.docs} ../website
    ln -sv ${authentik-src}/package.json ../
  '';
  # upstream does not clearly separate development dependencies
  # from release build dependencies, therefore this workaround
  CHROMEDRIVER_SKIP_DOWNLOAD = "true";
  npmCommands = [
    "npm install --include=dev --nodedir=${nodejs}/include/node --loglevel verbose --ignore-scripts"
    "npm run build"
    "npm run build:sfe"
  ];
  installPhase = ''
    mkdir $out
    mv dist $out/dist
    cp -r authentik icons $out
  '';
}
