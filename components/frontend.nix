{
  authentik-src,
  authentik-version,
  authentikComponents,
  buildNpmPackage,
  nodejs_26,
}:

buildNpmPackage {
  pname = "authentik-web";
  version = authentik-version; # 0.0.0 specified upstream in package.json

  src = "${authentik-src}/web";

  nodejs = nodejs_26;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-R+z1eUBGI2r6huBXjYBuT0DO27AmapvdEemG8STmnlM=";

  env.NODE_ENV = "production";

  npmFlags = [
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];

  postPatch = ''
    rm packages/client-ts
    cp -rv --no-preserve=mode ${authentikComponents.client-ts} packages/client-ts
  '';

  preBuild = ''
    cp -rv --no-preserve=mode ${authentik-src}/packages ../
    ln -sv ${authentikComponents.docs} ../website
    ln -sv ${authentik-src}/package.json ../
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
