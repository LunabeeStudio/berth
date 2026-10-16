---
# whackagent config — written by /wa-setup, edit freely.
discussion_language: en        # language Claude talk to you in
primary_language: swift        # swift | kotlin | typescript | generic → picks convention pack;
                               # other language → generic
project_kind: cli              # app | web | server | cli | package → picks architecture module
                               # app = mobile/desktop GUI; package = library/SDK

paths:                         # WHERE whackagent keep each file kind. Skills refer as
                               # {backlog} {tasks} {wiki} {reports} {conventions} {worktrees} — never literal path.
                               # Relative path resolve from repo root (sibling repo: ../other/docs).
                               # Config versioned + shared → NEVER user-specific absolute path
                               # (/Users/<name>, /home/<name>, ~): break every other machine.
                               # Team share folder → point at committed, browsable one —
                               # `docs/wiki` readable on GitHub, `.whackagent/wiki` not.
                               # Missing key → default below; old config still work.
  backlog: .whackagent/BACKLOG.md
  tasks: .whackagent/tasks
  wiki: .whackagent/wiki
  reports: .whackagent/reports          # run reports — local, gitignored by /wa-setup
  conventions: .whackagent/conventions  # convention modules copied here by /wa-setup
  worktrees: ../berth-worktrees  # task worktrees (branch.worktree, /wa-autopilot). <repo> = repo
                               # folder name. Resolve from MAIN checkout root, even when setup run
                               # from worktree — keep relative. MUST sit OUTSIDE repo: nested
                               # checkout get indexed, grepped, globbed by builds.
                               # `.whackagent/config.md` itself NOT configurable: carry these
                               # paths, must sit at known spot.
                               # Move path after setup → move files too; no back-fill.

backlog:
  provider: github             # WHERE tickets live — providers/CONTRACT.md.
                               #   local  — {backlog} + task files, one agent (default).
                               #   github — GitHub Project + issues, many agents/worktrees.
                               #     Settings in repo variables (wa-backlog provision), not here.
                               #     Forces branch.per_task: true, branch.base = close.target
                               #     (named branch). Ignores close.strategy for tickets:
                               #     /wa-validate marks PR ready, /wa-close merges on your yes.
  milestones: []               # OPEN release scopes (iteration, version), OLDEST FIRST. Local provider
                               # only — github read repo milestones. New task join LAST entry →
                               # new work never grow current/past scope. You own list: add entry
                               # = open next scope, remove when shipped (tasks keep milestone:).
                               # Empty → tasks get no milestone.

release:
  doc: docs/RELEASING.md       # WHERE release flow written — `path` or `path#Heading`
                               # (docs/RELEASING.md, {wiki}/release.md, CLAUDE.md#Releasing).
                               # /wa-release follow it step by step, never invent flow.
                               # Empty → /wa-release search markdown, else interview you + write it.

review:
  when: on_validation          # WHEN wa-verifier run.
                               #   on_validation — once, at /wa-validate: your green light = feature
                               #     match spec, THAT fire review over whole diff (code + every
                               #     feedback round). Coding + feedback stay fast; nothing reviewed
                               #     while still moving.
                               #   each_round — also after /wa-code and every /wa-feedback fix.
                               #     Catch drift earlier, cost verifier round each time. /wa-validate
                               #     still run final pass.
                               # Either way no task close unreviewed — /wa-close refuse task
                               # verifier never saw. /wa-autopilot ignore this key: always run
                               # /wa-validate itself after green runtime check.
  inline_micro_fixes: true     # /wa-feedback may apply MICRO-fix itself instead of spawn
                               # implementer (~50k tokens context for one-liner). Bounded: ≤2 files,
                               # ≤~20 lines, no new file/type/folder, no layer or public-API change.
                               # Bigger or any doubt → wa-implementer.
                               # false → every change through implementer, any size.
  autofix: true                # wa-code verify phase re-dispatch implementer until clean
  public_doc: false            # require doc on public API — flip false per company
  modules: [style.md, elegance.md, testing.md, architecture-global.md, architecture-package.md]
                               # what single wa-verifier load before judging. Setup write what
                               # it actually copied: UI module (swiftui.md, compose.md) only if
                               # project use that toolkit, architecture-package.md for non-app
                               # kinds, single <lang>.md for one-file packs. Paths relative to {conventions}.
                               # ONE verifier, not one per lens: isolated agent cost ~50k tokens
                               # context before reading a line, every lens judge same diff vs
                               # same rulebook — splitting pay twice, leave duplicate findings.
                               # Sweep style, elegance, structure, correctness in one pass,
                               # report which ran.
                               # Legacy `categories: {conventions: [...], correctness: []}` read as
                               # union of its lists.

