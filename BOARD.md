<!-- board-contract: 2.4 -->
<!-- Installed by setup, its angle-bracket placeholders filled for this repository and only its board tool's section kept. Update through the setup PR, never by hand: the hooks,
     the board CLI and the PR template carry the same contract version. -->

# Board contract

This repository's backlog is a board: *This board* below says which tool holds it and where. Code, branches and pull requests live on GitHub. Several developers and several AI agents share the board, each with their own tools and work loop. This file is the only thing they all have to agree on: how a ticket moves, who may touch it, and what the repository must show at each step. How you do the work in between (your skill, your agent, by hand) is yours.

**Every agent reads this file before it works on a ticket, and follows it.** The rules are written as MUST and NEVER on purpose; a workflow check reports every rule broken.

## The one rule

**Workers take tickets. The repository moves them.**

You never move a card on the board. You only *claim* a ticket (a lock) before working on it, and *release* it if you stop. Every other change of state comes from something that happened in the repository (a spec written, a PR opened, a PR merged) and is applied by the board workflow. The board says what the code says.


## This board: Plane

The board is a Plane project on a self-hosted Plane server: http://rlatapy-macbook.local:8391/lunabee/projects/492f893c-dda7-4438-a143-4692bf2377bf/issues/. Code, branches, claims and pull requests stay on GitHub. The Plane board is experimental. The board CLI needs the Plane API key in the `PLANE_API_KEY` environment variable; never write the key in the repository.

### What lives where

| Thing | Where |
|---|---|
| Ticket | a card (work item) of the Plane project; its key is the ticket id `<id>` (`BERTH-42`, always written as is). Every card is a ticket, unless labeled `wa-ignore` |
| State | the card's column: the six states below, plus `Canceled` |
| Priority | card order on the board, top = next |
| Size | none: this board has no size |
| Spec | a task file `.whackagent/tasks/<id>-<slug>.md` on the ticket's branch, only |
| Lock | a claim, git ref `refs/wa-claims/<id>/<phase>` on the GitHub repository, created by the board CLI |
| Reservation | card assignees: a ticket assigned to another Plane user is not yours to take |
| Sprint | a parent card labeled `wa-sprint`, plus a cycle of the same name; its tickets are its child cards |
| Milestone | a Plane module (release scope) |
| Dependency | Plane relations ("blocked by") |
| Change | one PR per ticket, on GitHub, carrying the card link |

### Columns

- Humans read the board, write tickets and reorder cards. Nobody moves a card to another column by hand, human or agent: claims and the board workflow do.
- Card order is priority. Drag a card up to make it next; the board CLI reads the same order.
- `Canceled` is not `done`: a canceled ticket never landed, is never claimable and never counts as done.
- A card in a column outside the six states and `Canceled` is a human's: the board CLI and the workflow leave it alone.

### Spec

- The spec is a task file on the ticket's branch `wa/<id>-<slug>`: `.whackagent/tasks/<id>-<slug>.md`, with frontmatter `issue: <id>` and a non-empty `## Acceptance criteria`. Pushing it moves the ticket to `grilled` and drops your claim.
- **A spec written in the card description does not move the ticket to `grilled`.** The board workflow runs on GitHub events and never sees a Plane edit. Write the task file instead. The board check reports acceptance criteria left in the description of a card in `todo`.

### Branch

Create the ticket's branch from the fork point and push it at once: `git switch -c wa/<id>-<slug> origin/<fork point>`, then `git push -u origin wa/<id>-<slug>`. The branch name ties the branch to the card. Another branch name works only if your PR body carries the card link.

### Ticket link

- A ticket PR's body carries exactly one card link under `## Ticket`: `[<id>](http://rlatapy-macbook.local:8391/lunabee/browse/<id>/)`, never `Closes`.
- The workflow finds the ticket from the branch name first, then from that card link, and adds the PR as a link on the card. Never link it by hand.
- A PR body with two card links moves nothing: the workflow reports it on the PR.
- A PR that is not a ticket's writes `Sprint <parent>` or `n/a` under `## Ticket`, never a card link.

### Sprints

- The sprint root is a parent card labeled `wa-sprint`; its tickets are its child cards. A cycle of the same name shows them in Plane's cycle view.
- The parent decides: a card dragged into a cycle by hand, without the parent, is not in the sprint.
- The workflow moves the sprint root to `Done` when the sprint lands. A root left open with nothing to land is the one card a human moves by hand: to `Done`, or to `Canceled` when nothing shipped.

