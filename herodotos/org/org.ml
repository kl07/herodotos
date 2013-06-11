open Lexing

(* let auto_correl = ref 0 *)
exception Error of string
exception Unrecoverable

let status = [Ast_org.BUG;
	      Ast_org.FP;
	      Ast_org.UNKNOWN;
	      Ast_org.IGNORED]
(*crée la chaine constituée des status ci-dessus séparés par des espaces *)
let statuslist = String.concat " " (List.map Org_helper.get_status status)

(*à quoi ça seeert???::dernière ligne .org *)
let orgtail = "* org config\n\n#+SEQ_TODO: TODO | "^statuslist^"\n"

(* crée un tableau de([],table de hashage) de mm taille que vlist *)
let emptyarray vlist =
  Array.init (Array.length vlist) (fun _ -> ([], Hashtbl.create 97))

(*ex: dans demo, prefix=/var/manseur/demo/herodotos/herodotos/demo/test/;v=ver1 *)
(*triplet prefix-version/nom_fichier,[4 orgoptions ??],is_head-prefix-version/nom_fichier::line?? :type link  *)
let make_orglink_of_bug prefix bug =
  let (_, _, _, f, v, (l,b,e), face, t, _, _) = bug in
    (
      prefix^v^"/"^f,
      [Ast_org.Face face;
       Ast_org.Line l;
       Ast_org.ColB b;
       Ast_org.ColE e],
      t ^ Printf.sprintf " %s%s/%s::%d" prefix v f l
    )

(*retourne la chaine correspondant à la "première "face de la liste ops *)
let face_of ops =
  match List.find (fun x ->
		     match x with
			 Ast_org.Face _  -> true
		       | _ -> false) ops
  with
      Ast_org.Face f -> f
    | _ -> raise Unrecoverable

