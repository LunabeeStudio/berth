# Update

Self-update from GitHub Releases ([[release]] owns assets + version). Two entry points, one updater.

- **BerthCore/Update**: `Updater` (facade, `UpdateSource` seam) → `check()` → `UpdateCheck` `.upToDate` / `.available(current, latest, release)`; `install(release)`. Feed = `api.github.com/repos/LunabeeStudio/berth/releases/latest` (prereleases excluded), `BERTH_UPDATE_URL` overrides (tests, proofs). `Download`: uncached, non-200 → `UpdateError.http`. `SemanticVersion` X.Y.Z numeric; `dev` → `UpdateError.devBuild`, never updates.
- **Install** (`Installer`): writable check first → archive + `.sha256` → CryptoKit SHA-256 → `/usr/bin/tar` into temp dir inside target dir → chmod 0755 → `rename(2)` onto `berth` (resolved exe path) then sibling `berth-bar` if present. Any failure → nothing replaced. Rename keeps running processes on old inode. Never write into a running signed binary's inode (`cat new > berth`): macOS SIGKILLs next exec.
- **CLI** `berth update [--check]`: never starts daemon; result stdout, errors `berth: <localizedDescription>` exit 1.
- **Daemon** (`BerthDaemon/SelfUpdate`): `AutoUpdater` — config `autoUpdate` (default true, key absent = true), off for dev; 60 s after start then every 24 h; logs `auto update: installed a → b` / `auto update failed: …`, keeps serving.
- **Re-exec** (`ReexecMonitor.poll`, every 5 s reap tick): `ExecutableWatch` (inode/size/mtime) reports change only when stable 2 polls → `Reexec.isLoadable` (executable + `codesign --verify`, rejection logged once) → `Broker.performIfIdle` (actor-isolated: no lease, no waiter, all slots free → no claim slips in) → `Reexec.run`: FD_CLOEXEC on open fds (`/dev/fd`), `execv` same path + args, **same pid** (launchd agent keeps tracking it), state restore adopts emulators. Exec failure → logged, no retry until file changes again. Daemon lock fd `O_CLOEXEC`.
- berth-bar: file replaced, running instance stays old until relaunch.
