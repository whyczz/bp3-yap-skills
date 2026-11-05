open Cmdliner

let last_exit = ref 0
let capture term = Term.(const (fun code -> last_exit := code) $ term)

let print_error message =
  prerr_endline ("yap: " ^ message);
  2

let split_harness_list values =
  values |> List.concat_map (String.split_on_char ',') |> List.map String.trim |> List.filter (fun value -> value <> "")

let selected_harnesses flags =
  let from_flags = split_harness_list flags in
  if from_flags <> [] then from_flags else [ "pi" ]

let harness_arg =
  Arg.(
    value & opt_all string []
    & info [ "harness" ] ~docv:"IDS"
        ~doc:"Harness ids, comma-separated or repeated. Falls back to $HARNESS (also comma-separated), then pi.")

let root_term =
  Arg.(value & opt string "." & info [ "root" ] ~docv:"DIR" ~doc:"Repository root. Defaults to the current directory.")

let json_term = Arg.(value & flag & info [ "json" ] ~doc:"Machine-readable output.")

let run_check root json =
  try
    let diagnostics = Core.lint root in
    let errors = diagnostics |> List.filter (fun d -> d.Core.level = "error") in
    if json then
      `List
        (diagnostics
        |> List.map (fun d -> `Assoc [ ("level", `String d.Core.level); ("message", `String d.Core.message) ]))
      |> Yojson.Safe.to_string |> print_endline
    else (
      diagnostics |> List.iter (fun d -> Printf.printf "%s: %s\n" d.Core.level d.Core.message);
      if errors = [] then print_endline "yap check: ok"
      else Printf.printf "yap check: %d error(s)\n" (List.length errors));
    if errors = [] then 0 else 1
  with
  | Failure message -> print_error message
  | Sys_error message -> print_error message

let check_cmd =
  Cmd.v
    (Cmd.info "check" ~doc:"Lint sources and render every harness.")
    (capture Term.(const run_check $ root_term $ json_term))

let run_render root json harness_flags all out =
  try
    let harness_ids = if all then [] else selected_harnesses harness_flags in
    let out_dir = Option.value out ~default:(Filename.concat root "generated") in
    let written = Core.write_rendered root out_dir harness_ids in
    if json then `List (written |> List.map (fun path -> `String path)) |> Yojson.Safe.to_string |> print_endline
    else written |> List.iter print_endline;
    0
  with
  | Failure message -> print_error message
  | Sys_error message -> print_error message

let render_cmd =
  let harness = harness_arg in
  let all = Arg.(value & flag & info [ "all" ] ~doc:"Render every harness, ignoring --harness.") in
  let out =
    Arg.(value & opt (some string) None & info [ "out" ] ~docv:"DIR" ~doc:"Output root. Defaults to generated/.")
  in
  Cmd.v
    (Cmd.info "render" ~doc:"Render skills for one or all harnesses.")
    (capture Term.(const run_render $ root_term $ json_term $ harness $ all $ out))

let run_plugin root json harness_flags out =
  try
    let harness_ids = selected_harnesses harness_flags in
    let out_dir = Option.value out ~default:(Filename.concat root "generated/plugin") in
    let written = Core.write_plugin root out_dir harness_ids in
    if json then `List (written |> List.map (fun path -> `String path)) |> Yojson.Safe.to_string |> print_endline
    else written |> List.iter print_endline;
    0
  with
  | Failure message -> print_error message
  | Sys_error message -> print_error message

let plugin_cmd =
  let harness = harness_arg in
  let out =
    Arg.(value & opt (some string) None & info [ "out" ] ~docv:"DIR" ~doc:"Output root. Defaults to generated/plugin/.")
  in
  Cmd.v
    (Cmd.info "plugin" ~doc:"Render plugin or package bundles (bp3) for selected harnesses.")
    (capture Term.(const run_plugin $ root_term $ json_term $ harness $ out))

let default_global_base harness_id =
  let home = match Sys.getenv_opt "HOME" with Some home -> home | None -> failwith "HOME is not set" in
  match harness_id with
  | "pi" -> (
      match Sys.getenv_opt "PI_CODING_AGENT_DIR" with
      | Some dir -> dir
      | None -> Filename.concat (Filename.concat home ".pi") "agent")
  | "claude" -> Filename.concat home ".claude"
  | "codex" -> Filename.concat home ".agents"
  | "muse" ->
      let config_home =
        match Sys.getenv_opt "XDG_CONFIG_HOME" with Some dir -> dir | None -> Filename.concat home ".config"
      in
      Filename.concat config_home "muse"
  | other -> failwith ("unknown harness: " ^ other)

