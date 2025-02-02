{
  authentik-src,
  authentikComponents,
  makeWrapper,
  runCommandLocal,
}:

runCommandLocal "authentik-migrate.py"
  {
    nativeBuildInputs = [ makeWrapper ];
  }
  ''
    mkdir -vp $out/bin
    cp ${authentik-src}/lifecycle/migrate.py $out/bin/migrate.py
    chmod +w $out/bin/migrate.py
    patchShebangs $out/bin/migrate.py
    substituteInPlace $out/bin/migrate.py \
      --replace \
      'migration_path in Path(__file__).parent.absolute().glob("system_migrations/*.py")' \
      'migration_path in Path("${authentikComponents.staticWorkdirDeps}/lifecycle").glob("system_migrations/*.py")'
    wrapProgram $out/bin/migrate.py \
      --prefix PATH : ${authentikComponents.pythonEnv}/bin \
      --prefix PYTHONPATH : ${authentikComponents.staticWorkdirDeps}
  ''
