open Yap_lib

let fail message = failwith ("test: " ^ message)
let assert_true condition message = if not condition then fail message

let assert_equal_string expected actual message =
  if expected <> actual then fail (Printf.sprintf "%s (expected %S, got %S)" message expected actual)

let contains needle haystack =
  let ln = String.length needle and lh = String.length haystack in
  let rec go i = i + ln <= lh && (String.sub haystack i ln = needle || go (i + 1)) in
  ln = 0 || go 0

let rec find_root dir depth =
  if
    Sys.file_exists (Filename.concat dir "harnesses.json")
    && Sys.file_exists (Filename.concat (Filename.concat (Filename.concat dir "skills") "iiuc") "SKILL.md.j2")
  then dir
  else if depth = 0 then fail "could not locate repository root"
  else find_root (Filename.dirname dir) (depth - 1)

let write path body =
  Fs_util.mkdir_p (Filename.dirname path);
  Fs_util.write_file path body

let test_matrix_and_render root =
  let harnesses = Harness.load root in
  let pi = match Harness.find harnesses "pi" with Some harness -> harness | None -> fail "missing pi" in
  assert_true pi.tested "pi must be tested";
  assert_equal_string "/skill:iiuc" (Harness.invocation pi "iiuc") "pi invocation";
  let rendered = Core.render_all root [] in
  let get harness_id =
    rendered |> List.find (fun (harness, _) -> harness.Harness.id = harness_id) |> snd |> List.assoc "iiuc"
  in
  assert_true (String.starts_with ~prefix:"---\nname: iiuc" (get "pi")) "pi frontmatter";
  assert_true (contains "`/skill:iiuc`" (get "pi")) "pi invocation rendered";
  assert_true (contains "`/iiuc`" (get "claude")) "claude invocation rendered";
  assert_true (contains "`$iiuc`" (get "codex")) "codex invocation rendered";
  rendered
  |> List.iter (fun (_, rows) ->
      rows |> List.iter (fun (_, body) -> assert_true (not (contains "{{" body)) "unresolved variable"))

let test_lint root =
  let errors = Core.lint root |> List.filter (fun d -> d.Core.level = "error") in
  assert_true (errors = []) "repository lint must be clean"

let make_fixture () =
  let root = Filename.temp_dir "yap-test-" "" in
  write (Filename.concat root "VERSION") "0.1.0\n";
  write (Filename.concat root "harnesses.json")
    (Fs_util.read_file (Filename.concat (find_root (Sys.getcwd ()) 10) "harnesses.json"));
  write (Filename.concat root "README.md") "# fixture\n\n`demo-skill`\n";
  let repo_root = find_root (Sys.getcwd ()) 10 in
  write
    (Filename.concat (Filename.concat (Filename.concat root "templates") "skill") "SKILL.md.j2")
    (Fs_util.read_file
       (Filename.concat (Filename.concat (Filename.concat repo_root "templates") "skill") "SKILL.md.j2"));
  root

let test_scaffold () =
  let root = make_fixture () in
  let dest = Core.scaffold root "demo-skill" "Demo job in one sentence." in
  assert_true (Sys.file_exists dest) "scaffold creates source";
  let errors = Core.lint root |> List.filter (fun d -> d.Core.level = "error") in
  assert_true (List.exists (fun d -> contains "TODO" d.Core.message) errors) "scaffold TODO must fail lint";
  let duplicate_failed =
    try
      ignore (Core.scaffold root "demo-skill" "again");
      false
    with Failure _ -> true
  in
  assert_true duplicate_failed "duplicate scaffold must fail"

let test_install root =
  let target = Filename.temp_dir "yap-target-" "" in
  let written = Core.install root target "pi" false in
  let dest =
    Filename.concat (Filename.concat (Filename.concat (Filename.concat target ".pi") "skills") "iiuc") "SKILL.md"
  in
  assert_true (written = [ dest ]) "pi install writes iiuc";
  assert_true (Sys.file_exists dest) "installed file exists";
  assert_true
    (Sys.file_exists (Filename.concat (Filename.concat (Filename.concat target ".pi") "skills") "yap-skills.lock.json"))
    "lock file exists";
  ignore (Core.install root target "pi" false);
  Fs_util.write_file dest (Fs_util.read_file dest ^ "\nhand edit\n");
  let refused =
    try
      ignore (Core.install root target "pi" false);
      false
    with Failure _ -> true
  in
  assert_true refused "hand edit must be refused";
  ignore (Core.install root target "pi" true);
  assert_true (not (contains "hand edit" (Fs_util.read_file dest))) "force replaces hand edit"

let () =
  let root = find_root (Sys.getcwd ()) 10 in
  test_matrix_and_render root;
  test_lint root;
  test_scaffold ();
  test_install root;
  print_endline "test_yap: ok"