### Milestones and dependencies

- A milestone is a Plane module. A ticket sits in one module at most: `set-field <id> milestone <name>` puts it there and takes it out of every other. Plane's paid Milestones feature is not used.
- Dependencies are Plane relations. The board CLI only adds them: a dependency added by mistake is removed by a human in Plane.

### Single writer and runner

- Plane's own GitHub integration must stay off. It would move cards from GitHub events too and fight the board workflow. Setup checks it.
- The board workflow runs on a self-hosted GitHub Actions runner next to the Plane server, labeled `whackagent-plane`. While the runner is offline, runs wait in the queue and cards do not move.

### Checks

The board workflow reports, as a comment on the card or PR:

- on a card, once a day on weekdays: a card in `grilling` or `coding` with no claim held; a claim held with nothing new for 24 h; a card in `review` with no open PR; a linked PR open while the card sits in `todo` or `grilled`; a linked PR merged while the card is not `done`; a card in `grilled` with no ticket branch; acceptance criteria in the card description while the card sits in `todo`.
- on a PR, as it happens: a push while the ticket holds no `coding` claim; a PR linking several cards.

## States

| State | Meaning | Entered by |
|---|---|---|
| `todo` | the ticket exists, no spec yet | ticket created |
| `grilling` | **locked**: one worker is writing its spec | `claim <id> grilling` |
| `grilled` | spec written, ready to code | workflow: spec found (see *3a. Spec*) |
| `coding` | **locked**: one worker is changing its code | `claim <id> coding` |
| `review` | a PR is open, humans are on turn | workflow: PR opened, or a claimed round pushed to it |
| `done` | the change landed | workflow: PR merged |

Allowed claims: `grilling` from `todo` (first spec) or `grilled` (re-spec, when scope changed). `coding` from `grilled` (first round) or `review` (any later round). Anything else is refused.

In `review`, the PR tells who acts: **draft** = humans test it, **ready** = a human decides the merge.

Column names may differ on the board; the board CLI always reports the six names above.

## Board CLI

`.github/board/wa-backlog` (run from the repository root; needs `gh` logged in, plus what *This board* names). It prints JSON on stdout and messages on stderr.

| You want to | Run |
|---|---|
| see the board | `.github/board/wa-backlog list [--state s,…] [--sprint x] [--milestone m]` |
| read one ticket (state, branch, blockers, claims) | `.github/board/wa-backlog get <id>` |
| create a ticket | `.github/board/wa-backlog create --title "…" --summary "…" [--size …] [--sprint …] [--note "…"]` |
| take a ticket | `.github/board/wa-backlog claim <id> grilling\|coding` (`--blocked-ok`: see *Dependencies*) |
| give it back | `.github/board/wa-backlog release <id> <phase> --reset-to <state> --reason "…"` |
| repair a PR's link to its ticket (the workflow links it on its own) | `.github/board/wa-backlog link-pr <id> <pr>` |
| record a dependency | `.github/board/wa-backlog depend <id> --on <x>[,<y>]` |
| set size, sprint, milestone | `.github/board/wa-backlog set-field <id> size\|sprint\|milestone <value>` |
| leave a note on the ticket | `.github/board/wa-backlog comment <id> "…"` |
| cancel a ticket, on a human's word only | `.github/board/wa-backlog cancel <id> --reason "…"` |
| see live locks | `.github/board/wa-backlog claims` |

`<id>` is the ticket id. In text (PR bodies, comments), write it as *This board → What lives where* shows it.

Exit codes: `0` ok · `1` error · `2` usage · **`3` taken** (someone else holds it, or it is assigned to another account; the owner is printed) · **`4` wrong state** (or, for `claim <id> coding` on a `grilled` ticket, a blocker still open; the blockers are named). `3` and `4` are normal answers, not failures. Claiming a phase you already hold (same agent id) answers `0`.

## Working a ticket

### 1. Pick

Take the top ticket of the state you need (`todo` to spec, `grilled` to code) that is **unclaimed and not reserved**. Never pick a ticket whose `claims` is non-empty or whose `reserved` is true. Never pick a `grilled` ticket whose related blockers are still open, unless you stack on them (see *Dependencies*).

### 2. Claim

`.github/board/wa-backlog claim <id> <phase>` before you change anything: spec, branch, code, PR. Exit `3` → someone holds it: never retry, never steal; pick another ticket or tell your user who holds it. Exit `4` → it is not in a state you can claim: say which, stop.

