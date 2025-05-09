{
  lib,
  krb5,
  libpq,
}:

let
  # Specify build system for dependencies where metadata is incomplete.
  buildSystemOverrides =
    final: prev:
    let
      buildSystemOverrides = {
        gssapi = {
          setuptools = [ ];
          cython = [ ];
        };
        django-tenants.setuptools = [ ];
        opencontainers.setuptools = [ ];
        djangorestframework.setuptools = [ ];
        psycopg-c = {
          setuptools = [ ];
          cython = [ ];
        };
      };
      inherit (final) resolveBuildSystem;
    in
    lib.mapAttrs (
      name: spec:
      prev.${name}.overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ resolveBuildSystem spec;
      })
    ) buildSystemOverrides;

  # Fixes for dependencies with C libraries.
  buildFixes = final: prev: {
    gssapi = prev.gssapi.overrideAttrs (
      {
        buildInputs ? [ ],
        ...
      }:
      {
        postPatch = ''
          substituteInPlace setup.py \
            --replace-fail 'get_output(f"{kc} gssapi --prefix")' '"${krb5.dev}"'
        '';
        buildInputs = buildInputs ++ [
          krb5
        ];
      }
    );
    psycopg-c = prev.psycopg-c.overrideAttrs (
      {
        nativeBuildInputs ? [ ],
        buildInputs ? [ ],
        ...
      }:
      {
        buildInputs = buildInputs ++ [
          libpq
        ];
        nativeBuildInputs = nativeBuildInputs ++ [
          libpq.pg_config
        ];
      }
    );
  };
in
lib.composeExtensions buildSystemOverrides buildFixes