build:                         # how THIS project build — project win over plugin default
  command: ""                  # e.g. "make build", "./scripts/build.sh", "./gradlew assembleDebug".
                               # Empty → build tool detected in repo: XcodeBuildMCP (Xcode project),
                               # ./gradlew (Gradle), swift build (SwiftPM), package.json scripts,
                               # cargo, go, dotnet, mvn, make… — see wa-implementer.
  test_command: ""             # e.g. "make test". Empty → same tool's test task.

tools: []                      # project tools whackagent run — lint, static analysis, format check.
                               # Commands, never hardcoded per language. Each entry:
                               #   - name: detekt
                               #     run: ./gradlew detekt                 # whole project; exit ≠ 0 = fail
                               #     fix: ./gradlew detekt --auto-correct  # optional: tool own fixer,
                               #                                           # implementer try before hand fix
                               #     when: [code, validation]
                               # when — code: implementer run after build + tests, every brick +
                               #   feedback round; failure in changed file = red build.
                               #   validation: /wa-validate run before verifier; failures join
                               #   autofix loop as `tool:<name>` findings.
                               # Failure only in untouched file = pre-existing: reported,
                               # never fixed — not task scope.
                               # Empty → no tool run.

verify:                        # runtime check — implementer drive app it just built
  mode: always                 # WHO exercise app after green build:
                               #   autopilot — agent drive it in /wa-autopilot only (nobody there
                               #     to test); attended /wa-code + /wa-feedback stop at build + tests,
                               #     YOU validate by testing app. Default for anything runnable.
                               #   always — agent drive it every run, attended or not.
                               #   off — agent never drive it; build + tests whole proof.
                               # Under `autopilot` and `off` implementer may STILL launch app when
                               # can't write feature without seeing it run (reproduce bug, judge
                               # layout, follow nav flow). That = implementation, not proof: drive
                               # minimum needed, say so in NOTES.
                               # Legacy `enabled: true` / `false` read as `always` / `off`.
  platform: cli                # WHAT gets driven, which tool (list allowed: [ios, android]):
                               #   ios     — XcodeBuildMCP (simulator), mobile-mcp (device)
                               #   android — mobile-mcp (emulator or device)
                               #   web     — browser automation MCP (Playwright, Chrome)
                               #   desktop — desktop/computer-use MCP when configured
                               #   server  — start it, hit endpoints (curl), read responses + logs
                               #   cli     — run binary with task inputs, check output + exit code
                               #   none    — library, nothing to drive; build + tests whole proof
                               # Legacy `both` read as [ios, android].
  target: local                # simulator | emulator | device | browser | local

commit:
  auto_commit_after_validation: false   # may Claude commit once YOU validate feature?
                               # (name kept for old configs: gate commit /wa-close make)
  author_name: ""              # commits use this — never "Claude". Empty (default) → committer's own
  author_email: ""             # `git config user.name` / `user.email` at commit time, never made up.
                               # Config versioned + shared → no personal identity here: teammates'
                               # commits would carry it. Set only for shared identity (team bot).

branch:
  per_task: true               # /wa-code work on own branch per task, not current one
  worktree: true               # with per_task: each task branch in own git worktree
                               #   at {worktrees}/<slug> — main checkout never switch branch, tasks
                               #   open side by side. Cost: cold build per worktree, open IDE there.
  prefix: "wa/"                # branch name: <prefix><slug> → wa/login-apple
  base: main                   # fork point: current | main | <branch name>
                               # GitHub provider: named branch, same as close.target
  sprint_prefix: "sprint/"     # task with `sprint:` branch off SPRINT branch, not base:
                               #   sprint/login-refacto ← created from base: on sprint's first task
                               #   wa/login-apple       ← forked from it, merged back by /wa-close
                               # So sprint task 3 see task 1 work — same screen, no blind conflict.
                               # Created by first who need it: /wa-code step 0 or /wa-autopilot
                               # wave setup. Empty string → sprint no branch, tasks use base:.
  tracks: {}                   # long-shot features on own long-lived trunk beside base:
                               #   {server: develop_synchro} — key = milestone title, value = branch.
                               # Task in that milestone fork from + land on that branch instead of
                               # base:/close.target. New tasks never join by default; agent
                               # suggest, you decide. Rules: wa-board → Tracks. Needs per_task.
                               # You own list. Empty (default) → no track, flow unchanged.
  checkout_next: true          # after /wa-close commit, hop to next task branch (worktree mode:
                               #   create its worktree)
                               # (only when per_task AND commit.auto_commit_after_validation)

