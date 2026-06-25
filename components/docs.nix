{
  authentik-src,
  authentik-version,
  buildNpmPackage,
  nodejs_26,
}:

buildNpmPackage {
  pname = "authentik-docs";
  version = authentik-version; # 0.0.0 specified upstream in package.json

  src = "${authentik-src}/website";

  nodejs = nodejs_26;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-SkIZF+wQPgoZOGJc0YR8Ot07KCsAdA1985SLQaoibfA=";

  env.NODE_ENV = "production";

  npmFlags = [
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];

  postPatch = ''
    cp -v ${authentik-src}/SECURITY.md ../SECURITY.md
    cp -vr ${authentik-src}/blueprints ../blueprints
    cp -v ${authentik-src}/schema.yml ../schema.yml
    mkdir -p ../lifecycle/container
    cp -v ${authentik-src}/lifecycle/container/compose.yml ../lifecycle/container/compose.yml
  '';

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    rm -f ../website/static/blueprints
    cp -vr ../blueprints ../website/static/blueprints
    cp -vr ../website $out
    # remove broken symlinks we'd get a build failure for. Do this explicitly
    # to avoid having other broken symlinks, these are not relevant for
    # production deployments anyways.
    rm $out/node_modules/@goauthentik/{prettier-config,tsconfig,eslint-config}

    runHook postInstall
  '';
}
