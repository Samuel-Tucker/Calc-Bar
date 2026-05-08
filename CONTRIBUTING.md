# Contributing

Calc Bar is a small Swift/AppKit app. Keep changes focused, easy to review, and friendly to people who want to fork it.

## Local Setup

```sh
swift build
swift run CalcBar
```

Build the app bundle:

```sh
Scripts/build-app.sh
open ".build/Calc Bar.app"
```

## Pull Requests

- Explain the user-facing behavior you changed.
- Include screenshots or a short screen recording for UI changes.
- Run `swift build` before opening a PR.
- Avoid committing `.build/`, `.env`, or local Xcode state.

## Design Direction

Calc Bar should stay keyboard-first, compact, and obvious. The menu bar app should feel like a utility, not a dashboard.
