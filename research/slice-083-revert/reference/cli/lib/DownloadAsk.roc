import Answer
import Consent
import Fail
import Fx
import Mode
import Prompt
import RocInstall

## The one prompt for the required compiler downloads of a command (slice 026b, slice 039: R-NI5, R-DL1, R-DL5, R-BL3). `RocUse` and `NightlyFlow` use it. Command code.
DownloadAsk :: [].{

	## The ids of the offers that are downloads, and their sizes added.
	totals : List(RocInstall.Offer) -> { ids : List(Str), size : U64 }
	totals = |offers| offers.fold(
		{ ids: [], size: 0 },
		|sum, offer| match offer {
			Download(d) => { ids: sum.ids.append(d.id), size: sum.size + d.size }
			Present(_) => sum
		},
	)

	## One prompt for all the downloads of a run that has a baseline to download. The decision is the one of the first probe of `install` (`Consent.required_want`). `first` is the baseline that the command did not name.
	## `Consent.use_download` is the prompt (default Yes: the command names its downloads, R-DL3).
	required! : Fx, { auto : [Ask, Yes, No], mode : Mode, yes : Bool, quiet : Bool, flag : Try(Answer, [NoFlag]) }, { all : List(RocInstall.Offer), first : Str } => Try({}, Fail)
	required! = |fx, ctx, run| {
		sum = DownloadAsk.totals(run.all)
		want = |mode| Consent.required_want({ id: run.first, auto: ctx.auto, mode, yes: ctx.yes, flag: ctx.flag })
		mode = if want(ctx.mode) == NeedTty Mode.with_tty(ctx.mode, fx.tty!()) else ctx.mode
		decided = want(mode)
		match decided {
			AutoNo => Err(Consent.download_refused(run.first))
			NeedsConsent => Err(Consent.download_stop({ count: sum.ids.len(), size: sum.size }))
			Install | Ask => {
				flag = if decided == Install Ok(Yes) else Err(NoFlag)
				asked = Prompt.ask!(fx, Consent.use_download(sum), { mode, yes: ctx.yes, quiet: ctx.quiet, flag })?
				if asked.answer == Yes Ok({}) else Err(Consent.command_declined(sum.ids.first() ?? run.first))
			}
			Refuse | NeedTty => Err(Fail.new(Internal, "the download rules gave no answer for ${run.first}"))
		}
	}
}
