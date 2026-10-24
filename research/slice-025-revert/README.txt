research/slice-025-revert (test agent, slice 025)
  before/          the files of the tree before the slice (the slice boundary, NEW.txt lists the added files)
  stubs/           the stub versions of the code files (what the test agent hands over). `swap.sh stubs` copies them to cli/.
  (reference/ was deleted after the manager review; mutate.py needs a green tree, so it can run again only with the code of the code agent.)
  FILES            the code files that differ between the two
  mkstub-consent.py makes stubs/cli/lib/Consent.roc from the reference Consent.roc
  mutate.py        the revert check (mutations of the reference)
