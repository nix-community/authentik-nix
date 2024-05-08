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
      "dumb-init"
      "django-tenants"
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
          final.pytest-runner final.pytest
        ];
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
      cryptography = prev.cryptography.overridePythonAttrs (oA: {
        cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
            src = oA.src;
            sourceRoot = "${oA.pname}-${oA.version}/src/rust";
            name = "${oA.pname}-${oA.version}";
            sha256 = "sha256-Pw3ftpcDMfZr/w6US5fnnyPVsFSB9+BuIKazDocYjTU=";
          };
      });
      dnspython = prev.dnspython.overrideAttrs (oA: {
        buildInputs = oA.buildInputs ++ [
          final.hatchling
        ];
      });
      sqlparse = prev.sqlparse.overrideAttrs (oA: {
        buildInputs = oA.buildInputs ++ [
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
    }
  )
]
