# Pre-publication privacy review

September 22, 2026. Reviewed the source, its reachable history, and the GitHub repository's existing release/build surfaces. The owner subsequently authorized removing both identified privacy items from history. The repository remains private.

## Result

No private shoe credentials, provider tokens, signing keys, raw captures, or proprietary app/firmware files were found in the material checked. Both identified privacy items have now been removed from the working repository's Git objects and the history obtained by a fresh GitHub clone:

- **Commit author/committer email:** the eight original commits used a personal address. All author and committer fields now use the account's GitHub noreply address. The address is also configured locally for future commits in this checkout.
- **Saved Bluetooth advertised name:** the full name from the owner's private profile appeared in three research notes. Four occurrences were removed from current files, and the name has now been replaced throughout historical files. This is an advertisement label, not a pairing secret; its uniqueness across shoes has not been established.

The rewrite used git-filter-repo 2.47.0 across all three local branches, followed by an explicit force-with-lease push of `master`. All nine commits present at rewrite time were rewritten; no commits were dropped. A verified, access-restricted Git bundle backup remains outside the repository. The public GitHub account name, project URLs, and plugin identifier are intentional project attribution.

**Remaining GitHub-side cleanup:** a cache/garbage-collection request was submitted to GitHub Support on September 23, 2026. The open ticket and complete follow-up report were verified; the receipt and ticket link are retained privately outside the repository. The request covers the old root, former tip, and two obsolete website commits that still resolved through GitHub's commit API after their branch references were removed. GitHub has not yet confirmed removal. Keep the repository private while resolving this. See [GitHub's removal guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository#fully-removing-the-data-from-github).

The obsolete website branch was deleted and only its website diff was replayed onto cleaned history using noreply metadata. The replacement branch, `codex/openadapt-site`, and its current pull request must be preserved. The Support request explicitly asks to retain both the current clean history and the repository's private visibility.

## Initial audit

| Surface | Scope and result |
| --- | --- |
| Git source and history | 240 tracked files, eight commits, 307 distinct historical file blobs across all local refs. Published remote refs contain only `master`; there are no tags. Gitleaks 8.30.1, run locally with redacted output and all refs, reported no leaks. |
| Known private data | Compared historical files against the locally available owner profile and iOS owner seed, including application keys, shoe addresses and advertised names. Checked textual values and raw/base64 key representations. No key/address matches. The advertised name matched three historical files, as described above. |
| Personal metadata in text | Checked user home paths, email, private-network addresses, Bluetooth addresses, private-key headers and token patterns. Bluetooth-address candidates were synthetic test/demo values. Git commit metadata contains the personal email described above; the separate exact-value check found the saved advertised name. |
| Images and documents | Inspected metadata and ran local OCR on all 52 historical PNG assets; inspected both vector PDFs. No personal author/device/location metadata or credential matches were found. Selected developer, panel and brand images were also viewed. The sneaker artwork is the project's original shared mark. |
| Video | The sole tracked video is a roughly three-second OpenAdapt Simulator demo with no audio. Sampled frames show demo fit controls; container metadata contains encoder details, without personal/device/location fields. |
| GitHub surfaces | No releases, release assets, issues/PRs, or Actions artifacts existed at review time. Downloaded logs for both existing workflow runs were scanned locally with Gitleaks and compared against known private profile values; no leaks or owner-profile matches were found. |
| Local-only material | Private profiles, raw phone/radio captures, proprietary APK/decompiled material, and signed personal Shortcuts are absent from tracked paths throughout the reviewed history. Existing ignore rules keep these local. |
| iOS personalization | The tracked build configuration has no development team or owner profile enabled. The optional local seed is ignored, opt-in, and Debug-only; the app reads it only under `DEBUG`. Release exclusion was previously checked in the [build verification](ios/VERIFICATION.md). No new app build or installation was needed for this documentation review. |

Synthetic crypto vectors and the fixed enrollment protocol constant are part of the implementation, not the owner's saved pairing secrets. Sanitized research notes include protocol behavior and historical fit-limit measurements; the raw recordings and proprietary implementations remain excluded.

After the initial advertised-name cleanup, the full staged tree (241 files) had zero matches against the known private profile values, and the staged Gitleaks check passed.

## History rewrite verification

- Compared every stored Git object in the working repository, including unreachable objects, against the personal email and known private profile values. All 426 objects passed with zero matches.
- Repeated that check on a fresh mirror clone fetched from GitHub after the force-push: nine reachable commits, 426 objects, zero matches, and only noreply author/committer email fields.
- Gitleaks reported no leaks across the rewritten history; Git's integrity check passed.
- The current source tree was byte-for-byte identical before and after rewriting. Local owner profiles and private build configuration retained their original file hashes. No app rebuild, installation, Bluetooth command, or credential change occurred.
- The separately inspected Omarchy research checkout still has uncommitted changes and private Codex checkpoint refs. It was left unchanged. Preserve that work and migrate it onto the rewritten history before any future push; do not merge the old history back into the cleaned repository. Private archival bundles are also not publication sources.

## Publication boundary

This is a source/privacy review, not a guarantee that all secrets can be detected or a hardware-readiness claim. It covers the repository and the GitHub surfaces listed above, not every local file or service setting. Repeat the staged-file and history checks if source, assets, releases, or attachments change before publication. Share a reviewed Git checkout or archive, rather than the development folder with ignored files.

Calibration remains a [future feature](TASKS.md#future-feature-fit-calibration). New profiles with unknown calibration continue to block app fit commands; the review changed no Bluetooth or shoe behavior.
