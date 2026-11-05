(* A deliberately tiny Jinja-shaped template engine.

   Supported syntax, and nothing else:
   - {{ name }} and {{ dotted.name }} substitution, strict on unknown names
   - {% if dotted.name == "literal" %} / {% if dotted.name != "literal" %}
   - {% else %} and {% endif %}, nestable

   No filters, macros, loops, or arithmetic. A skill that needs more is
   logic, and logic belongs in the CLI, not in prose. *)

type node =
  | Text of string
  | Var of string
  | If of { cond_var : string; negate : bool; literal : string; then_ : node list; else_ : node list }

exception Error of string

let error message = raise (Error message)

type token = TText of string | TVar of string | TIf of (string * bool * string) | TElse | TEndif

let starts_with_at s i prefix =
  let lp = String.length prefix in
  i + lp <= String.length s && String.sub s i lp = prefix

let find_from s start needle =
  let ls = String.length s and ln = String.length needle in
  let rec go i = if i + ln > ls then None else if String.sub s i ln = needle then Some i else go (i + 1) in
  go start

let trim = String.trim

let parse_if_tag tag =
  (* tag is the trimmed inside of {% %}; expected: if <var> == "lit" *)
  let re_parts =
    try Scanf.sscanf tag "if %s %s %s" (fun var op lit -> (var, op, lit))
    with _ -> error ("unsupported if expression: " ^ tag)
  in
  let var, op, raw_lit = re_parts in
  let negate = match op with "==" -> false | "!=" -> true | _ -> error ("unsupported if operator: " ^ op) in
  let literal =
    let n = String.length raw_lit in
    if n >= 2 && raw_lit.[0] = '"' && raw_lit.[n - 1] = '"' then String.sub raw_lit 1 (n - 2)
    else error ("if literal must be double-quoted: " ^ raw_lit)
  in
  TIf (var, negate, literal)

let tokenize input =
  let n = String.length input in
  let rec go i acc =
    if i >= n then List.rev acc
    else if starts_with_at input i "{{" then (
      match find_from input (i + 2) "}}" with
      | None -> error "unclosed {{"
      | Some j ->
          let var = trim (String.sub input (i + 2) (j - (i + 2))) in
          if var = "" then error "empty {{ }}";
          go (j + 2) (TVar var :: acc))
    else if starts_with_at input i "{%" then
      match find_from input (i + 2) "%}" with
      | None -> error "unclosed {%"
      | Some j ->
          let tag = trim (String.sub input (i + 2) (j - (i + 2))) in
          let token =
            if tag = "else" then TElse
            else if tag = "endif" then TEndif
            else if starts_with_at tag 0 "if " then parse_if_tag tag
            else error ("unsupported tag: " ^ tag)
          in
          go (j + 2) (token :: acc)
    else
      let next_var = find_from input i "{{" in
      let next_tag = find_from input i "{%" in
      let stop =
        match (next_var, next_tag) with
        | Some a, Some b -> min a b
        | Some a, None -> a
        | None, Some b -> b
        | None, None -> n
      in
      go stop (TText (String.sub input i (stop - i)) :: acc)
  in
  go 0 []

let parse tokens =
  let rec block tokens =
    match tokens with
    | [] -> ([], [], None)
    | TText text :: rest ->
        let nodes, rest', term = block rest in
        (Text text :: nodes, rest', term)
    | TVar var :: rest ->
        let nodes, rest', term = block rest in
        (Var var :: nodes, rest', term)
    | TIf (var, negate, literal) :: rest -> (
        let then_nodes, rest', term = block rest in
        match term with
        | Some "else" -> (
            let else_nodes, rest'', term' = block rest' in
            match term' with
            | Some "endif" ->
                let nodes, rest''', final = block rest'' in
                (If { cond_var = var; negate; literal; then_ = then_nodes; else_ = else_nodes } :: nodes, rest''', final)
            | _ -> error "if without endif")
        | Some "endif" ->
            let nodes, rest'', final = block rest' in
            (If { cond_var = var; negate; literal; then_ = then_nodes; else_ = [] } :: nodes, rest'', final)
        | _ -> error "if without endif")
    | TElse :: rest -> ([], rest, Some "else")
    | TEndif :: rest -> ([], rest, Some "endif")
  in
  let nodes, rest, term = block tokens in
  if rest <> [] || term <> None then error "unbalanced template tags";
  nodes

let lookup context name =
  match List.assoc_opt name context with Some value -> value | None -> error ("unknown template variable: " ^ name)

let rec eval context nodes =
  let buffer = Buffer.create 1024 in
  let rec go = function
    | [] -> ()
    | Text text :: rest ->
        Buffer.add_string buffer text;
        go rest
    | Var var :: rest ->
        Buffer.add_string buffer (lookup context var);
        go rest
    | If { cond_var; negate; literal; then_; else_ } :: rest ->
        let actual = lookup context cond_var in
        let take_then = actual = literal <> negate in
        Buffer.add_string buffer (eval context (if take_then then then_ else else_));
        go rest
  in
  go nodes;
  Buffer.contents buffer

let render ~context input = try Ok (eval context (parse (tokenize input))) with Error message -> Error message

let count_conditionals input =
  let rec count i acc =
    match find_from input i "{%" with
    | None -> acc
    | Some j -> (
        match find_from input (j + 2) "%}" with
        | None -> acc
        | Some k ->
            let tag = trim (String.sub input (j + 2) (k - (j + 2))) in
            let add = if starts_with_at tag 0 "if " then 1 else 0 in
            count (k + 2) (acc + add))
  in
  count 0 0
