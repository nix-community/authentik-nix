{ fetchFromGitHub, runCommand, openapi-generator-cli, authentik-src, authentik-version, stdenv, typescript, nodejs_24 , writableTmpDirAsHomeHook}:

let
  generatorSrc = fetchFromGitHub {
    owner = "goauthentik";
    repo = "client-ts";
    rev = "5604606f8a4978e0be7a52258b154278f1f476d2";
    hash = "sha256-WpWsCuH/OTZSRYl53569WLjYImVlQnfMGczF7W428Go=";
  };
  src = runCommand "client-ts-generator"
    {
      nativeBuildInputs = [
        openapi-generator-cli
      ];
    } ''
    cp -r ${generatorSrc}/* .

    substituteInPlace config.yaml \
      --replace-fail "templateDir: /local/templates/" "templateDir: ./templates/"
    cp -vr ${authentik-src}/schema.yml .

    openapi-generator-cli \
    	generate \
    	-i schema.yml \
    	-g typescript-fetch \
    	-o $out \
    	-c config.yaml \
    	--additional-properties=packageVersion=${authentik-version} \
    	--additional-properties=licenseName=MIT \
    	--git-user-id goauthentik \
    	--git-repo-id client-ts
  '';
in
stdenv.mkDerivation {
  pname = "client-ts";
  version = authentik-version;

  inherit src;

  nativeBuildInputs = [
    nodejs_24
    typescript
    writableTmpDirAsHomeHook
  ];

  buildPhase = ''
    npm run build
  '';

  installPhase = ''
    mkdir $out
    npm pack --pack-destination $out --ignore-scripts
  '';
}
