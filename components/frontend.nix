{
  authentik-src,
  authentik-version,
  authentikComponents,
  buildNpmPackage,
  nodejs_24,
  client-ts,
}:

buildNpmPackage {
  pname = "authentik-web";
  version = authentik-version; # 0.0.0 specified upstream in package.json

  src = "${authentik-src}/web";

  nodejs = nodejs_24;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-6JzGJuMAFndDHYm8IdUsYI8sEJ3RDO7DlVllOimdDNs=";

  env.NODE_ENV = "production";

  npmFlags = [
    "--ignore-scripts"
  ];

  preBuild = ''
    ln -sv ${authentikComponents.docs} ../website
    ln -sv ${authentik-src}/package.json ../
    npm install ${client-ts}/*.tgz
  '';

  buildPhase = ''
    runHook preBuild

    npm run build
    npm run build:sfe

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir $out
    mv dist $out/dist
    cp -r authentik icons $out    

    runHook postInstall
  '';
}
