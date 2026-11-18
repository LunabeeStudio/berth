---
issue: BERTH-19
phase: in-progress
type: feature
wiki: [architecture]
note:
created: 2026-11-18
---

## Context / Decisions

Ticket idea (2026-11-18): "Add right click menu with same stuff as ~/dev/switchboard". Switchboard is a sibling menu bar app. Its `StatusItemController` opens an `NSMenu` on a right click or a Control-click: the version (disabled), a separator, Open on GitHub, Launch at Login (checkmark), a separator, Quit. A left click still toggles its popover. Grilled by `/wa-autopilot`, so every decision below is an autopilot assumption for the user to confirm.

### Trigger

- A right click on the berth-bar status item, or a left click with Control held, opens the menu. Any other left click toggles the panel, as today. (autopilot assumption: same trigger as Switchboard)
- If the panel is open, it closes before the menu opens. Closing the menu leaves the panel closed.
- VoiceOver presses the button without a right click, so the button also gets an accessibility custom action "Show Menu" that opens the menu, as in Switchboard.
- The menu is attached to the status item for that one click (`item.menu = menu`, `button.performClick(nil)`, `item.menu = nil`), so the system places it and highlights the button, and a later left click opens the panel again. Same mechanism as Switchboard.

### Items, in order

1. `berth <BerthVersion.current>`, disabled. A debug build shows `berth dev`.
2. Separator.
3. `Open on GitHub`: opens `https://github.com/LunabeeStudio/berth` with `NSWorkspace`.
4. `Launch at Login`: checkmark on when `LaunchAtLogin.isEnabled`. Picking it toggles `LaunchAtLogin.isEnabled`, so it writes or removes the same `com.berth.bar` plist as the panel checkbox. `launchAtLogin.refresh()` runs before the menu is built, so a plist changed outside the app (`berth bar install`) shows the right state.
5. Separator.
6. `Quit berth-bar`, key equivalent `q`: `NSApp.terminate(nil)`, same as the panel's Quit button, so the mirror cleanup in `applicationWillTerminate` still runs. (autopilot assumption: "berth-bar" and not "berth", so nobody reads it as stopping the daemon)

- Auto update is not in the menu. The request names Switchboard's items, and Switchboard has no auto update. It stays as the panel checkbox. (autopilot assumption)
- The panel keeps its Launch at login, Auto update and Quit controls. Switchboard keeps them in its panel too. (autopilot assumption)

### Where the code lives

- `Sources/BerthBar/MenuBar/StatusMenu.swift` (new): builds the `NSMenu` from plain inputs (the version string and the launch at login state) and takes the target for the actions. Being pure, it is unit tested without a status item.
- `Sources/BerthBar/MenuBar/StatusItemController.swift`: sends the action on `.leftMouseUp` and `.rightMouseUp`, routes the click, adds the accessibility action, and holds the action methods (open repository, toggle launch at login, quit).
- The repository URL is a constant in BerthBar. Only the bar uses it.
- No daemon, protocol or CLI change.

### Proof

- Unit tests on `StatusMenu`: item titles and order, the disabled version item, the checkmark following the launch at login state, the `q` key equivalent on Quit, and each enabled item having an action and a target.
- `CLAUDE.md#Desktop proofs` forbids synthetic clicks and `AXPress` on berth-bar, so no agent opens the menu on screen. An agent may launch its own debug berth-bar with a short `BERTH_HOME`, check that it runs and that the frontmost app does not change, then stop it by pid. A human checks the right click, the Control-click, each item, and that a left click still opens the panel.

## Acceptance criteria

- A right click on the berth-bar status item opens a menu with, in order: `berth <version>` (disabled), a separator, `Open on GitHub`, `Launch at Login`, a separator, `Quit berth-bar`.
- A left click with Control held opens the same menu.
- A plain left click still opens and closes the panel, both before and after the menu has been used.
- When the panel is open, a right click closes it and opens the menu.
- `Open on GitHub` opens https://github.com/LunabeeStudio/berth in the default browser.
- `Launch at Login` shows a checkmark exactly when `~/Library/LaunchAgents/com.berth.bar.plist` exists. Picking it creates or removes that plist, and the panel's Launch at login checkbox shows the same state the next time the panel opens.
- `Quit berth-bar` quits berth-bar and stops the scrcpy mirrors it started, like the panel's Quit button. The daemon keeps running.
- The status item exposes a "Show Menu" accessibility action that opens the menu.
- Unit tests on the menu builder cover the item order, the disabled version item, the checkmark for both launch at login states, and the Quit key equivalent. `swift build` has no new warning, and `swift test` is green.
