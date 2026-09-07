{
  runCommand,
  openapi-generator-cli,
  authentik-src,
  authentik-version,
  client-ts-generator-src,
  stdenvNoCC,
  nodejs_26,
  typescript,
  writableTmpDirAsHomeHook,
}:

let
  generatedSrc = runCommand "client-ts-generator"
    {
      nativeBuildInputs = [
        openapi-generator-cli
      ];
    } ''
    cp -r ${client-ts-generator-src}/* .

    substituteInPlace config.yaml \
      --replace-fail "templateDir: /local/templates/" "templateDir: ./templates/"
    cp -vr ${authentik-src}/schema.yml .

    # the package.json of the frontend expect the version to be 0.0.0,
    # otherwise npm tries to download it from npmjs.org
    openapi-generator-cli \
    	generate \
    	-i schema.yml \
    	-g typescript-fetch \
    	-o $out \
    	-c config.yaml \
    	--additional-properties=npmVersion=0.0.0 \
    	--additional-properties=licenseName=MIT \
    	--git-user-id goauthentik \
    	--git-repo-id client-ts
  '';
in
stdenvNoCC.mkDerivation {
  pname = "authentik-client-ts";
  version = authentik-version; # 0.0.0 specified upstream in package.json

  src = generatedSrc;

  nativeBuildInputs = [
    nodejs_26
    typescript
    writableTmpDirAsHomeHook
  ];

  buildPhase = ''
    npm run build
  '';

  installPhase = ''
    mkdir $out
    cp -rv dist package.json $out/
  '';
}
