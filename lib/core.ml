type diagnostic = { level : string; message : string }
type scope = Project | Global

let scope_name = function Project -> "project" | Global -> "global"
let max_skill_lines = 500
let conditional_warn = 4

let valid_skill_id id =
  let valid_char c = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c = '-' || c = '_' in
  String.length id > 0
  && id.[0] >= 'a'
  && id.[0] <= 'z'
  && String.for_all valid_char id
  && not
       (List.mem id
          [
            "con";
            "prn";
            "aux";
            "nul";
            "com1";
            "com2";
            "com3";
            "com4";
            "com5";
            "com6";
            "com7";
            "com8";
            "com9";
            "lpt1";
            "lpt2";
            "lpt3";
            "lpt4";
            "lpt5";
            "lpt6";
            "lpt7";
            "lpt8";
            "lpt9";
          ])

let version root = Fs_util.read_file (Fs_util.join root "VERSION") |> String.trim

let skill_sources root =
  let skills_dir = Fs_util.join root "skills" in
  Fs_util.list_dir skills_dir
  |> List.filter_map (fun name ->
      let source = Fs_util.join (Fs_util.join skills_dir name) "SKILL.md.j2" in
      if Sys.file_exists source then Some source else None)

let skill_id_of_source source = Filename.dirname source |> Filename.basename

let context_with_invocation root harness skill_id invocation =
  [
    ("skill_id", skill_id);
    ("version", version root);
    ("invocation", invocation);
    ("harness.id", harness.Harness.id);
    ("harness.display", harness.Harness.display);
  ]

let context root harness skill_id = context_with_invocation root harness skill_id (Harness.invocation harness skill_id)

let render_source root harness source =
  let input = Fs_util.read_file source in
  Template.render ~context:(context root harness (skill_id_of_source source)) input

let render_source_with_invocation root harness source invocation =
  let input = Fs_util.read_file source in
  Template.render ~context:(context_with_invocation root harness (skill_id_of_source source) invocation) input

let render_all root harness_ids =
  let harnesses = Harness.load root in
  let selected =
    match harness_ids with
    | [] -> harnesses
    | ids ->
        ids
        |> List.map (fun id ->
            match Harness.find harnesses id with Some harness -> harness | None -> failwith ("unknown harness: " ^ id))
  in
  selected
  |> List.map (fun harness ->
      let rendered =
        skill_sources root
        |> List.map (fun source ->
            match render_source root harness source with
            | Ok body -> (skill_id_of_source source, body)
            | Error message -> failwith (skill_id_of_source source ^ ": " ^ message))
      in
      (harness, rendered))

let plugin_name = "bp3"
let plugin_description = "bp3 yap skills: human-invoked design skills for coding agents."

let render_plugin_source root harness source =
  render_source_with_invocation root harness source (Harness.plugin_invocation harness (skill_id_of_source source))

let split_frontmatter body =
  let lines = String.split_on_char '\n' body in
  match lines with
  | "---" :: rest ->
      let rec take acc = function
        | [] -> None
        | "---" :: tail -> Some (List.rev acc, tail)
        | line :: tail -> take (line :: acc) tail
      in
      take [] rest
      |> Option.map (fun (field_lines, body_lines) ->
          let fields =
            field_lines
            |> List.filter_map (fun line ->
                match String.index_opt line ':' with
                | Some index ->
                    Some
                      ( String.trim (String.sub line 0 index),
                        String.trim (String.sub line (index + 1) (String.length line - index - 1)) )
                | None -> None)
          in
          (fields, String.concat "\n" body_lines))
  | _ -> None

let render_prompt_source root harness source =
  match Harness.command_invocation harness (skill_id_of_source source) with
  | None -> None
  | Some invocation -> (
      match render_source_with_invocation root harness source invocation with
      | Error _ -> None
      | Ok body -> (
          match split_frontmatter body with
          | None -> None
          | Some (fields, rest) ->
              let description = Option.value (List.assoc_opt "description" fields) ~default:"" in
              Some
                (Printf.sprintf
                   "---\ndescription: %s\nargument-hint: \"[request]\"\n---\n%s\n\nUser request: ${ARGUMENTS:-}\n"
                   description (String.trim rest))))

let write_rendered root out_dir harness_ids =
  render_all root harness_ids
  |> List.concat_map (fun (harness, rendered) ->
      let skill_files =
        rendered
        |> List.map (fun (skill_id, body) ->
            let dest =
              Fs_util.join
                (Fs_util.join
                   (Fs_util.join (Fs_util.join out_dir harness.Harness.id) harness.Harness.skills_dir)
                   skill_id)
                "SKILL.md"
            in
            Fs_util.mkdir_p (Filename.dirname dest);
            Fs_util.write_file dest body;
            dest)
      in
      let prompt_files =
        match harness.Harness.prompts_dir with
        | None -> []
        | Some prompts_dir ->
            skill_sources root
            |> List.filter_map (fun source ->
                match render_prompt_source root harness source with
                | Some body ->
                    let dest =
                      Fs_util.join
                        (Fs_util.join (Fs_util.join out_dir harness.Harness.id) prompts_dir)
                        (skill_id_of_source source ^ ".md")
                    in
                    Fs_util.mkdir_p (Filename.dirname dest);
                    Fs_util.write_file dest body;
                    Some dest
                | None -> None)
      in
      skill_files @ prompt_files)

