{
  lib,
  krb5,
  libpq,
  libxslt,
  libxml2,
  zlib,
  libtool,
  pkg-config,
  xmlsec,
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
        lxml = {
          setuptools = [ ];
          cython = [ ];
        };
        xmlsec.setuptools = [ ];
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
    lxml = prev.lxml.overrideAttrs (
      {
        buildInputs ? [ ],
        patches ? [ ],
        ...
      }:
      {
        buildInputs = buildInputs ++ [
          libxslt
          libxml2
          zlib
        ];
        patches = patches ++ [
          # The upstream fix for this is
          # https://github.com/lxml/lxml/commit/f7a813483c4482dd114e7ee8b42b54337e285503,
          # however, this doesn't help us here because the `etree.c` file is already generated
          # (we're using the wheel), so we have to patch the C file directly.
          ./fix-lxml-libxml-2.15-build.patch
        ];
      }
    );
    xmlsec = prev.xmlsec.overrideAttrs (
      {
        buildInputs ? [ ],
        nativeBuildInputs ? [ ],
        propagatedBuildInputs ? [ ],
        ...
      }:
      {
        buildInputs = buildInputs ++ [
          libtool
          libxslt
          libxml2
          xmlsec
        ];
        nativeBuildInputs = nativeBuildInputs ++ [
          final.pkgconfig
          pkg-config
        ];
        propagatedBuildInputs = propagatedBuildInputs ++ [ final.lxml ];
      }
    );
  };
in
lib.composeExtensions buildSystemOverrides buildFixes
