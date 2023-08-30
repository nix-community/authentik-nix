pkgs:
[
  # modules missing only setuptools
  (final: prev:
    (builtins.listToAttrs (map (name: {
      inherit name;
      value = prev.${name}.overrideAttrs (oA: {
        nativeBuildInputs = (oA.nativeBuildInputs or []) ++ [ final.setuptools ];
      });
    }) [
      "bump2version"
      "dumb-init"
      "opencontainers"
      "pytest-github-actions-annotate-failures"
      "drf-jsonschema-serializer"
      "pydantic-scim"
    ]))
  )
  (final: prev: {
      ruff = null; # don't need a linter for the package %), groups = [] && checkGroups = [] doesn't seem to work
      django-otp = prev.django-otp.overrideAttrs (oA: {
        buildInputs = [ final.hatchling ];
      });
      service-identity = prev.service-identity.overrideAttrs (oA: {
        buildInputs = [
          final.hatchling
          final.hatch-fancy-pypi-readme
          final.hatch-vcs
        ];
      });
      pyrad = prev.pyrad.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.poetry
        ];
      });
      xmlsec = prev.xmlsec.overridePythonAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [ final.setuptools final.pkgconfig ];
        buildInputs = [ pkgs.xmlsec.dev pkgs.xmlsec pkgs.libxml2 pkgs.libtool ];
      });
      opencontainers = prev.opencontainers.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.pytest-runner final.pytest
        ];
      });
      urllib3-secure-extra = prev.urllib3-secure-extra.overrideAttrs (oA: {
        buildInputs = [ final.flit-core ];
      });
      pydantic-scim = prev.pydantic-scim.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.setuptools-scm
        ];
      });
      psycopg-c = prev.psycopg-c.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.setuptools
          final.tomli
          final.cython_3
          pkgs.postgresql
        ];
      });
      psycopg = prev.psycopg.overrideAttrs (oA: {
        propagatedBuildInputs = oA.propagatedBuildInputs ++ [
          final.psycopg-c
        ];
        pythonImportsCheck = [
          "psycopg"
          "psycopg_c"
        ];
      });
      twisted = prev.twisted.overrideAttrs (oA: {
        buildInputs = [
          final.hatchling
          final.hatch-fancy-pypi-readme
        ];
      });
    }
  )
]
