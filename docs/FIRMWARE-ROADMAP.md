# Firmware support and research roadmap

Updated September 23, 2026. This page reports the newer iOS **0.1.0 (12) development candidate** and the proposed next research phase. Its app changes are not yet migrated into the published source on `master`, and build 12 has not been uploaded to TestFlight. Older dated verification reports describe earlier builds.

## Firmware below 2.0.0

The iOS candidate admits strictly parsed **M firmware from 1.1.0 through 2.4.3**, including older 1.x shoes. It does not treat every version below 2.0.0 as supported: versions below 1.1.0, unfamiliar suffixes/formats, and revisions above 2.4.3 remain restricted.

| Firmware | Movement strategy in the iOS candidate | Evidence |
| --- | --- | --- |
| **1.4.1M** | Direct position request after a quiet, stable-position check | Both owned BB 2.0 shoes authenticated, returned status, and completed raw **0 → 30 → 0** with matching position readbacks, no preparatory Stop and no protection event in those sequences. |
| **2.4.3M** | Existing Stop-before-target sequence | Existing Auto Max authentication/control evidence; that movement sequence is preserved. |
| Other admitted **M** revisions | Same direct-position strategy as 1.4.1M | Compatibility policy and synthetic tests; physical behavior is not established for every revision. |
| Outside the admitted range or unfamiliar format | Restricted compatibility checks | No motor/settings support inferred from a version read. |

The sequence is selected independently for each shoe, including mixed-firmware pairs. Acknowledgements, completion validation, position readback, battery/charger checks, and fault handling remain required. Commands are not automatically replayed after a failure. Percentages use each shoe's measured range and are not measurements of force.

Firmware capability and implemented app features are separate. Unsupported controls stay hidden: for example, **Quick Unlace is absent on 1.4.1M**. Basic Auto-Lace is distinct from Quick Unlace and later activity APIs. Setup leaves Auto-Lace off; enabling it uses the fit stored in the shoes, separately from OpenAdapt's Move and Chill presets. Sharing the older movement sequence does not enable newer features on older firmware. This policy applies to the iOS candidate, not automatically to the Omarchy client.

The candidate passes **185 core tests**, four targeted Debug UI flows, and a clean-install Release UI check. Its signed archive and distribution export pass local packaging checks. The BB 2.0 UI flow is synthetic; the physical 0 → 30 → 0 capture does not include maximum search or prove complete first setup on a new pair. Broader hardware validation and publication of the app changes remain separate work.

## Proposed next step: PCB and bootloader research

The goal is to understand the shoe electronics and firmware update path well enough to maintain shoes beyond the original app's lifetime. [Nike's retirement notice](https://www.nike.com/help/a/adapt-app) provides the official app context; it does not establish a universal firmware image or upgrade route.

1. **Map the PCB.** Identify the controller, flash, board revisions, power connections, and candidate debug/test pads. Establish electrical requirements and whether nondestructive read access is possible. Keep board-specific findings separate from assumptions about all Adapt models.
2. **Understand boot and recovery.** Determine the bootloader layout, image validation/signing, read protection, and recovery behavior. Establish what can be backed up and restored without erasing pairing, calibration, or device-specific data before any write experiment.
3. **Reconstruct OTA updating.** Investigate update discovery, firmware package format, model/hardware targeting, version checks, Bluetooth transfer, integrity verification, activation, and interrupted-update recovery. PCB access may help explain this path; it does not by itself prove that an OTA package can be created or accepted.
4. **Assess upgrades toward 2.4.3M.** Treat **2.4.3M as the latest firmware observed and tested by this project**, and the current research target. A universal latest-release claim, availability of an authentic installable image, and compatibility with every board/model are not established. The ambition is to bring supported older shoes to that level where compatibility permits; a single image for all shoes cannot be assumed.
5. **Explore original custom firmware.** Investigate whether the boot chain permits owner-installed firmware and whether a recoverable development path can be built. Motor limits, protection responses, thermal/power behavior, calibration, and physical-button operation would need independent validation before everyday use. Custom firmware is a longer-term possibility, not an available feature or a guaranteed outcome of OTA research.

Start with inspection and documented evidence. Destructive reads, unlocks that erase flash, firmware writes, and motor experiments require their own concrete test plan; this roadmap does not initiate them. Raw dumps, proprietary firmware, captures, pairing keys, and unique device data remain outside the repository. Publish original findings, original code, and synthetic tests.

## Milestones

- [x] Confirm ordinary direct movement on both owned BB 2.0 shoes running 1.4.1M.
- [x] Prepare and test the iOS compatibility strategy while preserving 2.4.3M behavior.
- [ ] Migrate the reviewed app changes onto the cleaned public source history and distribute the candidate.
- [ ] Validate complete first setup and recovery on another 1.4.1M pair, then additional firmware/model combinations.
- [ ] Document the PCB, bootloader, read-access limits, and recovery route.
- [ ] Establish authentic firmware availability and model-specific OTA requirements.
- [ ] Demonstrate a recoverable update on compatible development hardware.
- [ ] Assess feasibility of original custom firmware.

There is currently **no OpenAdapt OTA updater, universal upgrade path, or custom firmware release**.
