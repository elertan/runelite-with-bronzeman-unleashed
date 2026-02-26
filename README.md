# RuneLite With Bronzeman Unleashed (Unofficial)

This repository exists to publish unofficial RuneLite builds that include Bronzeman Unleashed before it is ready on the official Plugin Hub.
It is an automation/release repository, not a maintained mirror of the full RuneLite source tree.

## Read This First (Safety)

This build is unofficial.
We cannot guarantee security, and we do not recommend playing this way.

Use this only if you are comfortable reading and verifying source code changes yourself.
Do not blindly trust unofficial binaries.

## Installation

1. Install Java:
- [Microsoft OpenJDK downloads](https://learn.microsoft.com/en-us/java/openjdk/download)
2. Download the latest release from this repository.
3. Extract all files to a folder on your computer (for example Desktop or Documents).
4. Launch the client:
- Windows: `start.bat`
- Linux/macOS: `start.sh`

## Troubleshooting (Windows Smart App Control)

If Windows shows `Smart App Control blocked a file that may be unsafe` when launching `start.bat`:
- This is expected for some unsigned/untrusted custom builds.
- Smart App Control does not provide a simple per-file allowlist for this case.
- You can use official RuneLite, or disable Smart App Control and run this build at your own risk.

## Jagex Account Setup Requirement

To make this custom build work with Jagex Accounts, you must have official RuneLite installed.

1. Open RuneLite Launcher Configuration (`RuneLite (Configure)` on Windows).
2. Add `--insecure-write-credentials` to Client Arguments.
3. Launch official RuneLite once and log in.

This allows the custom launcher to reuse the last launch account credentials.

Using `--insecure-write-credentials` stores a session credential on disk.
If malware runs on your machine, or someone can read your files, your account can be compromised.

## JVM Arguments (`jvmargs.txt`)

Custom JVM arguments are read from `jvmargs.txt` in the same folder as:
- `runelite.jar`
- `start.sh`
- `start.bat`

Rules:
- One argument per line
- Lines starting with `#` are comments
- `jvmargs.txt` is preserved across launcher self-updates

Default example:

```text
-Dsun.java2d.uiScale=1.0
```

## UI Scaling (Like RuneLite Configure)

To change client scale, set `-Dsun.java2d.uiScale` in `jvmargs.txt`, for example:

```text
-Dsun.java2d.uiScale=1.35
```

Use any value that works for your display.

## NVIDIA Dedicated GPU Note

Some users may need to add `runelite.jar` in NVIDIA Control Panel Program Settings and force the dedicated/high-performance NVIDIA GPU.

## How Releases Are Built

GitHub Actions builds releases by combining:
- The latest RuneLite upstream release tag from [`runelite/runelite`](https://github.com/runelite/runelite) (`runelite-parent-*`)
- The latest commit on the `main` branch of [`elertan/bronzeman-unleashed`](https://github.com/elertan/bronzeman-unleashed)

Release names use:
- `<runeliteVersion>-<pluginCommit7>`
- Example: `1.12.17-c7c3280`

The launcher checks for updates on startup.
If update checking fails, it still launches your currently installed version.