close:                         # WHERE work land when /wa-close finish task. Sprint task always
                               # merge into sprint branch first — this block say what happen to
                               # branch with nowhere left to go (standalone task, or sprint
                               # branch itself once last task close).
  strategy: nothing            # nothing — /wa-close stop after commit, branch left alone.
                               #   YOU open PR. Safest, default.
                               # pr     — push branch + PR onto target: ready for review —
                               #   existing draft marked ready, else opened ready. Never merged.
                               #   Sprint task: PR onto sprint branch, no local merge.
                               #   Outward-facing: /wa-close ALWAYS confirm first, every time.
                               # merge  — merge branch into target: locally, no push.
                               # GitHub provider: ignored for tickets — /wa-validate marks PR ready,
                               #   /wa-close merges on GitHub (squash) on your yes, every time.
  target: main                 # where pr/merge land. Ignored by `nothing`.
  delete_branch: auto          # auto   — delete only once code live elsewhere (merged into sprint
                               #   branch or target). `pr` and `nothing` keep it:
                               #   PR need branch, so do you.
                               # always — delete after close regardless. Ask first when
                               #   branch unmerged — that throw work away.
                               # never  — /wa-close never delete branch.
                               # Slug's worktree (autopilot leftover) removed with it.

pr:                            # HOW every whackagent PR look — ticket draft, /wa-close PR, sprint PR.
                               # Rules: wa-board → Pull requests. Not release PR: release doc own it.
  template: auto               # (key missing → none, old behavior)
                               # auto — repo PR template when present (.github/pull_request_template.md,
                               #   .github/PULL_REQUEST_TEMPLATE/…): sections filled from task file,
                               #   checkboxes ticked only when proved. <path> — that file. none — no template.
                               # whackagent part (Closes #n, criteria, status) always in own marked block;
                               # refresh rewrite only that block, human edits stay.
  title: "{title}"             # placeholders {title} {n} (issue number, GitHub) {slug}
                               # e.g. "[#{n}] {title}", "feat: {title}"
  labels: []                   # added at creation, e.g. [whackagent]. Label missing in repo → skipped.
                               # Plus every PR get ≥1 label from repo's own labels
                               # (best fit: bug, feature, docs, area…) — never created.
  assignees: ["@me"]           # PR assignees at creation, plus @me (always self-assigned)
  reviewers: []                # requested when PR goes ready, never on draft. Users or org/team.
                               # Empty → none requested (CODEOWNERS still apply).
  doc: ""                      # PR rules keys can't express (changelog line, size limit) — `path` or
                               # `path#Heading` (CONTRIBUTING.md#Pull requests). Empty → none.

compress_wiki: true            # caveman-compress config + wiki pages, save re-read tokens
                               # (at /wa-setup + after every /wa-wiki update; .original backups removed)
---

# Project config

Free-form project notes every skill keep in mind.
Edit frontmatter above to change behavior.

- berth = Swift 6 CLI + daemon leasing Android emulators to parallel AI agents. Build `swift build`, test `swift test` (broker tested vs fake backend, no emulator).
- Runtime checks on real emulators: set `BERTH_HOME` to SHORT dir (Unix socket path ≤ 104 bytes), pool only AVDs no human use, never stop/kill emulators berth didn't start.
- Comments minimal: only complex algorithm or non-obvious business rule; no restating doc comments.

## Core rule — stop and ask

Outside autopilot, anything unclear, ambiguous, or blocked beyond task spec: **stop and ask**. Never guess scope.

**Every question come with recommended answer** — always, no exception. One line pick, one line why, plus alternative when real one exist. No basis to choose? Recommend most reversible option, say it guess. Bare question without proposal never acceptable: answer must be confirm-or-correct, not homework.

Inside autopilot: never ask (nobody watching) — freeze task with open question logged, move to next.