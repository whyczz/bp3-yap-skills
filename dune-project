(lang dune 3.17)

(name bp3-yap-skills)

(version 0.1.0)

(generate_opam_files true)

(package
 (name bp3-yap-skills)
 (synopsis "Authoring toolchain for portable, human-invoked bp3 yap skills")
 (depends
  (ocaml
   (>= 5.1))
  cmdliner
  yojson))
