{ authentikComponents
, makeWrapper
, runCommandLocal
}:

runCommandLocal "authentik-celery" {
  nativeBuildInputs = [ makeWrapper ];
} ''
  mkdir -vp $out/bin
  ln -sv ${authentikComponents.pythonEnv}/bin/celery $out/bin/celery
  wrapProgram $out/bin/celery \
    --prefix PYTHONPATH : ${authentikComponents.staticWorkdirDeps}
''
