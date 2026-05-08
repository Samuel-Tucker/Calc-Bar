# Calc Bar

A tiny macOS menu bar calculator for people who keep reaching for the built-in Calculator app and thinking: this is not quite what I wanted.

Calc Bar opens with a global hotkey, accepts real numpad input, can stay pinned above other apps, and keeps the calculation visible as you type.

![Calc Bar floating above another app](Docs/calc-bar-menu-bar.jpg)

![Calc Bar pinned on the desktop](Docs/calc-bar-pinned.jpg)

## What It Does

- Lives in the macOS menu bar with no Dock icon.
- Opens and closes with `Control + Option + C`.
- Works with the number row and numeric keypad.
- Shows expressions as you type, like `5+5`, then shows the result after `Enter`.
- Turns the output box green when a calculation is complete.
- Can be pinned so it stays above other windows and apps.
- Can be dragged around the screen when pinned.

## Quick Start

Clone the repo:

```sh
git clone https://github.com/Samuel-Tucker/Calc-Bar.git
cd Calc-Bar
```

Run it during development:

```sh
swift run CalcBar
```

Build a `.app` bundle:

```sh
Scripts/build-app.sh
open ".build/Calc Bar.app"
```

The app bundle is written to:

```text
.build/Calc Bar.app
```

The local bundle is ad-hoc signed with `codesign --sign -`, so it works well for local builds and testing. It is not notarized, so other Macs may still show a Gatekeeper warning.

## Controls

Open the calculator and click `Calc Bar ▾` in the header for the built-in cheat sheet.

| Action | Shortcut |
| --- | --- |
| Open / close | `Control + Option + C` |
| Close panel | `Esc` or `×` |
| Keep on top | Pin button |
| Move pinned calculator | Drag the panel |
| Digits | `0-9` or numeric keypad |
| Operators | `+`, `-`, `x`, `/` |
| Calculate | `Enter`, `Return`, or `=` |
| Clear | `C` or `Delete` |

## Development

Requirements:

- macOS
- Swift toolchain
- Xcode or Apple Command Line Tools

Useful commands:

```sh
swift build
swift run CalcBar
Scripts/build-app.sh
Scripts/package-release.sh 0.1.0
```

Package a GitHub Release zip:

```sh
Scripts/package-release.sh 0.1.0
```

That writes:

```text
.build/dist/Calc-Bar-0.1.0-macos.zip
.build/dist/Calc-Bar-0.1.0-macos.zip.sha256
```

Regenerate the app icon after changing `Scripts/generate-icon.swift`:

```sh
swift Scripts/generate-icon.swift
iconutil -c icns Resources/AppIcon.iconset -o Resources/CalcBar.icns
```

If you want to reset the built app:

```sh
pkill -x CalcBar
Scripts/build-app.sh
open ".build/Calc Bar.app"
```

## Project Structure

```text
Package.swift
Info.plist
Scripts/build-app.sh
Sources/CalcBar/
  AppDelegate.swift
  CalculatorEngine.swift
  CalculatorPanelController.swift
  GlobalHotKey.swift
  KeyCode.swift
  main.swift
Resources/
  CalcBar.icns
  AppIcon.iconset/
```

## Forking Notes

This is intentionally small and boring Swift/AppKit. Fork it, change the layout, swap the hotkey, add themes, or turn it into the calculator macOS should have shipped with.

Things worth improving:

- Preferences for custom hotkeys.
- Light/dark themes.
- Calculation history.
- Developer ID signing and notarization.
- A Homebrew cask once release zips are published.

## Distribution Notes

You can publish release zips without an Apple Developer account:

```sh
Scripts/package-release.sh 0.1.0
```

Attach the generated zip from `.build/dist/` to a GitHub Release.

Without an Apple Developer account, the app can be ad-hoc signed but not Developer ID signed or notarized. That means users may need to allow it manually in macOS Privacy & Security after downloading.

## License

MIT. See [LICENSE](LICENSE).
