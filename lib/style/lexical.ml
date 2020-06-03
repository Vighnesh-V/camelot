open Canonical
(* open Utils.IOUtils *)
open Check


module LineLength : LEXICALCHECK = struct

  type ctxt = Pctxt.file Pctxt.pctxt 
  let fix = "indenting to avoid exceeding the line limit"
  let violation = "exceeding the 80 character line limit. Only showing (1) such violation of this kind, although there may be others - fix this and re-run the linter to find them."
    
      
  let check st (L {source; pattern = Pctxt.F chan}: ctxt) =
    let filestream : (int * string) Stream.t =
      Stream.from
        (fun line -> try (Some (line, input_line chan))
          with End_of_file -> None
        ) in
    
    Stream.iter (fun (line_no, line) ->
        if String.length line > 80 then
          st := Hint.line_hint source line_no line :: !st
      ) filestream
    
  let name = "LineLength", check
end
