{
  authentik-src,
  authentik-version,
  buildNpmPackage,
  nodejs_24,
}:

buildNpmPackage {
  pname = "authentik-docs";
  version = authentik-version; # 0.0.0 specified upstream in package.json

  src = "${authentik-src}/website";

  nodejs = nodejs_24;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-oQLHdJwxvOW/fVVQn7DdSn/Ae3bdmapxWjcCl2iBLKY=";

  env.NODE_ENV = "production";

  npmFlags = [
    "--ignore-scripts"
  ];

  postPatch = ''
    cp -v ${authentik-src}/SECURITY.md ../SECURITY.md
    cp -vr ${authentik-src}/blueprints ../blueprints
    cp -v ${authentik-src}/schema.yml ../schema.yml
    mkdir -p ../lifecycle/container
    cp -v ${authentik-src}/lifecycle/container/compose.yml ../lifecycle/container/compose.yml
    rm -rf ../nodejs-axios
  '';

  npmBuildScript = "build:api";

  installPhase = ''
    runHook preInstall

    rm -f ../website/static/blueprints
    cp -vr ../blueprints ../website/static/blueprints
    cp -vr ../website $out

    runHook postInstall
  '';
}
