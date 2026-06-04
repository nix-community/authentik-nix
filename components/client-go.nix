{
  authentik-src,
  openapi-generator-cli,
  runCommand,
}:

runCommand "go-client-code" {
  nativeBuildInputs = [
    openapi-generator-cli
  ];
} ''
  cp --no-preserve=mode -vr ${authentik-src}/packages/client-go/ $out/
  cp -vr ${authentik-src}/schema.yml $out/
  pushd $out &>/dev/null
    openapi-generator-cli generate -i schema.yml -g go -o . -c config.yaml
  popd &>/dev/null
''
