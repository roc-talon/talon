app [event!] {
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.7/H2XzG4R2kci1kL4iVzvjx4CF1ohs1XYv1CMHjZzJ5TTi.tar.zst",
}

import pf.Worker
import pf.Response

worker = Worker.new({ fetch!: |_req| Ok(Response.from_text(500, "not used")) })

## A large function: a long string match. Called once, so it is inlined.
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

event! = |e| match e {
	Fetch(_) => own!(e)
	Scheduled(_) => own!(e)
	Queue(_) => own!(e)
	Email(_) => own!(e)
	Tail(_) => own!(e)
	Other(_) => own!(e)
	_ => worker.event!(e)
}

own! : Worker.Event => Worker.Outcome
own! = |e| match e {
	Fetch(req) => Respond(Response.from_text(200, "own marker literal text ${big(req.method().to_str())}"))
	_ => Unhandled
}
