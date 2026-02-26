# RuneLite With Bronzeman Unleashed (Unofficial)

This repository is an automation and release repository.
It is not a maintained fork of the full RuneLite source tree.

GitHub Actions builds releases by combining:
- The latest RuneLite upstream release tag from [`runelite/runelite`](https://github.com/runelite/runelite) (`runelite-parent-*`)
- The latest commit on the `main` branch of [`elertan/bronzeman-unleashed`](https://github.com/elertan/bronzeman-unleashed)

Release names use:
- `<runeliteVersion>-<pluginCommit7>`
- Example: `1.12.17-c7c3280`

## Important Safety Notice

This build is unofficial.
We cannot guarantee security, and we do not recommend playing this way.

This is intended for people who want to try Bronzeman Unleashed before it is ready on the official Plugin Hub.
Use at your own risk.

## How Releases Work

- The workflow checks for the newest RuneLite release tag.
- It syncs Bronzeman Unleashed into RuneLite during the CI build.
- It publishes release assets in this repository.
- The bundled launchers check for updates on startup and can install updates in place.
- If update checking fails, the launcher still starts your currently installed version.

## JVM Arguments (`jvmargs.txt`)

Custom JVM arguments are read from `jvmargs.txt` in the same folder as:
- `runelite.jar`
- `start.sh`
- `start.bat`

Rules:
- One argument per line
- Lines starting with `#` are comments

Example:

```text
-Dsun.java2d.uiScale=1.35
-Xmx2048m
```

`jvmargs.txt` is preserved across launcher self-updates.

## Jagex Account Requirement

To make this custom build work with Jagex Accounts, you must have official RuneLite installed.

Then:
1. Open RuneLite Launcher Configuration (`RuneLite (Configure)` on Windows).
2. Add `--insecure-write-credentials` to Client Arguments.
3. Launch official RuneLite once and log in.

This allows the custom launcher to reuse the last launch account credentials.

## Credential Risk Warning

Using `--insecure-write-credentials` stores a session credential on disk.
If malware runs on your machine, or someone can read your files, your account can be compromised.
