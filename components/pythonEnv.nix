{ authentik-src
, authentikPoetryOverrides
, defaultPoetryOverrides
, lib
, mkPoetryEnv
, python312
}:

mkPoetryEnv {
  projectDir = authentik-src;
  python = python312;
  overrides = [
    defaultPoetryOverrides
  ] ++ authentikPoetryOverrides;
  groups = ["main"];
  checkGroups = [];
  # workaround to remove dev-dependencies for the current combination of legacy
  # used by authentik and poetry2nix's behavior
  pyproject = builtins.toFile "patched-pyproject.toml" (lib.replaceStrings
    ["tool.poetry.dev-dependencies"]
    ["tool.poetry.group.dev.dependencies"]
    (builtins.readFile "${authentik-src}/pyproject.toml")
  );
}
