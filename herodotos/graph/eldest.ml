open Helper

let age vlist factor bugs idx =
  let eldestage = List.fold_left (fun eldest bug ->
		    let (_,_, _, _, bmin, bmax, _) = bug in
		      if bmin <= idx && idx <= bmax then
			let (_, dmin, _, _) = Array.get vlist bmin in
			let (_, dmax, _, _) = Array.get vlist idx in
			  max eldest (dmax - dmin)
		      else
			eldest
		 ) 0 bugs
  in (float_of_int eldestage) /. factor

let eldest vlist bugs grinfo vminopt =
  let (_,_, _, _, _, _, factor) = grinfo in
    wrap_single_some (Array.init (Array.length vlist) (age vlist factor bugs))

let xmax vers _ = ceil (get_xmax vers)
let ymax evol = (0.0, ceil (get_ymax1 evol))

let dfts = ("Eldest", "Project", "Age of the eldest", 365.25, xmax, ymax, false, eldest)