A winning claim assigns your account to the ticket. Leave that assignment alone.

### 3a. Spec (`grilling`)

- The spec has two sections:
  - `## Acceptance criteria` (required, non-empty): observable checks that mean "done", one per line.
  - `## Context / Decisions` (optional): what was decided and why.
- *This board → Spec* says where the spec goes and which write counts. Write both sections in **one write, at the end**: the workflow moves the ticket to `grilled` on that write and drops your claim. A half-written spec saved early would move it too soon.
- A task file on the ticket's branch (`.whackagent/tasks/<id>-<slug>.md`, frontmatter `issue: <id>`, non-empty `## Acceptance criteria`) counts on every board: pushing it has the same effect. That route needs the branch named `wa/<id>-<slug>`.
- Spec too big for one ticket → split it into new tickets in a sprint (see *Sprints*), with your user's agreement.
- You stop before the spec is written → `release <id> grilling --reset-to todo` (re-spec: `--reset-to grilled`).

### 3b. Code (`coding`)

- **Branch.** Reuse the ticket's branch when it has one (`get <id>` → `branch`). Otherwise create it as *This board → Branch* says.
- **Fork point** = the sprint branch `sprint/<sprint>` when the ticket is in a sprint, else `main` (or its track branch, when its milestone is a track).
- **One round = claim → work → commit → push.** Push **once, at the end** of the round: a push to a branch with an open PR ends the round and drops your claim.
- **First round** opens a **draft PR** (`gh pr create --draft`) whose body carries the ticket link (*This board → Ticket link*). Later rounds push to the same PR and refresh its body.
- **A round ends only with a PR or a release.** Local commits, or a branch pushed without a PR, keep your claim and the card in `coding`: nobody else can test or review that work yet. Stopping for longer than 24 h → open the draft PR, or release.
- **Nothing to push** at the end of a round → `release <id> coding --reset-to review` (PR open) or `--reset-to grilled` (no PR yet). Never leave a claim behind.
- **After each push**, check `gh pr view <pr> --json mergeable` (retry while `UNKNOWN`). `CONFLICTING` → GitHub runs no workflow on a conflicting PR, so your push moved nothing and your claim is still held: rebase your ticket's own commits onto the PR base, re-run the tests, `git push --force-with-lease`, check again.
- **Feedback on a ready PR** → `gh pr ready --undo` before your first commit, so nobody merges code that is moving.

### 4. Ready

`gh pr ready <pr>` means: *this PR is mergeable*. Mark ready only when every acceptance criterion is proven (checked in the PR body) or explicitly left to a human, and no check is failing. In an attended run, the human who tested says so. In an unattended run, mark ready only if your own verification proved every criterion it could run; otherwise leave the PR draft and say what is left. Request reviewers when the PR goes ready, never on a draft.

### 5. Merge

**A human decides every merge**: on GitHub, or by asking their agent to merge that PR in that session. An agent merges no PR its user did not name. When it merges:

- Claim `coding` first (from `review`), so no other round pushes while you merge. Exit `3` → stop.
- Merge only a **ready** PR whose checks are green, whose required reviews are in, and whose base is not another ticket's open branch (stacked: the PR below merges first).
- Use the merge style below: `.github/board/wa-backlog merge <pr>` for a ticket (squash; `--method merge` for a track landing). It merges that one PR through GitHub's async merge API, the only one that accepts a stacked PR, and refuses while a PR below it in the stack is open. Never `--admin`, never bypass branch protection.
- GitHub refuses (checks, reviews, conflict) → `release <id> coding --reset-to review --reason "…"` and say why.

Never merge a ticket branch locally. The workflow sets `done` and drops the claim on merge.

## Pull requests

- **One PR links exactly one ticket**, through the ticket link in its body (*This board → Ticket link*).
- **The body follows the repository's PR template**, including its board sections:
  - `## Ticket`: the ticket link.
  - `## Acceptance criteria`: the ticket's current criteria as a checklist. Check `- [x]` only what a round proved; leave the rest `- [ ]` with a one-line reason.
  - `## Status`: one line saying what is owed next (`Draft — test it`, `Ready — review, then merge`).
  - A PR that is not a ticket's (sprint, track or sync PR) says so under `## Ticket` and never carries a ticket link.
- **Refresh the body on every round that pushes**: a PR body describing superseded behavior misleads its reviewer. Keep text a human added.
- **No milestone on PRs**: the linked ticket carries it. **Labels**: pick from the repository's own; never create labels.

