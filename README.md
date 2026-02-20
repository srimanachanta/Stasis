# Stasis

**A smarter battery icon for your MacBook.** Monitor power metrics, manage charge limits, and extend your battery's lifespan — all from the menu bar.

Stasis gives you real-time insight into your MacBook's power system and lets you control charging behavior directly, without relying on macOS's opaque "Optimized Battery Charging."

> **Apple Silicon only.** Tested on M1 and M4. Other Apple Silicon chips should work but are untested.
>
> Requires **macOS 14.8 – 26.3**.

<!-- Screenshot: menu bar dropdown showing battery info, power metrics, and Sankey diagram -->
![Stasis Menu Bar](Media/FullApp.jpg)

## Installation

### Homebrew

<!-- TODO: Fill in tap and cask name -->
```bash
brew install --cask placeholder/tap/stasis
```

### Direct Download

Download the latest `.dmg` from [GitHub Releases](https://github.com/srimanachanta/Stasis/releases).

## Features

<details>
<summary><strong>Real-Time Power Dashboard</strong></summary>

The menu bar dropdown shows live power data pulled directly from the SMC and IOKit:

- Battery percentage (macOS-calibrated or raw hardware value)
- Power source and time remaining
- Battery and adapter voltage, current, and wattage
- System power draw
- Battery temperature, health, and cycle count
- System uptime

Every metric is individually toggleable in settings.

</details>

<details>
<summary><strong>Power Flow Visualization</strong></summary>

A Sankey diagram in the menu shows how power flows through your system in real time — from adapter and battery to system load. See at a glance whether your MacBook is charging, discharging, or running on pass-through power.

![Power Flow Diagram](Media/PowerSankeyView.png)

</details>

<details>
<summary><strong>Charge Limit Management</strong></summary>

Set a maximum charge level (50–100%) to reduce long-term battery wear. When the limit is reached, Stasis inhibits charging at the hardware level via SMC writes through a privileged helper daemon.

- **Automatic Discharge** — Optionally force the system to run on battery power when above the limit, even while plugged in.
- **Sailing Mode** — Instead of toggling charging on and off around the limit, Stasis holds the battery at your target by floating on adapter power. A configurable threshold (1–20% below the limit) controls when charging resumes.
- **Charge Limit Override** — Temporarily charge to 100% without disabling charging management. One click in the menu.

<!-- Screenshot: Settings window, Charging tab -->
![Charging Settings](Media/SettingsView.png)

</details>

<details>
<summary><strong>Heat Protection</strong></summary>

When battery temperature exceeds a configurable threshold (30–50 C), Stasis automatically pauses charging regardless of the current charge level. Charging resumes once the battery cools down.

</details>

<details>
<summary><strong>MagSafe LED Control</strong></summary>

On supported MacBooks, Stasis overrides the MagSafe LED to reflect charging state:

- **Green** — at or above the charge limit
- **Orange** — actively charging
- **Configurable during heat protection** — off, green, orange, or blinking orange

</details>

<details>
<summary><strong>Localization</strong></summary>

Stasis is available in:

- English
- German
- Spanish
- Japanese

Translations are community-contributed. Some strings may be incomplete in non-English languages.

</details>

## How It Works

Stasis uses a three-process architecture:

| Component | Privilege | Role |
|---|---|---|
| **Stasis.app** | User | UI, business logic, menu bar |
| **helper.xpc** | User | SMC reads (voltage, current, power) |
| **charging-helper** | Root | SMC writes (charge inhibit, discharge, MagSafe LED) |

The privileged helper is a LaunchDaemon registered through `SMAppService`. When you enable "Manage Charging" in settings, macOS will prompt you to approve Stasis in **System Settings > Login Items**. The daemon only runs while charging management is active and resets all SMC keys to defaults when it stops.

SMC reads happen through an unprivileged XPC service embedded in the app bundle. Power metrics are polled at 1-second intervals only while the menu is open.

## Building from Source

**Requirements:**
- macOS 15.7+
- Xcode with Swift 6+ support

```bash
git clone https://github.com/srimanachanta/Stasis.git
cd Stasis
open stasis.xcodeproj
```

Build and run the `stasis` scheme in Xcode. The project uses Swift Package Manager for dependencies, which Xcode resolves automatically.

## Contributing

PRs welcome. Please open an issue first for large changes.

## Acknowledgments

- [SMCKit](https://github.com/srimanachanta/SMCKit) — SMC access library
- [AsahiLinux](https://asahilinux.org/) — SMC key reverse engineering
- [Battery-Toolkit](https://github.com/mhaeuser/Battery-Toolkit) — SMC key documentation

## License

[GPL-3.0](LICENSE)
