# Stasis

**A smarter battery icon for your MacBook.** Monitor power metrics, manage charge limits, and extend your battery's lifespan — all from the menu bar.

Stasis gives you real-time insight into your MacBook's power system and lets you control charging behavior directly, without relying on macOS's opaque "Optimized Battery Charging."

> **Apple Silicon only.** Tested on M1 and M4. Other Apple Silicon chips should work but are untested.
>
> Requires **macOS 14.8 – 26.3**.

![Stasis Menu Bar](https://github.com/srimanachanta/Stasis/wiki/images/FullApp.jpg)

## Installation

### Homebrew (Recommended)

```bash
brew install --cask --no-quarantine srimanachanta/tap/stasis
```

### Direct Download

1. Download from [GitHub Releases](https://github.com/srimanachanta/Stasis/releases).
2. Open the `.dmg` and drag Stasis into `/Applications`.
3. Remove the quarantine flag:
   ```bash
   xattr -cr /Applications/Stasis.app
   ```
4. Open Stasis from Applications.

## Highlights

- **Charge Limit** — Set a max charge level (50–100%) enforced at the hardware level, even through sleep.
- **Sailing Mode** — Avoid micro-charging by letting the battery float within a configurable range.
- **Automatic Discharge** — Drain to your target level while staying plugged in.
- **Heat Protection** — Pause charging when battery temperature gets too high.
- **Power Dashboard** — Live voltage, current, wattage, temperature, health, and cycle count in the menu bar.
- **Power Flow Diagram** — Sankey visualization of real-time power distribution.
- **MagSafe LED Control** — Green at limit, orange while charging.

## Documentation

For detailed feature explanations, settings walkthroughs, architecture info, and FAQ, see the **[Stasis Wiki](https://github.com/srimanachanta/Stasis/wiki)**.

## Building from Source

```bash
git clone https://github.com/srimanachanta/Stasis.git
cd Stasis
open stasis.xcodeproj
```

Requires macOS 15.7+ and Xcode with Swift 6+ support. Dependencies resolve automatically via Swift Package Manager.

## Contributing

PRs welcome. Please open an issue first for large changes.

## Acknowledgments

- [SMCKit](https://github.com/srimanachanta/SMCKit) — SMC access library
- [AsahiLinux](https://asahilinux.org/) — SMC key reverse engineering
- [Battery-Toolkit](https://github.com/mhaeuser/Battery-Toolkit) — SMC key documentation

## License

[GPL-3.0](LICENSE)
