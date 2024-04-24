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
          final.cython-3
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
            sha256 = "sha256-qaXQiF1xZvv4sNIiR2cb5TfD7oNiYdvUwcm37nh2P2M=";
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
      # alias because lxml references cython_3 in nativeBuildInputs
      cython_3 = final.cython-3;
      #pyyaml = pkgs.python312.pkgs.pyyaml;
      pyyaml = prev.pyyaml.overrideAttrs (oA:
      let
        # checks if derivation is cython with major version 3
        isNotCython3 = drv:
          let
            drvInfo = builtins.parseDrvName drv.name;
            isCython = pkgs.lib.hasSuffix "-cython" drvInfo.name;
            isVersion3 = pkgs.lib.versions.major drvInfo.version == "3";
          in
          isCython -> !isVersion3;

        # removes cython3 derivation from list
        removeCython3 = builtins.filter isNotCython3;
      in
      {
        # pyyaml 6.0.1 doesn't build with cython3, see upstream nixpkgs
        nativeBuildInputs = (removeCython3 oA.nativeBuildInputs) ++ [
          pkgs.python312Packages.cython_0
          final.setuptools
        ];
        buildInputs = oA.buildInputs ++ [
          pkgs.libyaml
        ];
      });
    }
  )
]
