# Hex streaming dictation: internal decode vs. live text

Checked 2026-11-01 against the installed Hex 3.0.0 and Hex's official Linux, CLI, and README documentation. The upstream `dev` docs are moving and may describe a newer build than the installed app.

## Finding

The selected `Parakeet Unified English` model can use incremental streaming inference on Linux when Vulkan is available. Hex's official README says Linux dictation streams while speaking with a Vulkan graphics driver, and describes the result as arriving about 100 ms after release. That wording supports low-latency processing during capture, but does not promise that partial words are displayed or pasted before the user releases the dictation shortcut. [Hex README, Linux beta](https://github.com/anomalyco/hex/blob/dev/README.md#linux-beta)

No streaming toggle is documented in Hex's Linux or CLI guides. The Linux guide describes start/stop/toggle dictation and a recording/processing pill; the CLI guide documents control and model commands but no partial-transcript preview setting. [Hex Linux guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md), [Hex CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/cli.md)

## This workstation

- `hex --version` reports `hex 3.0.0`.
- `hex status` reports `parakeet_unified_en` as the selected model.
- `hex model devices` lists an Intel UHD Graphics Vulkan device, as well as CPU inference.
- The local settings file has `transcription.model`, `language`, and `recognition_hints`, but no streaming/partial-preview setting. `hex settings list` is not implemented by this installed Linux CLI and responds that settings commands are unsupported on this OS.
- The local Hex process log contains prior `hex::gguf_session` streaming events. This is evidence that the internal streaming decode path has run; log transcript content was not inspected or copied into this note.

## What this means for kmDot

The kmDot HUD currently gets activity state from `hex status` and displays Recording or Transcribing. It does not receive partial transcript text. Hex's documented `status` interface is an activity/status view, while its documented dictation controls return or paste a completed result; the docs do not describe an API that streams partial dictation text to an external HUD.

So the likely distinction is:

1. **Model streaming:** Hex processes audio incrementally while you speak, which can make the final result arrive quickly after release.
2. **Live transcript preview:** showing evolving words in Hex's HUD or in the focused application while you are still speaking. The installed settings and documented Linux/CLI interfaces provide no switch or partial-text feed for kmDot to consume.

This is an inference from Hex's description of streaming plus its stated post-release result timing and available status/control interfaces. The selected model and this machine's Vulkan device do not point to an obvious missing toggle. There is no documented setting to turn on for visible live text in the current integration.

## Primary sources

- [Hex README: Linux beta](https://github.com/anomalyco/hex/blob/dev/README.md#linux-beta)
- [Hex Linux installation and behavior guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)
- [Hex control CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/cli.md)
