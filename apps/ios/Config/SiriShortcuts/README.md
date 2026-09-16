# Ready-made personal shortcuts

This resource folder exists in clean checkouts. Signed shortcut files and the
bundle-specific manifest are generated locally and ignored by Git.

Run `scripts/make-siri-shortcuts.py --bundle-id YOUR_BUNDLE_ID --team-id YOUR_TEAM`
from `apps/ios` before building. This uses Apple's `shortcuts sign --mode anyone`
command, which sends the two credential-free workflows to Apple for validation.
The Mac must be signed into iCloud. Each file contains one OpenAdapt action, no
shoe keys, addresses, saved percentages, or network requests.

The app offers the Add buttons only when the manifest matches its bundle ID.
Otherwise its manual Shortcuts setup guide remains available. Generate these
files again for a different signing identity or bundle ID before distribution.
