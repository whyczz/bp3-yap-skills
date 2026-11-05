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
    Sys.file_exists (Filename.concat dir "dune-project")
    && Sys.file_exists (Filename.concat (Filename.concat (Filename.concat dir "templates") "skill") "SKILL.md.j2")
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
  assert_true
    (List.for_all (fun id -> (Harness.find harnesses id |> Option.get).tested) [ "codex"; "muse" ])
    "codex and muse are load-tested";
  assert_true (not (Harness.find harnesses "claude" |> Option.get).tested) "claude stays render-only until load-tested";
  assert_equal_string "/skill:iiuc" (Harness.invocation pi "iiuc") "pi invocation";
  let rendered = Core.render_all root [] in
  let get harness_id =
    rendered |> List.find (fun (harness, _) -> harness.Harness.id = harness_id) |> snd |> List.assoc "iiuc"
  in
  assert_true (String.starts_with ~prefix:"---\nname: iiuc" (get "pi")) "pi frontmatter";
  assert_true (contains "`/skill:iiuc`" (get "pi")) "pi invocation rendered";
  assert_true (contains "`/iiuc`" (get "claude")) "claude invocation rendered";
  assert_true (contains "`$iiuc`" (get "codex")) "codex invocation rendered";
  let commit_fmt = rendered |> List.find (fun (h, _) -> h.Harness.id = "claude") |> snd |> List.assoc "commit-fmt" in
  assert_true (contains "For humans" commit_fmt) "commit-fmt has a human section";
  assert_true (contains "For LLMs" commit_fmt) "commit-fmt has an LLM section";
  assert_true (contains "ELI5" commit_fmt) "commit-fmt keeps the ELI5";
  let design = rendered |> List.find (fun (h, _) -> h.Harness.id = "claude") |> snd |> List.assoc "design" in
  assert_true (contains "Data models" design) "design covers data models";
  assert_true (contains "Proposed milestones" design) "design proposes milestones";
  assert_true (contains "supersedes this document" design) "design yields to the packet once building starts";
  assert_true (contains "four red-chair passes" design) "design runs four implicit red-chair passes";
  assert_true (contains "User input" design && contains "Problem space" design) "passes cover input and problem";
  assert_true (contains "Milestones" design && contains "Red chair record" design) "passes end in a record";
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
  let written = Core.install root target "pi" Core.Project false in
  let dest =
    Filename.concat (Filename.concat (Filename.concat (Filename.concat target ".pi") "skills") "iiuc") "SKILL.md"
  in
  let prompt = Filename.concat (Filename.concat (Filename.concat target ".pi") "prompts") "iiuc.md" in
  assert_true (List.mem dest written && List.mem prompt written) "pi install writes skill and prompt template";
  assert_true (contains "/iiuc" (Fs_util.read_file prompt)) "prompt template names /iiuc";
  assert_true (contains "${ARGUMENTS:-}" (Fs_util.read_file prompt)) "prompt template forwards arguments";
  assert_true (Sys.file_exists dest) "installed file exists";
  assert_true
    (Sys.file_exists (Filename.concat (Filename.concat (Filename.concat target ".pi") "skills") "yap-skills.lock.json"))
    "lock file exists";
  ignore (Core.install root target "pi" Core.Project false);
  Fs_util.write_file dest (Fs_util.read_file dest ^ "\nhand edit\n");
  let refused =
    try
      ignore (Core.install root target "pi" Core.Project false);
      false
    with Failure _ -> true
  in
  assert_true refused "hand edit must be refused";
  ignore (Core.install root target "pi" Core.Project true);
  assert_true (not (contains "hand edit" (Fs_util.read_file dest))) "force replaces hand edit"

let test_install_global root =
  let base = Filename.temp_dir "yap-global-" "" in
  let written = Core.install root base "pi" Core.Global false in
  let dest = Filename.concat (Filename.concat (Filename.concat base "skills") "iiuc") "SKILL.md" in
  let prompt = Filename.concat (Filename.concat base "prompts") "iiuc.md" in
  assert_true (List.mem dest written && List.mem prompt written) "global pi install writes skills/ and prompts/";
  let lock = Fs_util.read_file (Filename.concat (Filename.concat base "skills") "yap-skills.lock.json") in
  assert_true (contains "\"scope\": \"global\"" lock) "global lock records scope"

let test_install_many root =
  let target = Filename.temp_dir "yap-many-" "" in
  let written = Core.install_many root [ ("pi", target); ("claude", target) ] Core.Project false in
  assert_true
    (List.exists (fun path -> contains "commit-fmt" path) written)
    "multi-harness install writes both harnesses";
  let clash_target = Filename.temp_dir "yap-clash-" "" in
  let refused =
    try
      ignore (Core.install_many root [ ("codex", clash_target); ("muse", clash_target) ] Core.Project false);
      false
    with Failure _ -> true
  in
  assert_true refused "codex and muse sharing .agents must be refused";
  assert_true
    (not (Sys.file_exists (Filename.concat clash_target ".agents")))
    "collision refusal happens before any writes"

let test_plugin root =
  let out = Filename.temp_dir "yap-plugin-" "" in
  let written = Core.write_plugin root out [] in
  let expect path = assert_true (Sys.file_exists (Filename.concat out path)) ("plugin file: " ^ path) in
  expect "claude/bp3/.claude-plugin/plugin.json";
  expect "claude/bp3/skills/iiuc/SKILL.md";
  expect "codex/bp3/.codex-plugin/plugin.json";
  expect "muse/bp3/.muse-plugin/plugin.json";
  expect "pi/bp3/package.json";
  expect "pi/bp3/prompts/iiuc.md";
  assert_true (List.length written >= 12) "plugin writes bundles for all supported harnesses";
  let claude_skill = Fs_util.read_file (Filename.concat out "claude/bp3/skills/iiuc/SKILL.md") in
  assert_true (contains "/bp3:iiuc" claude_skill) "claude plugin skill is namespaced bp3:";
  let codex_skill = Fs_util.read_file (Filename.concat out "codex/bp3/skills/iiuc/SKILL.md") in
  assert_true (contains "$bp3:iiuc" codex_skill) "codex plugin skill is namespaced bp3:";
  let muse_manifest = Fs_util.read_file (Filename.concat out "muse/bp3/.muse-plugin/plugin.json") in
  assert_true (contains "\"schemaVersion\": 1" muse_manifest) "muse manifest declares schemaVersion 1"

let test_harness_selection_is_cli_only () =
  Unix.putenv "HARNESS" "claude";
  assert_true (Cli.selected_harnesses [] = [ "pi" ]) "HARNESS env must not select harnesses";
  assert_true (Cli.selected_harnesses [ "pi,codex" ] = [ "pi"; "codex" ]) "CLI --harness list selects harnesses";
  Unix.putenv "HARNESS" ""

let () =
  let root = find_root (Sys.getcwd ()) 10 in
  test_matrix_and_render root;
  test_lint root;
  test_scaffold ();
  test_install root;
  test_install_global root;
  test_install_many root;
  test_plugin root;
  test_harness_selection_is_cli_only ();
  print_endline "test_yap: ok"
