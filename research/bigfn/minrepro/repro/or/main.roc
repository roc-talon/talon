main! = |args| {
	s = args.first().map_ok(|a| a.to_str()) ?? ""
	e = match args.len() {
		0 => A
		1 => B
		2 => C
		3 => D
		4 => E
		5 => F
		_ => Z
	}
	match e {
		A | B | C | D | E | F => match s {
			"k0" => echo!("line 00 of the arm body")
			"k1" => echo!("line 01 of the arm body")
			"k2" => echo!("line 02 of the arm body")
			"k3" => echo!("line 03 of the arm body")
			"k4" => echo!("line 04 of the arm body")
			"k5" => echo!("line 05 of the arm body")
			"k6" => echo!("line 06 of the arm body")
			"k7" => echo!("line 07 of the arm body")
			"k8" => echo!("line 08 of the arm body")
			"k9" => echo!("line 09 of the arm body")
			"k10" => echo!("line 10 of the arm body")
			"k11" => echo!("line 11 of the arm body")
			"k12" => echo!("line 12 of the arm body")
			"k13" => echo!("line 13 of the arm body")
			"k14" => echo!("line 14 of the arm body")
			"k15" => echo!("line 15 of the arm body")
			"k16" => echo!("line 16 of the arm body")
			"k17" => echo!("line 17 of the arm body")
			"k18" => echo!("line 18 of the arm body")
			"k19" => echo!("line 19 of the arm body")
			_ => {}
		}
		Z => {}
	}
	Ok({})
}
