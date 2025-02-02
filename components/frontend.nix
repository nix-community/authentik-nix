{
  authentik-src,
  authentik-version,
  authentikComponents,
  buildNapalmPackage,
  nodejs_22,
}:
buildNapalmPackage "${authentik-src}/web" rec {
  version = authentik-version; # 0.0.0 specified upstream in package.json
  NODE_ENV = "production";
  nodejs = nodejs_22;
  preBuild = ''
    ln -sv ${authentikComponents.docs} ../website
    ln -sv ${authentik-src}/package.json ../
  '';
  # upstream does not clearly separate development dependencies
  # from release build dependencies, therefore this workaround
  CHROMEDRIVER_SKIP_DOWNLOAD = "true";
  npmCommands = [
    "npm install --include=dev --nodedir=${nodejs}/include/node --loglevel verbose"
    "npm run build"
  ];
  installPhase = ''
    mkdir $out
    mv dist $out/dist
    cp -r authentik icons $out
  '';
}
