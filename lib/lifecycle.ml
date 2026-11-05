(* Explicit retirements only: absence from a render is not permission to delete. *)
let retired root ~valid_id ~active =
  let path = Fs_util.join root "retired-skills.json" in
  if not (Sys.file_exists path) then []
  else
    Yojson.Safe.from_file path |> Yojson.Safe.Util.to_assoc
    |> List.map (fun (id, metadata) ->
        if not (valid_id id) then failwith ("invalid retired skill id: " ^ id);
        if List.mem id active then failwith ("retired skill is still active: " ^ id);
        (match Yojson.Safe.Util.member "replacement" metadata with
        | `Null -> ()
        | `String next when List.mem next active -> ()
        | _ -> failwith ("invalid replacement for retired skill: " ^ id));
        let reason = metadata |> Yojson.Safe.Util.member "reason" |> Yojson.Safe.Util.to_string in
        if String.trim reason = "" then failwith ("missing retirement reason: " ^ id);
        id)

let rec no_symlink ~root path =
  (try (Unix.lstat path).Unix.st_kind <> Unix.S_LNK with Unix.Unix_error (Unix.ENOENT, _, _) -> true)
  && (path = root || (path <> Filename.dirname path && no_symlink ~root (Filename.dirname path)))

let pi_settings_plan base ids =
  let path = Fs_util.join base "settings.json" in
  let fields = if Sys.file_exists path then Yojson.Safe.from_file path |> Yojson.Safe.Util.to_assoc else [] in
  let existing =
    match List.assoc_opt "skills" fields with
    | None -> []
    | Some value -> Yojson.Safe.Util.to_list value |> List.map Yojson.Safe.Util.to_string
  in
  (* Prefer the installed Pi variants; leave Codex/Muse's files intact. *)
  let patterns = ids |> List.map (fun id -> "!**/.agents/skills/" ^ id ^ "/SKILL.md") in
  let merged = existing @ List.filter (fun pattern -> not (List.mem pattern existing)) patterns in
  let fields = ("skills", `List (List.map (fun s -> `String s) merged)) :: List.remove_assoc "skills" fields in
  (path, Yojson.Safe.pretty_to_string (`Assoc fields) ^ "\n")

let cleanup ~dry_run ~owned ~version ~recorded ~removals ~root key dest =
  let exists =
    try
      ignore (Unix.lstat dest);
      true
    with Unix.Unix_error (Unix.ENOENT, _, _) -> false
  in
  if exists then
    match List.assoc_opt key !recorded with
    | Some hash
      when owned && no_symlink ~root dest
           && (Unix.lstat dest).Unix.st_kind = Unix.S_REG
           && Fs_util.digest_hex (Fs_util.read_file dest) = hash ->
        Printf.eprintf "%s retired file: %s\n%!" (if dry_run then "would remove" else "removing") dest;
        if not dry_run then (
          Sys.remove dest;
          if (not (String.starts_with ~prefix:"prompt:" key)) && Fs_util.list_dir (Filename.dirname dest) = [] then
            Unix.rmdir (Filename.dirname dest));
        recorded := List.remove_assoc key !recorded;
        removals :=
          !removals
          @ [
              `Assoc
                [
                  ("key", `String key);
                  ("path", `String dest);
                  ("hash", `String hash);
                  ("version", `String version);
                  ("removed_at", `Float (Unix.gettimeofday ()));
                ];
            ]
    | _ -> Printf.eprintf "preserved modified, foreign, or symlinked retired file: %s\n%!" dest
  else recorded := List.remove_assoc key !recorded
