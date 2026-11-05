let read_file path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () ->
      let length = in_channel_length channel in
      really_input_string channel length)

let write_file path contents =
  let channel = open_out_bin path in
  Fun.protect ~finally:(fun () -> close_out channel) (fun () -> output_string channel contents)

let rec mkdir_p path =
  if path = "" || path = "." || Sys.file_exists path then ()
  else (
    mkdir_p (Filename.dirname path);
    try Unix.mkdir path 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ())

let list_dir path =
  if Sys.file_exists path && Sys.is_directory path then Sys.readdir path |> Array.to_list |> List.sort String.compare
  else []

let join = Filename.concat
let digest_hex text = Digest.string text |> Digest.to_hex