(*retourne l'entier correspondant à la "première " line de la liste ops *)
let line_of ops =
  match List.find (fun x ->
		     match x with
			 Ast_org.Line _  -> true
		       | _ -> false) ops
  with
      Ast_org.Line l -> l
    | _ -> raise Unrecoverable

(*retourne l'entier correspondant à la "première " colB de la liste ops *)
let start_of ops =
  match List.find (fun x ->
		     match x with
			 Ast_org.ColB _ -> true
		       | _ -> false) ops
  with
      Ast_org.ColB b -> b
    | _ -> raise Unrecoverable

(*retourne l'entier correspondant à la "première " colE de la liste ops *)
let end_of ops =
  match List.find (fun x ->
		     match x with
			 Ast_org.ColE _ -> true
		       | _ -> false) ops
  with
      Ast_org.ColE e -> e
    | _ -> raise Unrecoverable

(*Crée le triplet (line,colB,colE) (par ex à partir de la liste créée par make_orglink_of_bug prefix ) *)
let position ops =
  (line_of ops, start_of ops, end_of ops)

(* ??? *)
let clean_link_text prefix v f pos t =
  let (l,_,_) = pos in
  let endstr = Printf.sprintf "%s/%s::%d" v f l in
  let re = Str.regexp (" ?"^(Str.quote endstr)^"$") in
  let re_prefix = Str.regexp_string prefix in
  let new_t = Str.replace_first re_prefix "" t in
    Str.global_replace re "" new_t

(* Prefix should have a trailing '/' *) (*apparamment appelée pour le .new.org (lien_bug) *)
let make_orglinkbug_freetext prefix (bug: Ast_org.bug) =
  let (_, _, _, file, ver, pos, face, t, _, _, _) = bug in
  let (line, cb, ce) = pos in
    Printf.sprintf
      "[[view:%s%s/%s::face=%s::linb=%d::colb=%d::cole=%d][%s]]"
      prefix ver file face line cb ce t

(* Prefix should have a trailing '/' *)  (*apparamment appelée pour le .correl.org (lien_bug) *)
let make_orglinkbug w_freetext prefix bug =
  let (_, _, _, file, ver, pos, face, t, _, _, _) = bug in
  let (line, cb, ce) = pos in
    if w_freetext then
      let clean_t = clean_link_text prefix ver file pos t in
      let new_t = if clean_t = "" then "" else clean_t ^ " " in
	Printf.sprintf
	  "[[view:%s%s/%s::face=%s::linb=%d::colb=%d::cole=%d][%s%s%s/%s::%d]]"
	  prefix ver file face line cb ce new_t prefix ver file line
    else
	Printf.sprintf
	  "[[view:%s%s/%s::face=%s::linb=%d::colb=%d::cole=%d][%s%s/%s::%d]]"
	  prefix ver file face line cb ce prefix ver file line

(*crée une chaine de level étoiles ici 1 ou 2 selon le level*)
let rec make_star level =
  if level > 0 then
    if level = max_int then
      ""
    else
      "*" ^ make_star (level -1)
  else
    ""
(*crée la chaine indiquant le bug avec la ligne,début et fin par ex dans les rapports d'erreurs.org  *)
let make_link prefix link =
  let (p, ops, t) = link in
  let pos = position ops in
  let face = face_of ops in
  let (line, cb, ce) = pos in
      Printf.sprintf "[[view:%s%s::face=%s::linb=%d::colb=%d::cole=%d][%s]]"
	prefix p face line cb ce t

(* produit une ligne d'un rapport d'erreurs .org *)
let rec make_org prefix org =
  let Ast_org.Org(l, s, r, link, sub) = org in
  let head = String.concat " "
    (List.filter (fun x -> x <> "")                (*retourne la liste des elts /="" on a par exp "* TODO ..." *)
       [ make_star l ; Org_helper.get_status s ; r]) (*head:string *)
  in
  let head = Printf.sprintf "%s %s" head (make_link prefix link) in    (* ex "* TODO [link du bug] "*)
  let tail = List.map (make_org prefix) sub in                         (* la mm chose pour les sub_items  sans le "* TODO"*)
  let tailstring = String.concat "\n" tail in
    head ^ if tailstring = "" then "" else "\n" ^ tailstring         (*ex "* TODO [link du bug]
                                                                                  [link du bug]  "  *)
(* produit une seule ligne du .new.org*)
let make_flat_org prefix org =
  let (l, s, r, file, ver, pos, face, t, _, _, sub) = org in  (*org est un buuuuug*)
  let head = String.concat " "
    (List.filter (fun x -> x <> "")
       [ make_star l ; Org_helper.get_status s ; r]) (*head:string  *)
  in
  let link = make_orglinkbug_freetext prefix org in
  let head = Printf.sprintf "%s %s" head link in
  let tail = List.map (make_org "") sub in
  let tailstring = String.concat "\n" tail in
    head ^ if tailstring = "" then "" else "\n" ^ tailstring

let parse_line file lnum line : (int * Ast_org.org) option =
  try
    let lexbuf = Lexing.from_string line in
      try
	Misc.init_line file lnum lexbuf;
	let ast = Org_parser.oneline Org_lexer.token lexbuf in
	  Some ast
      with
	  (Org_lexer.Lexical msg) ->
	    let pos = lexbuf.lex_curr_p in
	      Misc.report_error
		{ Ast.file  = file;
		  Ast.line  = pos.pos_lnum;
		  Ast.colfr = pos.pos_cnum - pos.pos_bol;
		  Ast.colto = (Lexing.lexeme_end lexbuf) - pos.pos_bol + 1}
		("Org Lexer Error: " ^ msg);
	| Org_parser.Error ->
	    let pos = lexbuf.lex_curr_p in
	      Misc.report_error
		{ Ast.file  = file;
		  Ast.line  = pos.pos_lnum;
		  Ast.colfr = pos.pos_cnum - pos.pos_bol;
		  Ast.colto = (Lexing.lexeme_end lexbuf) - pos.pos_bol + 1}
		("Org Parser Error: unexpected token '" ^ (Lexing.lexeme lexbuf) ^"'")
  with Sys_error msg ->
    prerr_endline ("*** WARNING *** "^msg);
    None

let push_stack stack org =
  [org]::stack

let pop_stack stack =
  match stack with
      [] -> []
    | [head] -> [head]
    | head::bighead::tail ->
	match bighead with
	    [] -> raise Unrecoverable
	  | tophead::toptail ->
	      let Ast_org.Org(lvl, s, r, link, sub) = tophead in
		((Ast_org.Org(lvl, s, r, link, sub@(List.rev head)))::toptail)::tail

let upd_head stack org =
  match stack with
      [] -> [[org]]
    | head::tail -> (org::head)::tail

let rec parse_line_opt v file olnum ch =
  let lnum = olnum + 1 in
  let lineopt =
    try
      Some (input_line ch)
    with End_of_file -> None
  in
    match lineopt with
	None -> (lnum, None)
      | Some line ->
(* 	  if !Misc.debug then prerr_string (Printf.sprintf "% 3d " lnum); *)
	  if line = "* org config" then
	    parse_line_opt v file lnum ch
	  else if line = "" then
	    parse_line_opt v file lnum ch
	  else
	    let re = Str.regexp ("^" ^ Str.quote "#+SEQ_TODO:") in
	    if Str.string_match re line 0 then
	      parse_line_opt v file lnum ch
	    else
	      (if v then prerr_endline line;
	       (lnum, parse_line file lnum line))

(*
let dbg_cvt_lvl level =
  if level = max_int then
    "**"
  else
    Printf.sprintf "% 2d" level

let dbg_stack_el prefix stack =
  Misc.print_stack (List.map (fun o -> prefix ^(make_org 0 "" o)) stack)

let dbg_stack clevel level stack =
  Printf.eprintf " C:%s / L:%s\n" (dbg_cvt_lvl clevel) (dbg_cvt_lvl level);
  match stack with
      [] -> ()
    | head::tail ->
	Printf.eprintf "HEAD\n";
	dbg_stack_el "" head;
	Printf.eprintf "TAIL\n";
	List.fold_left (fun i s -> dbg_stack_el (string_of_int i) s;i+1) 1 tail;
	Printf.eprintf "-----------------------\n"
*)

let rec reduce_lines v file lnum (clevel, lineinfo, stack) ch =
  let (level, org) = lineinfo in
(*     if !Misc.debug then dbg_stack clevel level stack; *)
    if clevel = level then
      (* Same level: update stack head, reduce with stack*)
      let newstack = upd_head stack org in
      let (lnum, sinfo, newstack) = parse_lines v file lnum (level, newstack) ch in
	shift_lines v file lnum (clevel, sinfo, newstack) ch
    else if clevel < level then
      (* Sub-level: push in new environment at the beginning, pop at the end *)
      let newstack = push_stack stack org in
      let (lnum, sinfo, newstack) = parse_lines v file lnum (level, newstack) ch in
	shift_lines v file lnum (clevel, sinfo, newstack) ch
    else (* clevel > level *)
      (lnum, Some lineinfo, pop_stack stack) (* Reduce clevel elements *)

and shift_lines v file lnum (clevel, sinfo, stack) ch =
  match sinfo with
      None          -> parse_lines v file lnum (clevel, stack) ch
    | Some lineinfo -> reduce_lines v file lnum (clevel, lineinfo, stack) ch

and parse_lines v file olnum (clevel, stack) ch =
  let (lnum, lineopt) = parse_line_opt v file olnum ch in
    match lineopt with
	None          -> (lnum, None, pop_stack stack)
      | Some lineinfo -> reduce_lines v file lnum (clevel, lineinfo, stack) ch

let parse_all_lines v file ch =
  let (_, rem, orgs) = parse_lines v file 0 (0, []) ch in
    match rem with
	None     -> orgs
      | Some (_,org) -> [org]::orgs

let parse_org v file : Ast_org.orgs =    (*file est dans le cas qui nous intéresse un correlfile *)
  Debug.profile_code_silent "parse_org" (*d'après ce que j'ai compris, le résultat de Debug.pofile... fait que f() est exécutée *)
    (fun () ->
       try
	 let in_ch = if file <> "-" then open_in file else stdin in
	 let ast = List.flatten (parse_all_lines v file in_ch) in
	   close_in in_ch;
	   ast
       with Sys_error msg ->
	 prerr_endline ("*** WARNING *** "^msg);
	 []
    )





  






(* à refaire; essayer éventuellement de paralléliser *)
let rec parse_orgs v (files:(int*string) list)=
  match files with
    |[]->[]
    |file::file_list->(fst file,parse_org v (snd file))::(parse_orgs v file_list)



let get_string_pos (line, cb, ce) =
  let sline = string_of_int line in
  let scb = string_of_int cb in
  let sce = string_of_int ce in
  let snpos = "("^sline  ^"@"^ scb ^"-"^ sce ^ ")" in
    snpos

let show_bug verbose bug =
  let (_, _, _, _, ver, pos, _, _,_, _, _) = bug in
    prerr_string ver;
    if verbose then prerr_string (get_string_pos pos)

let flat_link prefix depth link =
  let (p, ops, t) = link in
      let (ver, file) = Misc.strip_prefix_depth prefix depth p in
      let pos = position ops in
      let face = face_of ops in
(*
      let re = Str.regexp (Str.quote prefix) in
      let new_t = Str.replace_first re "" t in
*)
	(file, ver, pos, face, t)

let extract_link org =
  let Ast_org.Org(lvl, s, r, link, sub) = org in
    link

(* TODO + FIXME --- Should remove duplicate bug reports *)
let find_all_org_w_status org orgs =
  let (_, so, _, fo, vo, po, _, _, _, _, _) = org in
    List.find_all (fun (_, s, _, f, v, p, _, _, _, _, _) ->
		     s = so && f = fo && v = vo && p = po
		  ) orgs

(*
  Used to group similar main entries
  Sub-items are regrouped.
*)

let update_list orglist org =
  let tomerge = find_all_org_w_status org orglist in
    if tomerge = [] then
      org::orglist
    else
      let subtomerge =
	List.flatten (List.map
			(fun (_, _, _, _, _, _, _, _, _, _, sub) -> sub)
			tomerge)
      in
      let newlist = List.filter (fun e -> not (List.mem e tomerge)) orglist in
      let (l, s, r, f, v, pos, face, t, h, n, sub) = org in
	(l, s, r, f, v, pos, face, t, h, n, sub@subtomerge)::newlist

let rec filter_orgs orgs =
  match orgs with
      []       -> []
    | hd::tail ->
	let t2 = filter_orgs tail in
	  update_list t2 hd

let flat_org prefix depth raw_org : Ast_org.bug =
  let Ast_org.Org(lvl, s, r, link, sub) = raw_org in
  let (file, ver, pos, face, t) = flat_link prefix depth link in
    (lvl, s, r, file, ver, pos, face, t, {Ast_org.is_head=true}, {Ast_org.def=None}, sub)



let get_version_name file = let dirList = Str.split (Str.regexp "/") file in 
                                   let vname = List.nth dirList (List.length dirList -2) in
                                   (vname,file) 

(* début modif*)
let get_version prefix depth vlist raw_org=
  let org = flat_org prefix depth raw_org in
  let (_, _, _, file, ver, _, _, _, _, _, _) = org in
  Misc.get_idx_of_version vlist ver

let get_versions prefix depth vlist orgs=try get_version prefix depth vlist (List.hd orgs)
                                         with _->0

(* associates each orgs to its version *)
let rec get_versionsList prefix depth vlist orgsList:(int * Ast_org.orgs)list = match orgsList with
              []->[]
             |orgs::orgsList_tail->(get_versions prefix depth vlist orgs,orgs )::(get_versionsList prefix depth vlist orgsList_tail)


(*doit remplacer la fonction qu'elle précéde *)
let flat_org_for_arrBis  prefix depth (flist,tbl) (raw_org:Ast_org.org)  =
  let org = flat_org prefix depth raw_org in (*:Ast_org.bug *)
  let (_, _, _, file, ver, _, _, _, _, _, _) = org in
  let (orglist:Ast_org.bug list) = try Hashtbl.find tbl file with _ -> [] in
  let newlist = update_list orglist org in
    Hashtbl.replace tbl file newlist;
    if not (List.mem file flist) then
       (file::flist, tbl)
    else
       (flist,tbl)

let flat_org_for_arr prefix depth vlist orgarray (raw_org:Ast_org.org) : unit =
  let org = flat_org prefix depth raw_org in (*:Ast_org.bug *)
  let (_, _, _, file, ver, _, _, _, _, _, _) = org in
  let idx = Misc.get_idx_of_version vlist ver in
  let ((flist, tbl)) = Array.get orgarray idx in (*:(path list * table de hachage(path,bugs)) *)
  let (orglist:Ast_org.bug list) = try Hashtbl.find tbl file with _ -> [] in
  let newlist = update_list orglist org in
    Hashtbl.replace tbl file newlist;
    if not (List.mem file flist) then
      Array.set orgarray idx (file::flist, tbl)


let format_orgs prefix depth orgs =
  Debug.profile_code_silent "format_orgs"
    (fun () -> let flat_orgs_to_filter = List.map (flat_org prefix depth) orgs in
       filter_orgs flat_orgs_to_filter
    )

(*let format_orgs_to_arr_aux prefix depth vlist orgs= 
  let rec format_orgs_to_arr_ter prefix depth vlist orgs orgarray : Ast_org.orgarray = 
     match orgs with 
       []->orgarray
      |org::orglist->List.iter(flat_org_for_arr prefix depth vlist orgarray) org;
                     (format_orgs_to_arr_ter prefix depth vlist orglist orgarray)
  in format_orgs_to_arr_ter prefix depth vlist orgs (emptyarray vlist)
*)






(*let format_orgsList_to_arr prefix depth vlist (orgsList:(int*Ast_org.orgs) list) : Ast_org.orgarray =
   Debug.profile_code_silent "format_orgs_to_arr" 
   (fun()-> let orgarray=emptyarray vlist in
      List.iter(fun orgs->List.iter(fun org->flat_org_for_arrBis (fst orgs) prefix depth orgarray org)(snd orgs))orgsList;
       orgarray
    )*)


let build_org_arr prefix depth resultsdir pdir orgfile vlist :Ast_org.orgarray =  
  Array.map(fun vers -> let (vname,i,tm,i2) = vers in
			
                        let orgs=(parse_org false (resultsdir^pdir^"/"^vname^"/"^orgfile)) in
                        
                        List.fold_left(fun arrayelt org ->flat_org_for_arrBis  prefix depth arrayelt org)([],Hashtbl.create 97) orgs
                         
                        ) vlist


  

let format_orgs_to_arr prefix depth vlist (orgs:Ast_org.orgs ) : Ast_org.orgarray =
   Debug.profile_code_silent "format_orgs_to_arr" 
    (fun () -> let orgarray = emptyarray vlist in
       List.iter (flat_org_for_arr prefix depth vlist orgarray) orgs;
       orgarray
    )


                                              


let count = ref 0

let show_org verbose prefix orgs =
  count := 0;
  if verbose then
    begin
      prerr_endline ("SHOW ORG\nPrefix used: " ^ prefix);
      List.iter (fun (file, bugslist) ->
		   prerr_string file;
		   prerr_newline ();
		   List.iter (fun bugs ->
				prerr_string "#";
				prerr_int !count;
				count := !count + 1;
				prerr_string " in vers. ";
				List.iter
				  (fun  bug ->
				     show_bug verbose bug;
				     prerr_string " -> "
				  )
				  bugs;
		   		prerr_newline ()
			     )
		     bugslist;
		   prerr_newline ()
		)
	orgs
    end

let print_orgs_raw ch prefix orgs =
  List.iter
    (fun o ->
       let orgstr = make_flat_org prefix o in
	 Printf.fprintf ch "%s\n" orgstr
    ) orgs; (*impression dans le channel de chacun des liens respectifs de chacun des bugs de orgs *)
  Printf.fprintf ch "%s" orgtail (* *)

(*?? crée une liste le links_bugs *)
let print_bugs_raw ch prefix bugs =
  let bug = List.hd bugs in
    Printf.fprintf ch "%s\n" (make_flat_org prefix bug);
    List.iter
      (fun  bug ->
	 Printf.fprintf ch "** %s\n"
	   (make_orglinkbug true prefix bug)
      ) bugs
(*?? crée la chaine des link_bugs du fichier  prefix/path(present dans le lien de chaque org de la liste orgs) *)
let print_bugs ch prefix orgs =
  List.iter (fun (_, bugslist) ->
	       List.iter (print_bugs_raw ch prefix) bugslist
	    )
    orgs;
  Printf.fprintf ch "%s" orgtail

let compute_correlation prefix depth correl =
  let list = List.map (flat_org prefix depth) correl in
    List.fold_left (fun correllist b ->
		 let (_, s, _, file, ver, pos, _, t, _, _,sub) = b in
		   try
		     let l = extract_link (List.hd sub) in
		     let new_t = clean_link_text prefix ver file pos t in
		     let (nfile, nver, npos, _, _) = flat_link prefix depth l in
		       (s, file, ver, pos, nfile, nver, npos, new_t)::correllist
		   with Failure _ -> correllist
		   ) [] list

let show_correlation verbose correl =
  if verbose then
    begin
      prerr_endline "SHOW CORRELATION";
      List.iter (fun b ->
		   let (s, file, ver, pos, nfile, nver, next, t) = b in
		     prerr_string (Org_helper.get_status s ^ " ");
		     prerr_string (file ^" ");
		     prerr_string ver;
		     prerr_string " ";
		     prerr_string (get_string_pos pos);
		     prerr_string " -> ";
		     prerr_string (nfile ^" ");
		     prerr_string nver;
		     prerr_string " ";
		     prerr_string (get_string_pos next);
		     prerr_newline ()
		) correl
    end

let sort_bug bug1 bug2 =
  let (l1, s1, r1, f1, v1, pos1, _, t1, _, _, sub1) = bug1 in
  let (l2, s2, r2, f2, v2, pos2, _, t2, _, _, sub2) = bug2 in
  let dt = compare t1 t2 in
  if dt <> 0 then
    dt
  else
    let df = compare f1 f2 in
    if df <> 0 then
      df
    else
      let dv = compare v1 v2 in
      if dv <> 0 then
	dv
      else
	let dpos = compare pos1 pos2 in
	if dpos <> 0 then
	  dpos
	else
	  compare bug1 bug2

let sort bugarray =
  Array.iter
    (fun (flist, tbl) ->
       List.iter
	 (fun file ->
	    let bugs = Hashtbl.find tbl file in
	      Hashtbl.replace tbl file
		(List.sort sort_bug bugs)
	 ) flist
    ) bugarray

let list_of_bug_array bugarray =
  Array.fold_left
    (fun head (flist, tbl) ->
       head @ List.flatten
	 (List.map
	    (fun file ->
	       Hashtbl.find tbl file
	    ) flist
	 )
    ) [] bugarray

let length bugarray =
  Array.fold_left
    (fun sum (flist, tbl) ->
       sum + (List.fold_left
		(fun sum file ->
		   sum + (List.length (Hashtbl.find tbl file))
		) 0 flist
	 )
    ) 0 bugarray

(*retourne la liste des fichiers .org dans toutes les versions avec,pour chaque fichier, le numéro de version *)
let rec orgfiles resultsdir pdir orgfile vlist indice:(int*string) list =
  if indice=(Array.length vlist) then []
  else let (vname,i,tm,i2)=vlist.(indice) in
       if Sys.file_exists (resultsdir^pdir^"/"^vname^"/"^orgfile) then (indice,resultsdir^pdir^"/"^vname^"/"^orgfile)::(orgfiles resultsdir pdir orgfile vlist (indice+1))
       else raise (Error ("File "^resultsdir^pdir^"/"^vname^"/"^orgfile^" must have been deleted")) 


(*nouvelle fonction pour remplacer orgfiles ci-dessus  *)


                                  
     
(* fonction trace à virer  *)
let rec trace orgarray indice=
  if indice=(Array.length orgarray) then ()
  else let (pathlist,reste)=orgarray.(indice) in
       List.iter(fun elt->Printf.printf "%s\n" elt ) pathlist;(trace orgarray (indice+1))
