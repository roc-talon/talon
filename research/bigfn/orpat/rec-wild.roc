## Or-pattern repro: `big` is called once, so it is inlined. The arm is written with an or-pattern of 6 alternatives
## (dispatch with the or-pattern). The size of `main!` shows how many copies of `big` the compiler makes.
Ev : [A(Str), B(Str), C(Str), D(Str), F(Str), G(Str), H]

ev_of : Str -> Ev
ev_of = |t| match t {
	"a" => A(t)
	"b" => B(t)
	"c" => C(t)
	"d" => D(t)
	"f" => F(t)
	"g" => G(t)
	_ => H
}

## The work of the event `A`, as `own!` of Worker.new runs `fetch!` for `Fetch` only.
big! : Ev => Str
big! = |e| match e {
	A(s) => {
		var $out = ""
		for _i in 0.U64.to(3) {
				if s.starts_with("k0") { echo!("hit k0") 
					$out = $out.concat(s.drop_prefix("k0").with_ascii_uppercased()).concat("-v0-") }
				if s.starts_with("k1") { echo!("hit k1") 
					$out = $out.concat(s.drop_prefix("k1").with_ascii_uppercased()).concat("-v1-") }
				if s.starts_with("k2") { echo!("hit k2") 
					$out = $out.concat(s.drop_prefix("k2").with_ascii_uppercased()).concat("-v2-") }
				if s.starts_with("k3") { echo!("hit k3") 
					$out = $out.concat(s.drop_prefix("k3").with_ascii_uppercased()).concat("-v3-") }
				if s.starts_with("k4") { echo!("hit k4") 
					$out = $out.concat(s.drop_prefix("k4").with_ascii_uppercased()).concat("-v4-") }
				if s.starts_with("k5") { echo!("hit k5") 
					$out = $out.concat(s.drop_prefix("k5").with_ascii_uppercased()).concat("-v5-") }
				if s.starts_with("k6") { echo!("hit k6") 
					$out = $out.concat(s.drop_prefix("k6").with_ascii_uppercased()).concat("-v6-") }
				if s.starts_with("k7") { echo!("hit k7") 
					$out = $out.concat(s.drop_prefix("k7").with_ascii_uppercased()).concat("-v7-") }
				if s.starts_with("k8") { echo!("hit k8") 
					$out = $out.concat(s.drop_prefix("k8").with_ascii_uppercased()).concat("-v8-") }
				if s.starts_with("k9") { echo!("hit k9") 
					$out = $out.concat(s.drop_prefix("k9").with_ascii_uppercased()).concat("-v9-") }
				if s.starts_with("k10") { echo!("hit k10") 
					$out = $out.concat(s.drop_prefix("k10").with_ascii_uppercased()).concat("-v10-") }
				if s.starts_with("k11") { echo!("hit k11") 
					$out = $out.concat(s.drop_prefix("k11").with_ascii_uppercased()).concat("-v11-") }
				if s.starts_with("k12") { echo!("hit k12") 
					$out = $out.concat(s.drop_prefix("k12").with_ascii_uppercased()).concat("-v12-") }
				if s.starts_with("k13") { echo!("hit k13") 
					$out = $out.concat(s.drop_prefix("k13").with_ascii_uppercased()).concat("-v13-") }
				if s.starts_with("k14") { echo!("hit k14") 
					$out = $out.concat(s.drop_prefix("k14").with_ascii_uppercased()).concat("-v14-") }
				if s.starts_with("k15") { echo!("hit k15") 
					$out = $out.concat(s.drop_prefix("k15").with_ascii_uppercased()).concat("-v15-") }
				if s.starts_with("k16") { echo!("hit k16") 
					$out = $out.concat(s.drop_prefix("k16").with_ascii_uppercased()).concat("-v16-") }
				if s.starts_with("k17") { echo!("hit k17") 
					$out = $out.concat(s.drop_prefix("k17").with_ascii_uppercased()).concat("-v17-") }
				if s.starts_with("k18") { echo!("hit k18") 
					$out = $out.concat(s.drop_prefix("k18").with_ascii_uppercased()).concat("-v18-") }
				if s.starts_with("k19") { echo!("hit k19") 
					$out = $out.concat(s.drop_prefix("k19").with_ascii_uppercased()).concat("-v19-") }
				if s.starts_with("k20") { echo!("hit k20") 
					$out = $out.concat(s.drop_prefix("k20").with_ascii_uppercased()).concat("-v20-") }
				if s.starts_with("k21") { echo!("hit k21") 
					$out = $out.concat(s.drop_prefix("k21").with_ascii_uppercased()).concat("-v21-") }
				if s.starts_with("k22") { echo!("hit k22") 
					$out = $out.concat(s.drop_prefix("k22").with_ascii_uppercased()).concat("-v22-") }
				if s.starts_with("k23") { echo!("hit k23") 
					$out = $out.concat(s.drop_prefix("k23").with_ascii_uppercased()).concat("-v23-") }
				if s.starts_with("k24") { echo!("hit k24") 
					$out = $out.concat(s.drop_prefix("k24").with_ascii_uppercased()).concat("-v24-") }
				if s.starts_with("k25") { echo!("hit k25") 
					$out = $out.concat(s.drop_prefix("k25").with_ascii_uppercased()).concat("-v25-") }
				if s.starts_with("k26") { echo!("hit k26") 
					$out = $out.concat(s.drop_prefix("k26").with_ascii_uppercased()).concat("-v26-") }
				if s.starts_with("k27") { echo!("hit k27") 
					$out = $out.concat(s.drop_prefix("k27").with_ascii_uppercased()).concat("-v27-") }
				if s.starts_with("k28") { echo!("hit k28") 
					$out = $out.concat(s.drop_prefix("k28").with_ascii_uppercased()).concat("-v28-") }
				if s.starts_with("k29") { echo!("hit k29") 
					$out = $out.concat(s.drop_prefix("k29").with_ascii_uppercased()).concat("-v29-") }
				if s.starts_with("k30") { echo!("hit k30") 
					$out = $out.concat(s.drop_prefix("k30").with_ascii_uppercased()).concat("-v30-") }
				if s.starts_with("k31") { echo!("hit k31") 
					$out = $out.concat(s.drop_prefix("k31").with_ascii_uppercased()).concat("-v31-") }
				if s.starts_with("k32") { echo!("hit k32") 
					$out = $out.concat(s.drop_prefix("k32").with_ascii_uppercased()).concat("-v32-") }
				if s.starts_with("k33") { echo!("hit k33") 
					$out = $out.concat(s.drop_prefix("k33").with_ascii_uppercased()).concat("-v33-") }
				if s.starts_with("k34") { echo!("hit k34") 
					$out = $out.concat(s.drop_prefix("k34").with_ascii_uppercased()).concat("-v34-") }
				if s.starts_with("k35") { echo!("hit k35") 
					$out = $out.concat(s.drop_prefix("k35").with_ascii_uppercased()).concat("-v35-") }
				if s.starts_with("k36") { echo!("hit k36") 
					$out = $out.concat(s.drop_prefix("k36").with_ascii_uppercased()).concat("-v36-") }
				if s.starts_with("k37") { echo!("hit k37") 
					$out = $out.concat(s.drop_prefix("k37").with_ascii_uppercased()).concat("-v37-") }
				if s.starts_with("k38") { echo!("hit k38") 
					$out = $out.concat(s.drop_prefix("k38").with_ascii_uppercased()).concat("-v38-") }
				if s.starts_with("k39") { echo!("hit k39") 
					$out = $out.concat(s.drop_prefix("k39").with_ascii_uppercased()).concat("-v39-") }
		}
		$out
	}
	_ => "other"
}

## As Worker.new: the handler is an optional field, and `own!` is a closure in a record.
make = |h| {
	own!: |ev| match ev {
		A(_) => match h.?a! {
			Ok(f!) => f!(ev)
			Err(MissingField) => "unhandled"
		}
		_ => "unhandled"
	},
}

## As Worker.event!: a wildcard.
event! = |w, ev| match ev {
	H => "none"
	_ => {
		own! = w.own!
		own!(ev)
	}
}

main! = |args| {
	t = args.first() ?? "a"
	w = make({ a!: big! })
	echo!(event!(w, ev_of(t.to_str())))
	Ok({})
}