let plugin_manifest root harness skill_ids =
  let ver = version root in
  match harness.Harness.id with
  | "claude" ->
      `Assoc
        [
          ("name", `String plugin_name);
          ("version", `String ver);
          ("description", `String plugin_description);
          ("author", `Assoc [ ("name", `String "whyczz") ]);
        ]
  | "codex" ->
      `Assoc
        [
          ("name", `String plugin_name);
          ("version", `String ver);
          ("description", `String plugin_description);
          ("skills", `String "./skills/");
          ( "interface",
            `Assoc
              [
                ("displayName", `String "bp3 yap skills");
                ("shortDescription", `String "Human-invoked design skills");
                ("longDescription", `String "Portable yap skills for sync, design, and review.");
                ("developerName", `String "whyczz");
                ("category", `String "Productivity");
                ("capabilities", `List [ `String "Interactive"; `String "Read" ]);
              ] );
        ]
  | "muse" ->
      `Assoc
        [
          ("name", `String plugin_name);
          ("version", `String ver);
          ("description", `String plugin_description);
          ("schemaVersion", `Int 1);
          ("compat", `Assoc [ ("manifestDir", `String ".muse-plugin") ]);
          ( "capabilities",
            `Assoc
              [
                ( "skills",
                  `List
                    (skill_ids
                    |> List.map (fun id ->
                        `Assoc [ ("id", `String id); ("path", `String ("./skills/" ^ id ^ "/SKILL.md")) ])) );
              ] );
        ]
  | "pi" ->
      `Assoc
        [
          ("name", `String "bp3-yap-skills");
          ("version", `String ver);
          ("description", `String plugin_description);
          ("keywords", `List [ `String "pi-package" ]);
          ("pi", `Assoc [ ("skills", `List [ `String "./skills" ]); ("prompts", `List [ `String "./prompts/*.md" ]) ]);
        ]
  | other -> failwith ("no plugin bundle for harness: " ^ other)

let write_plugin root out_dir harness_ids =
  let harnesses = Harness.load root in
  let selected =
    match harness_ids with
    | [] -> harnesses
    | ids ->
        ids
        |> List.map (fun id ->
            match Harness.find harnesses id with Some harness -> harness | None -> failwith ("unknown harness: " ^ id))
  in
  selected
  |> List.concat_map (fun harness ->
      let base = Fs_util.join (Fs_util.join out_dir harness.Harness.id) plugin_name in
      let sources = skill_sources root in
      let skill_ids = sources |> List.map skill_id_of_source in
      let skill_files =
        sources
        |> List.map (fun source ->
            let skill_id = skill_id_of_source source in
            match render_plugin_source root harness source with
            | Error message -> failwith (skill_id ^ ": " ^ message)
            | Ok body ->
                let dest = Fs_util.join (Fs_util.join (Fs_util.join base "skills") skill_id) "SKILL.md" in
                Fs_util.mkdir_p (Filename.dirname dest);
                Fs_util.write_file dest body;
                dest)
      in
      let prompt_files =
        match harness.Harness.prompts_dir with
        | None -> []
        | Some _ ->
            sources
            |> List.filter_map (fun source ->
                match render_prompt_source root harness source with
                | None -> None
                | Some body ->
                    let dest = Fs_util.join (Fs_util.join base "prompts") (skill_id_of_source source ^ ".md") in
                    Fs_util.mkdir_p (Filename.dirname dest);
                    Fs_util.write_file dest body;
                    Some dest)
      in
      let manifest_path =
        match harness.Harness.plugin_manifest_dir with
        | Some manifest_dir -> Fs_util.join (Fs_util.join base manifest_dir) "plugin.json"
        | None -> Fs_util.join base "package.json"
      in
      Fs_util.mkdir_p (Filename.dirname manifest_path);
      Fs_util.write_file manifest_path (Yojson.Safe.pretty_to_string (plugin_manifest root harness skill_ids) ^ "\n");
      let readme_path = Fs_util.join base "README.md" in
      let readme =
        Printf.sprintf
          "# bp3 yap skills (%s)\n\n\
           %s\n\n\
           Skills: %s. Generated by `yap plugin`; do not hand-edit. Invoke through this harness's plugin or package \
           mechanism; on Claude and Codex, skills are namespaced as bp3:<skill>.\n"
          harness.Harness.display plugin_description (String.concat ", " skill_ids)
      in
      Fs_util.write_file readme_path readme;
      skill_files @ prompt_files @ [ manifest_path; readme_path ])

let parse_frontmatter body =
  let lines = String.split_on_char '\n' body in
  match lines with
  | "---" :: rest ->
      let rec take acc = function
        | [] -> None
        | "---" :: _ -> Some (List.rev acc)
        | line :: tail -> take (line :: acc) tail
      in
      take [] rest
      |> Option.map (fun field_lines ->
          field_lines
          |> List.filter_map (fun line ->
              match String.index_opt line ':' with
              | Some index ->
                  Some
                    ( String.trim (String.sub line 0 index),
                      String.trim (String.sub line (index + 1) (String.length line - index - 1)) )
              | None -> None))
  | _ -> None

let contains substring text =
  let ls = String.length substring and lt = String.length text in
  let rec go i = if i + ls > lt then false else if String.sub text i ls = substring then true else go (i + 1) in
  ls = 0 || go 0

let lint root =
  let diagnostics = ref [] in
  let add level message = diagnostics := { level; message } :: !diagnostics in
  let sources = skill_sources root in
  if sources = [] then add "error" "no skills found under skills/";
  let readme = try Fs_util.read_file (Fs_util.join root "README.md") with _ -> "" in
  let harnesses = Harness.load root in
  sources
  |> List.iter (fun source ->
      let skill_id = skill_id_of_source source in
      if not (valid_skill_id skill_id) then add "error" ("invalid skill id: " ^ skill_id);
      let entries = Fs_util.list_dir (Filename.dirname source) in
      if entries <> [ "SKILL.md.j2" ] then
        add "error" (Printf.sprintf "%s: expected only SKILL.md.j2, found %s" skill_id (String.concat ", " entries));
      let text = Fs_util.read_file source in
      if contains "TODO:" text then add "error" (skill_id ^ ": TODO scaffold text remains");
      if List.length (String.split_on_char '\n' text) > max_skill_lines then
        add "error" (Printf.sprintf "%s: over %d lines" skill_id max_skill_lines);
      let conditionals = Template.count_conditionals text in
      if conditionals > conditional_warn then
        add "warning" (Printf.sprintf "%s: %d harness conditionals; each needs a named test" skill_id conditionals);
      if not (contains ("`" ^ skill_id ^ "`") readme) then add "error" (skill_id ^ ": missing from README roster");
      harnesses
      |> List.iter (fun harness ->
          match render_source root harness source with
          | Error message ->
              add "error" (Printf.sprintf "%s [%s]: render failed: %s" skill_id harness.Harness.id message)
          | Ok body -> (
              if contains "{{" body || contains "{%" body then
                add "error" (Printf.sprintf "%s [%s]: unresolved template markers" skill_id harness.Harness.id);
              match parse_frontmatter body with
              | None -> add "error" (Printf.sprintf "%s [%s]: missing frontmatter" skill_id harness.Harness.id)
              | Some fields ->
                  if List.assoc_opt "name" fields <> Some skill_id then
                    add "error"
                      (Printf.sprintf "%s [%s]: frontmatter name is %s" skill_id harness.Harness.id
                         (Option.value (List.assoc_opt "name" fields) ~default:"<missing>"));
                  if Option.value (List.assoc_opt "description" fields) ~default:"" = "" then
                    add "error" (Printf.sprintf "%s [%s]: empty description" skill_id harness.Harness.id))));
  List.rev !diagnostics

let scaffold root skill_id description =
  if not (valid_skill_id skill_id) then invalid_arg ("invalid skill id: " ^ skill_id);
  let dest_dir = Fs_util.join (Fs_util.join root "skills") skill_id in
  if Sys.file_exists dest_dir then failwith ("skill already exists: " ^ skill_id);
  let template_path = Fs_util.join (Fs_util.join (Fs_util.join root "templates") "skill") "SKILL.md.j2" in
  let template = Fs_util.read_file template_path in
  let replace_all needle replacement text =
    let buffer = Buffer.create (String.length text) in
    let ln = String.length needle in
    let rec go i =
      if i + ln <= String.length text && String.sub text i ln = needle then (
        Buffer.add_string buffer replacement;
        go (i + ln))
      else if i < String.length text then (
        Buffer.add_char buffer text.[i];
        go (i + 1))
    in
    go 0;
    Buffer.contents buffer
  in
  let body = replace_all "{{ skill_id }}" skill_id template in
  let body =
    if description = "" then body
    else replace_all "TODO: one sentence stating the job this skill does." description body
  in
  Fs_util.mkdir_p dest_dir;
  let dest = Fs_util.join dest_dir "SKILL.md.j2" in
  Fs_util.write_file dest body;
  dest

let install_roots target harness scope =
  match scope with
  | Project ->
      (Fs_util.join target harness.Harness.skills_dir, Option.map (Fs_util.join target) harness.Harness.prompts_dir)
  | Global ->
      ( Fs_util.join target harness.Harness.global_skills_dir,
        Option.map (Fs_util.join target) harness.Harness.global_prompts_dir )

let install root target harness_id scope force =
  let harnesses = Harness.load root in
  let harness =
    match Harness.find harnesses harness_id with
    | Some harness -> harness
    | None -> failwith ("unknown harness: " ^ harness_id)
  in
  let rendered = match render_all root [ harness_id ] with [ (_, rows) ] -> rows | _ -> [] in
  let skills_root, prompts_root = install_roots target harness scope in
  let lock_path = Fs_util.join skills_root "yap-skills.lock.json" in
  let recorded = ref [] in
  let lock_harness = ref None in
  let lock_scope = ref None in
  (if Sys.file_exists lock_path then
     try
       let json = Yojson.Safe.from_file lock_path in
       lock_harness := json |> Yojson.Safe.Util.member "harness" |> Yojson.Safe.Util.to_string_option;
       lock_scope := json |> Yojson.Safe.Util.member "scope" |> Yojson.Safe.Util.to_string_option;
       recorded :=
         json |> Yojson.Safe.Util.member "files" |> Yojson.Safe.Util.to_assoc
         |> List.map (fun (key, value) -> (key, Yojson.Safe.Util.to_string value))
     with _ -> ());
  (match !lock_harness with
  | Some other when other <> harness_id && not force ->
      failwith
        (Printf.sprintf
           "skills root %s is already managed for harness %s; refusing to install %s variant (pass --force to replace \
            it)"
           skills_root other harness_id)
  | _ -> ());
  (match !lock_scope with
  | Some other when other <> scope_name scope && not force ->
      failwith
        (Printf.sprintf "skills root %s is already managed for scope %s; refusing scope %s (pass --force to replace it)"
           skills_root other (scope_name scope))
  | _ -> ());
  let write_one key dest body =
    (if Sys.file_exists dest && not force then
       let current = Fs_util.digest_hex (Fs_util.read_file dest) in
       if List.assoc_opt key !recorded <> Some current then
         failwith
           (Printf.sprintf "refusing to overwrite hand-edited or foreign file: %s (pass --force to replace it)" dest));
    Fs_util.mkdir_p (Filename.dirname dest);
    Fs_util.write_file dest body;
    recorded := (key, Fs_util.digest_hex body) :: List.remove_assoc key !recorded;
    dest
  in
  let written_skills =
    rendered
    |> List.map (fun (skill_id, body) ->
        write_one skill_id (Fs_util.join (Fs_util.join skills_root skill_id) "SKILL.md") body)
  in
  let written_prompts =
    match prompts_root with
    | None -> []
    | Some prompt_root ->
        skill_sources root
        |> List.filter_map (fun source ->
            match render_prompt_source root harness source with
            | None -> None
            | Some body ->
                let skill_id = skill_id_of_source source in
                Some (write_one ("prompt:" ^ skill_id) (Fs_util.join prompt_root (skill_id ^ ".md")) body))
  in
  let written = written_skills @ written_prompts in
  let files_json =
    `Assoc (!recorded |> List.sort (fun (a, _) (b, _) -> String.compare a b) |> List.map (fun (k, v) -> (k, `String v)))
  in
  let lock =
    `Assoc
      [
        ("version", `String (version root));
        ("harness", `String harness_id);
        ("scope", `String (scope_name scope));
        ("files", files_json);
      ]
  in
  Fs_util.mkdir_p skills_root;
  Fs_util.write_file lock_path (Yojson.Safe.pretty_to_string lock ^ "\n");
  written

let install_many root installs scope force =
  let harnesses = Harness.load root in
  let resolved =
    installs
    |> List.map (fun (harness_id, target) ->
        match Harness.find harnesses harness_id with
        | Some harness -> (harness, target)
        | None -> failwith ("unknown harness: " ^ harness_id))
  in
  let roots =
    resolved |> List.map (fun (harness, target) -> (harness.Harness.id, fst (install_roots target harness scope)))
  in
  let rec check_seen = function
    | [] -> ()
    | (id, root) :: rest ->
        (match List.find_opt (fun (_, other_root) -> other_root = root) rest with
        | Some (other_id, _) ->
            failwith
              (Printf.sprintf "harnesses %s and %s share skills root %s in this scope; install one variant at a time" id
                 other_id root)
        | None -> ());
        check_seen rest
  in
  check_seen roots;
  resolved |> List.concat_map (fun (harness, target) -> install root target harness.Harness.id scope force)
