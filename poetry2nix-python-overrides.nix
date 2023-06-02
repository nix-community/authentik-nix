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
      "asgiref"
      "bump2version"
      "codespell"
      "colorama"
      "dumb-init"
      "opencontainers"
      "pytest-github-actions-annotate-failures"
      "drf-jsonschema-serializer"
    ]))
  )
  (final: prev: {
      ruff = null; # don't need a linter for the package %), groups = [] && checkGroups = [] doesn't seem to work
      pydantic-scim = prev.pydantic-scim.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.setuptools-scm
        ];
      });
      asyncio = prev.asyncio.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.setuptools final.setuptools-scm
        ];
      });
      click-didyoumean = prev.click-didyoumean.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.poetry
          final.setuptools
        ];
      });
      pyrad = prev.pyrad.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.poetry
        ];
      });
      kombu = prev.kombu.overrideAttrs (oA: rec {
        version = "5.3.0b3"; # 5.2.4 broken build from source
        src = final.fetchPypi {
          inherit version;
          pname = "kombu";
          sha256 = "316df5e840f284d0671b9000bbf747da2b00f3b81433c720de66a5f659e5711d";
        };
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.setuptools
        ];
      });
      urllib3-secure-extra = prev.urllib3-secure-extra.overrideAttrs (oA: {
        buildInputs = [ final.flit-core ];
      });
      django-otp = prev.django-otp.overrideAttrs (oA: {
        buildInputs = [ final.hatchling ];
      });
      tenacity = prev.tenacity.overrideAttrs (oA: rec {
          buildInputs = [ final.pbr final.setuptools final.setuptools-scm ];
          propagatedBuildInputs = [ final.pbr ];
      });
      opencontainers = prev.opencontainers.overrideAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [
          final.pytest-runner final.pytest
        ];
      });
      lxml = prev.lxml.overrideAttrs (oA: {
        buildInputs = [ pkgs.xmlsec ];
      });
      xmlsec = prev.xmlsec.overridePythonAttrs (oA: {
        nativeBuildInputs = oA.nativeBuildInputs ++ [ final.setuptools final.pkgconfig ];
        buildInputs = [ pkgs.xmlsec.dev pkgs.xmlsec pkgs.libxml2 pkgs.libtool ];
      });
      cryptography = prev.cryptography.overridePythonAttrs (oA: {
        cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
            src = oA.src;
            sourceRoot = "${oA.pname}-${oA.version}/src/rust";
            name = "${oA.pname}-${oA.version}";
            sha256 = "sha256-0x+KIqJznDEyIUqVuYfIESKmHBWfzirPeX2R/cWlngc=";
          };
      });
      #mistune = prev.mistune.override (oA: rec {
      #  version = "0.8.4";
      #  src = final.fetchPypi {
      #    inherit version;
      #    pname = "mistune";
      #    sha256 = "59a3429db53c50b5c6bcc8a07f8848cb00d7dc8bdb431a4ab41920d201d4756e";
      #  };
      #  buildInputs = [ final.nose ];
      #  #meta.knownVulnerabilities = [ "CVE-2022-34749" ];
      #});
      #twilio = prev.twilio.overrideAttrs (oA: rec {
      #    version = "8.1.0"; # unnecessary dependency on asyncio breaks build
      #    src = final.fetchPypi {
      #      inherit version;
      #      pname = "twilio";
      #      sha256 = "a31863119655cd3643f788099f6ea3fe74eea59ce3f65600f9a4931301311c08";
      #    };
      #    propagatedBuildInputs = [
      #        final.tenacity
      #        final.pytz
      #        final.requests
      #        final.pyjwt
      #        final.aiohttp
      #        final.aiohttp-retry
      #    ];
      #});
    }
  )
]
