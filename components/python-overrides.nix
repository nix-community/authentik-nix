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
  python,
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
    django-tenants = prev.django-tenants.overrideAttrs {
      /*
        Resolves

         > FileCollisionError: Two or more packages are trying to provide the same file with different contents
         >
         >         Files: /nix/store/snsw4gij9l7pllphdskxqmr3y5a951aq-django-tenants-3.10.0/lib/python3.14/site-packages/docs/Makefile /nix/store/dxy56wp46sm8nqjfhmfswb5k5rcwrj6y-pyrad-2.5.4/lib/python3.14/site-packages/docs/Makefile
      */
      postFixup = ''
        rm -r $out/${python.sitePackages}/docs
      '';
    };
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
        ...
      }:
      {
        buildInputs = buildInputs ++ [
          libxslt
          libxml2
          zlib
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
