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
      "django-cte"
      "django-tenants"
      "dumb-init"
      "drf-orjson-renderer"
    ]))
  )
  (final: prev: {
      xmlsec = prev.xmlsec.overridePythonAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [ final.setuptools final.pkgconfig ];
        buildInputs = [ pkgs.xmlsec.dev pkgs.xmlsec pkgs.libxml2 pkgs.libtool ];
      });
      opencontainers = prev.opencontainers.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.setuptools
          final.pytest
        ];
        postPatch = ''
          substituteInPlace setup.py --replace-fail '"pytest-runner"' '''
        '';
      });
      psycopg-c = prev.psycopg-c.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.setuptools
          final.tomli
          pkgs.postgresql
        ];
      });
      twisted = prev.twisted.overrideAttrs (oA: {
        buildInputs = oA.buildInputs ++ [
          final.hatchling
          final.hatch-fancy-pypi-readme
        ];
      });
      #cryptography = prev.cryptography.overridePythonAttrs (oA: {
      #  cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
      #      src = oA.src;
      #      sourceRoot = "${oA.pname}-${oA.version}/src/rust";
      #      name = "${oA.pname}-${oA.version}";
      #      sha256 = "sha256-PgxPcFocEhnQyrsNtCN8YHiMptBmk1PUhEDQFdUR1nU=";
      #    };
      #});
      dnspython = prev.dnspython.overrideAttrs (oA: {
        buildInputs = oA.buildInputs ++ [
          final.hatchling
        ];
      });
      sqlparse = prev.sqlparse.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.hatchling
        ];
      });
      scim2-filter-parser = prev.scim2-filter-parser.overrideAttrs (oA: {
        patches = [
          (pkgs.fetchpatch {
            name = "replace-poetry-with-poetry-core.patch";
            url = "https://patch-diff.githubusercontent.com/raw/15five/scim2-filter-parser/pull/43.patch";
            hash = "sha256-PjJH1S5CDe/BMI0+mB34KdpNNcHfexBFYBmHolsWH4o=";
          })
        ];
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.poetry-core
        ];
      });
      pendulum = prev.pendulum.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          pkgs.rustPlatform.cargoSetupHook
          pkgs.rustPlatform.maturinBuildHook
        ];
        cargoRoot = "rust";
        cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
          src = oA.src;
          sourceRoot = "${oA.pname}-${oA.version}/rust";
          name = "${oA.pname}-${oA.version}";
          sha256 = "sha256-6fw0KgnPIMfdseWcunsGjvjVB+lJNoG3pLDqkORPJ0I=";
        };
      });
      django-pgactivity = prev.django-pgactivity.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.poetry-core
        ];
      });
      docker = prev.docker.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          prev.hatchling
          prev.hatch-vcs
        ];
      });
      django-pglock= prev.django-pglock.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.poetry-core
        ];
      });
      # https://github.com/pyradius/pyrad/pull/168/files
      # not included in the latest release :/
      pyrad = prev.pyrad.overrideAttrs (oA: {
        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace-fail "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      });
     msgraph-sdk = prev.msgraph-sdk.overrideAttrs (oA: {
       nativeBuildInputs = oA.nativeBuildInputs ++ [
         final.flit-core
       ];
     });
     python-kadmin = prev.python-kadmin.overrideAttrs (oA: {
       nativeBuildInputs = oA.nativeBuildInputs ++ [
         final.setuptools
         final.poetry-core
       ];
       buildInputs = oA.buildInputs ++ [
         pkgs.krb5
       ];
       pythonImportsCheck = [ "kadmin" ];
     });
     gssapi = prev.gssapi.overrideAttrs (oA: {
       nativeBuildInputs = oA.nativeBuildInputs ++ [
         final.setuptools
         final.cython
         pkgs.krb5 # needs krb5-config
       ];
       postPatch = ''
         substituteInPlace setup.py \
           --replace-fail 'get_output(f"{kc} gssapi --prefix")' '"${pkgs.krb5.dev}"'
       '';
       pythonImportsCheck = [ "gssapi" ];
     });
    }
  )
]
