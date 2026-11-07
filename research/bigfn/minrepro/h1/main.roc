Event : [Fetch(Str), Scheduled(Str), Queue(Str), Email(Str), Tail(Str), Other(Str), Rpc(Str), Manifest]
Outcome : [Respond(Str), Unhandled, Reply(Str)]

big : Str -> Str
big = |t| match t {
	"k0" => "${t} marker text number 00 for the copy count ${t}"
	"k1" => "${t} marker text number 01 for the copy count ${t}"
	"k2" => "${t} marker text number 02 for the copy count ${t}"
	"k3" => "${t} marker text number 03 for the copy count ${t}"
	"k4" => "${t} marker text number 04 for the copy count ${t}"
	"k5" => "${t} marker text number 05 for the copy count ${t}"
	"k6" => "${t} marker text number 06 for the copy count ${t}"
	"k7" => "${t} marker text number 07 for the copy count ${t}"
	"k8" => "${t} marker text number 08 for the copy count ${t}"
	"k9" => "${t} marker text number 09 for the copy count ${t}"
	"k10" => "${t} marker text number 10 for the copy count ${t}"
	"k11" => "${t} marker text number 11 for the copy count ${t}"
	"k12" => "${t} marker text number 12 for the copy count ${t}"
	"k13" => "${t} marker text number 13 for the copy count ${t}"
	"k14" => "${t} marker text number 14 for the copy count ${t}"
	"k15" => "${t} marker text number 15 for the copy count ${t}"
	"k16" => "${t} marker text number 16 for the copy count ${t}"
	"k17" => "${t} marker text number 17 for the copy count ${t}"
	"k18" => "${t} marker text number 18 for the copy count ${t}"
	"k19" => "${t} marker text number 19 for the copy count ${t}"
	"k20" => "${t} marker text number 20 for the copy count ${t}"
	"k21" => "${t} marker text number 21 for the copy count ${t}"
	"k22" => "${t} marker text number 22 for the copy count ${t}"
	"k23" => "${t} marker text number 23 for the copy count ${t}"
	"k24" => "${t} marker text number 24 for the copy count ${t}"
	"k25" => "${t} marker text number 25 for the copy count ${t}"
	"k26" => "${t} marker text number 26 for the copy count ${t}"
	"k27" => "${t} marker text number 27 for the copy count ${t}"
	"k28" => "${t} marker text number 28 for the copy count ${t}"
	"k29" => "${t} marker text number 29 for the copy count ${t}"
	"k30" => "${t} marker text number 30 for the copy count ${t}"
	"k31" => "${t} marker text number 31 for the copy count ${t}"
	"k32" => "${t} marker text number 32 for the copy count ${t}"
	"k33" => "${t} marker text number 33 for the copy count ${t}"
	"k34" => "${t} marker text number 34 for the copy count ${t}"
	"k35" => "${t} marker text number 35 for the copy count ${t}"
	"k36" => "${t} marker text number 36 for the copy count ${t}"
	"k37" => "${t} marker text number 37 for the copy count ${t}"
	"k38" => "${t} marker text number 38 for the copy count ${t}"
	"k39" => "${t} marker text number 39 for the copy count ${t}"
	_ => "the default answer of the big function"
}

header! : Str, Str => Try(Str, [NotFound])
header! = |req, name| {
	echo!("header ${name}")
	if req.starts_with(name) Ok(req.drop_prefix(name)) else Err(NotFound)
}

fetch! : Str => Str
fetch! = |req| match header!(req, "x-0") {
	Ok(t) => "own marker literal text ${big(t)}"
	Err(_) => "no header in the request"
}

other! : Event => Outcome
other! = |e| match e {
	Rpc(s) => {
		echo!(s)
		Reply(s)
	}
	_ => Unhandled
}

event! : Event => Outcome
event! = |e| match e {
	Fetch(_) | Scheduled(_) | Queue(_) | Email(_) | Tail(_) | Other(_) => own!(e) #OR
	_ => other!(e)
}

own! : Event => Outcome
own! = |e| match e {
	Fetch(req) => Respond(fetch!(req))
	_ => Unhandled
}

event_of : Str -> Event
event_of = |t| match t {
	"f" => Fetch(t)
	"s" => Scheduled(t)
	"q" => Queue(t)
	"e" => Email(t)
	"t" => Tail(t)
	"o" => Other(t)
	"r" => Rpc(t)
	_ => Manifest
}

main! = |args| {
	t = args.first() ?? "f"
	echo!(Str.inspect(event!(event_of(t.to_str()))))
	Ok({})
}
