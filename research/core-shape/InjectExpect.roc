import Inject

## A pure fake in place of an effect, called from a top-level expect.
## `roc test` rejects this: an expect must not perform an effect.
expect {
	fake = { read!: |p| if p == "a" Ok("x\ny") else Err(NotFound) }
	Inject.count_lines!(fake, "a") == 2 and Inject.count_lines!(fake, "b") == 0
}
