# Pre-publication privacy review

September 22, 2026. Reviewed source revision `4995b0e`, its reachable history, and the GitHub repository's existing release/build surfaces. The repository remains private. This review does not change its visibility or rewrite history.

## Result

No private shoe credentials, provider tokens, signing keys, raw captures, or proprietary app/firmware files were found in the material checked. Two privacy items were found:

- **Commit author/committer email:** all eight existing commits contain the owner's personal address. The address is deliberately not repeated here.
- **Saved Bluetooth advertised name:** the full name from the owner's private profile appeared in three research notes. Four occurrences were replaced in the current files with the model family and a reference to the privately saved name. This is an advertisement label, not a pairing secret; its uniqueness across shoes has not been established. Its historical copies remain in Git.

Before public visibility, decide whether to replace the personal email with the account's GitHub noreply address and remove the saved Bluetooth name from historical files. Doing so requires a coordinated history rewrite and force-push; adding this cleanup commit or updating `.gitignore` does not remove old copies. No rewrite was performed by this review. The public GitHub account name, project URLs, and plugin identifier are intentional project attribution.

## Checks performed

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

After removing the advertised-name references, the full staged tree (241 files) had zero matches against the known private profile values, and the staged Gitleaks check passed. The documentation cleanup uses the GitHub noreply address for its new commit; existing commit metadata is unchanged.

## Publication boundary

This is a source/privacy review, not a guarantee that all secrets can be detected or a hardware-readiness claim. It covers the repository and the GitHub surfaces listed above, not every local file or service setting. Repeat the staged-file and history checks if source, assets, releases, or attachments change before publication. Share a reviewed Git checkout or archive, rather than the development folder with ignored files.

Calibration remains a [future feature](TASKS.md#future-feature-fit-calibration). New profiles with unknown calibration continue to block app fit commands; the review changed no Bluetooth or shoe behavior.