let run_install root json harness_flags target project global force =
  try
    let harness_ids = selected_harnesses harness_flags in
    let scope, installs =
      match (project, global, target) with
      | true, false, Some target -> (Core.Project, harness_ids |> List.map (fun id -> (id, target)))
      | true, false, None -> failwith "install -p needs --target DIR (the project directory)"
      | false, true, Some base when List.length harness_ids = 1 ->
          (Core.Global, harness_ids |> List.map (fun id -> (id, base)))
      | false, true, Some _ ->
          failwith
            "install -g --target names one harness global base; pass it with exactly one --harness (or drop --target \
             for per-harness defaults)"
      | false, true, None -> (Core.Global, harness_ids |> List.map (fun id -> (id, default_global_base id)))
      | false, false, _ -> failwith "choose exactly one install scope: -p/--project or -g/--global"
      | true, true, _ -> failwith "install scopes are mutually exclusive: choose -p/--project or -g/--global"
    in
    let written = Core.install_many root installs scope force in
    if json then `List (written |> List.map (fun path -> `String path)) |> Yojson.Safe.to_string |> print_endline
    else written |> List.iter print_endline;
    0
  with
  | Failure message -> print_error message
  | Sys_error message -> print_error message
  | Invalid_argument message -> print_error message

let install_cmd =
  let harness = harness_arg in
  let target =
    Arg.(
      value
      & opt (some string) None
      & info [ "target" ] ~docv:"DIR"
          ~doc:
            "With -p: the project directory. With -g: the harness global base (defaults: pi ~/.pi/agent, claude \
             ~/.claude, codex ~/.agents, muse ~/.config/muse).")
  in
  let project = Arg.(value & flag & info [ "p"; "project" ] ~doc:"Install per project (explicit project scope).") in
  let global = Arg.(value & flag & info [ "g"; "global" ] ~doc:"Install globally for this harness and user.") in
  let force = Arg.(value & flag & info [ "force" ] ~doc:"Replace hand-edited installed files.") in
  Cmd.v
    (Cmd.info "install" ~doc:"Install rendered .md skills. Choose exactly one scope: -p/--project or -g/--global.")
    (capture Term.(const run_install $ root_term $ json_term $ harness $ target $ project $ global $ force))

let run_new root skill_id description =
  try
    print_endline (Core.scaffold root skill_id description);
    0
  with
  | Failure message -> print_error message
  | Sys_error message -> print_error message
  | Invalid_argument message -> print_error message

let new_cmd =
  let skill_id = Arg.(required & pos 0 (some string) None & info [] ~docv:"SKILL" ~doc:"New skill id.") in
  let description =
    Arg.(value & opt string "" & info [ "description" ] ~docv:"TEXT" ~doc:"One-sentence job for the new skill.")
  in
  Cmd.v
    (Cmd.info "new" ~doc:"Scaffold a new skill source. Scaffolding is not approval.")
    (capture Term.(const run_new $ root_term $ skill_id $ description))

let run_list root json =
  try
    let skills = Core.skill_sources root |> List.map Core.skill_id_of_source in
    let harnesses = Harness.load root in
    if json then
      let harness_json =
        `Assoc
          (harnesses
          |> List.map (fun harness ->
              ( harness.Harness.id,
                `Assoc
                  [
                    ("display", `String harness.Harness.display);
                    ("skills_dir", `String harness.Harness.skills_dir);
                    ("invocation", `String (Harness.invocation harness "<skill>"));
                    ("tested", `Bool harness.Harness.tested);
                  ] )))
      in
      `Assoc [ ("skills", `List (skills |> List.map (fun id -> `String id))); ("harnesses", harness_json) ]
      |> Yojson.Safe.pretty_to_string |> print_endline
    else (
      Printf.printf "skills: %s\n" (String.concat ", " skills);
      harnesses
      |> List.iter (fun harness ->
          Printf.printf "%s: %s (%s)\n" harness.Harness.id harness.Harness.skills_dir
            (if harness.Harness.tested then "tested" else "render-only")));
    0
  with
  | Failure message -> print_error message
  | Sys_error message -> print_error message

let list_cmd =
  Cmd.v
    (Cmd.info "list" ~doc:"List implemented skills and harnesses.")
    (capture Term.(const run_list $ root_term $ json_term))

let main () =
  let info =
    Cmd.info "yap" ~version:"0.1.0" ~doc:"bp3 yap skills toolchain."
      ~man:[ `S "DESCRIPTION"; `P "Author, render, lint, and install portable yap skills." ]
  in
  ignore (Cmd.eval (Cmd.group info [ check_cmd; render_cmd; plugin_cmd; install_cmd; new_cmd; list_cmd ]));
  exit !last_exit
