type t = {
  id : string;
  display : string;
  skills_dir : string;
  invocation_format : string;
  command_invocation_format : string option;
  prompts_dir : string option;
  global_skills_dir : string;
  global_prompts_dir : string option;
  tested : bool;
}

let format_invocation format skill_id =
  let format = format in
  let buffer = Buffer.create 32 in
  let rec go i =
    if i < String.length format then
      if i + 7 <= String.length format && String.sub format i 7 = "{skill}" then (
        Buffer.add_string buffer skill_id;
        go (i + 7))
      else (
        Buffer.add_char buffer format.[i];
        go (i + 1))
  in
  go 0;
  Buffer.contents buffer

let invocation harness skill_id = format_invocation harness.invocation_format skill_id

let command_invocation harness skill_id =
  harness.command_invocation_format |> Option.map (fun format -> format_invocation format skill_id)

let load root =
  let path = Filename.concat root "harnesses.json" in
  let json = Yojson.Safe.from_file path in
  let rows = Yojson.Safe.Util.to_assoc json in
  rows
  |> List.map (fun (id, row) ->
      let open Yojson.Safe.Util in
      {
        id;
        display = row |> member "display" |> to_string;
        skills_dir = row |> member "skills_dir" |> to_string;
        invocation_format = row |> member "invocation" |> to_string;
        command_invocation_format = row |> member "command_invocation" |> to_string_option;
        prompts_dir = row |> member "prompts_dir" |> to_string_option;
        global_skills_dir = row |> member "global_skills_dir" |> to_string;
        global_prompts_dir = row |> member "global_prompts_dir" |> to_string_option;
        tested = row |> member "tested" |> to_bool_option |> Option.value ~default:false;
      })
  |> List.sort (fun a b -> String.compare a.id b.id)

let find harnesses id = List.find_opt (fun harness -> harness.id = id) harnesses
