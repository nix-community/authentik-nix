{
  authentik-src,
  authentikComponents,
  makeWrapper,
  runCommandLocal,
}:

runCommandLocal "authentik-manage"
  {
    nativeBuildInputs = [ makeWrapper ];
  }
  ''
    mkdir -vp $out/bin
    cp -v ${authentik-src}/manage.py $out/bin/manage.py

    wrapProgram $out/bin/manage.py \
      --prefix PATH : ${authentikComponents.pythonEnv}/bin \
      --prefix PYTHONPATH : ${authentikComponents.staticWorkdirDeps}
  ''