## Merge style

- **Ticket PRs land squashed.**
- **Sprint, track and sync PRs land with a merge commit, never squashed**: squashing loses the history every later rebase and sync relies on. Their body says so.
- Because tickets land squashed, the base never contains a ticket's original commits. **Diff and rebase only your ticket's own commits**: `git rebase --onto origin/<new base> <first own commit>^`. Never a plain `git rebase main` or a `main..HEAD` diff after a parent or stacked ticket landed.

## Sprints

- A sprint groups the tickets of one body of work under a sprint root (*This board → Sprints*). Sprint name = the root's title in kebab-case. `set-field <id> sprint <name>` creates or joins it.
- With sprint branches, each ticket forks from `sprint/<name>` and its PR targets it. When every ticket landed, one sprint PR merges the sprint branch into `main` (merge commit); the workflow then closes the sprint root.
- A sprint root is not a ticket: never claim it, never code it. A ticket that already has a parent which is not a sprint can't join a sprint: say so, never detach it.

## Milestones

- **Humans own milestones**: they create, rename and close them. Workers never do, except closing one in a documented release flow on a human's yes.
- A new ticket joins the **highest open milestone** (version order of titles); `create` does it. Change a ticket's milestone only on a human's word.
- Milestones listed as tracks (long-lived trunks beside `main`) are never a default: a ticket joins one only on a human's word, and then forks from and lands on that track's branch.

## Dependencies

- Record them: `depend <id> --on <x>`. Read them: `get <id>` → `blocked_by`. A blocker is **open** until it is done or canceled.
- `claim <id> coding` on a `grilled` ticket with an open blocker answers `4`. Pass `--blocked-ok` only when you mean it: you stack on the blocker, or the blocker is unrelated and your human said to go ahead. A ticket already in `review` claims without the check.
- A blocker is **related** when it shares the ticket's sprint, or its track milestone (`get` → `sprint`, `milestone`). An **unrelated** blocker (other sprint or track, or none) never stacks: work the ticket from its own base as usual (claim with `--blocked-ok`) and add the body line `Blocked by <x>: merge order is yours`.
- Ticket with an open related blocker: wait, or **stack**: claim with `--blocked-ok`, fork from the blocker's branch, PR base = that branch, then `.github/board/wa-backlog stack <pr> --on <blocker pr>` puts the PR in the blocker's GitHub stack. Stacks are linear: when the blocker already has a PR on top (exit `4`), the PR stays chained on the blocker's branch with the body line `Stacked on #<pr>: merge it first`.
- **Keep a stack linear.** GitHub refuses to merge a stack whose upper branch does not descend from the one below. A round that pushes to a ticket with PRs above it in its stack rebases each of them onto the new branch below: claim it `coding` first (exit `3` → leave it, say it needs a rebase), rebase only its own commits, push with `--force-with-lease`.
- After a stacked PR merges, GitHub retargets the PRs above it and rebases their branches itself: start your next round from the remote branch, never push an older local copy over it.
- **Never delete a branch by hand** while PRs are based on it: GitHub retargets them only when the branch is deleted by a merge. Deleting it later closes them.

## Locks

- Claims never expire: a spec interview may wait two days for an answer.
- `claims` flags a lock `stale` after 24 h with nothing new (age = the newer of the claim and the branch's last commit), and the check reports it on the ticket. **Only a human clears a stale lock** (`release <id> <phase> --reset-to <state> --reason "stale: …"`). Never release a lock you don't hold to take its ticket.

## Checks

The board workflow **reports** what breaks this contract, once per problem, as a comment on the ticket or PR. It never moves cards: fixing is up to the worker or a human. *This board → Checks* lists what it reports. A comment turns to resolved once the problem is gone.

Read those comments when you take a ticket, and fix what they name.

## Never

- Move a card, or set a state, yourself.
- Work on a ticket you have not claimed, or one claimed by someone else, or reserved for another account.
- Merge a PR your user did not ask you to merge, merge with an admin override, or merge a ticket branch locally.
- Push in the middle of a round to a branch with an open PR.
- Create, rename or close milestones; create labels.
- Force-push without `--force-with-lease`, or force-push a branch whose ticket you have not claimed.
- Delete a branch other PRs are based on.

## Version

This file carries `board-contract: 2.4` in its first line. The board CLI, the board workflow and the PR template sections carry the same version. The CLI warns when this file's version differs from its own: update them together with the setup PR, never one file by hand.
