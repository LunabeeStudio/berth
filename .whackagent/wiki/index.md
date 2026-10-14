# Wiki — Index

Living knowledge base for project. Pages link to each other and to tasks via `[[wikilink]]` syntax (Obsidian-compatible). Keep current via `/wa-wiki`.

## Pages

- [[architecture]] — client/daemon split, socket protocol, modules, key decisions
- [[broker]] — slot lifecycle, FIFO scheduling, leases, reaping
- [[android-backend]] — emulator boot, reset-by-restart, prepare, gotchas
- [[cli]] — commands, exit codes, owner detection, TUI

## How to read

- Page describes domain, decision, or subsystem — *why* and *shape*, not code copy.
- Tasks reference wiki pages in `wiki:` frontmatter; wiki pages can link back to tasks.
- Code = structural truth; wiki = human narrative on top — explains what source can't tell you.