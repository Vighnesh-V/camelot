(** Entry point for the OCaml linter.

    Parses command line args, and runs the linter

*)

open Canonical
open Report
module Config = Arthur
let lint_dir : string ref = ref "./" (* lint the current directory if none provided *)
let recurse : bool ref = ref false (* Do not recurse the directory by default *)
let lint_file : string option ref = ref None (*  lint a given file*)
let show_type : (Hint.hint list -> unit) ref = ref Report.Display.student_display (* default to showing hints for students *)
let config_file : string ref = ref "arthur.yaml" (* Use the following file as a configuration *)
(* The spec we'll be using to format command line arguments *)

let set_config_file : string -> unit = fun s ->
  config_file := s

(** TODO: sort out this camelot config stuff tomorrow *)
let set_display_type : string -> unit = fun s ->
  match s with
  | "ta" -> show_type := Display.ta_display
  | "gradescope" -> show_type := Display.gradescope_display
  | "json" -> show_type := Display.json_display
  | _ -> show_type := Display.student_display

let fail msg = prerr_endline msg; exit 1

let set_lint_file : string -> unit = fun s ->
  let exist = try
      let _ = open_in s in
      Some s
    with Sys_error _ -> None in
  lint_file := exist

let safe_open src =
  try src, open_in src 
  with Sys_error msg -> fail msg

let lex_src file =
  let src, f = safe_open file in
  src, Lexing.from_channel f

let parse_src (src, lexbuf) =
  src, Parse.implementation lexbuf


let to_lint dirname =
  begin match !lint_file with
  | Some f -> [f]
  | None -> (* We don't want to lint a single *)
     (* Instead use the arthur config system *)
     Config.files_to_lint !recurse dirname
  end

let parse_sources_in (files: string list) : (string * Parsetree.structure) list = 
  let open Sys in
    files |>
    List.filter (fun f -> not (is_directory f)) |> (* remove directories *)
    List.filter (fun f -> Filename.check_suffix f ".ml") |> (* only want to lint *.ml files *)
    List.map (lex_src) |> (* Tokenize the files *)
    List.map (parse_src) (* Parse the files *)

let usage_msg =
  "invoke with -r (only works if -d is set too) to recurse into subdirectories\n" ^
  "invoke with -d <dir_name> to specify a directory to lint, or just run the program with default args\n" ^
  "invoke with -show <student | ta | gradescope> to select the display type - usually ta's want a briefer summary\n" ^
  "invoke with -f <.ml filename> to lint a particular file\n"^
  "invoke with -c <path/to/arthur.json> to inform the linter of where the config file is"

let spec =
  let open Arg in
  [
    "-r", Set recurse, 
    "\t If calling on a directory using -d, recurse into its subdirectories"
  ;  "-d", Set_string lint_dir, 
     "\t Invoke the linter on the provided directory, defaulting to the current directory, non re"
  ; "-show", String set_display_type,
    " Make the linter output display for either ta's | students | gradescope"
  ; "-f", String set_lint_file,
    "\t Invoke the linter on a single file"
  ; "-c", String (set_config_file),
    "\t Invoke the linter using the provided arthur.yaml config file"
  ] 

let () =
  (* Initialize things *)
  Arg.parse spec (fun _ -> ()) usage_msg;
  begin
    (* set the config file here *)
    match Config.parse_file_config !config_file with
    | Ok config -> Config.set_config config
    | Error e -> fail e
  end;
  (* Figure out what files to lint *)
  let sources : string list = to_lint !lint_dir in
  sources |> parse_sources_in |> Linter.lint;
  (* Display the hints *)
  Linter.hints () |> List.rev |> !show_type
