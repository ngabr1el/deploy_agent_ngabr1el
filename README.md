# Attendance Tracker: Automated Deployment Agent

`deploy_agent.sh` is a Bash script that deploys, runs and archives the logs of the Student Attendance Tracker (`attendance_checker.py`). The Python application is never modified. Everything here is shell scripting around it.

## Repository layout

```
deploy_agent_ngabr1el/
├── deploy_agent.sh          # the master script
├── templates/               # unmodified source files
│   ├── attendance_checker.py
│   ├── assets.csv
│   └── config.json
├── README.md
└── .gitignore               # ignores deployed projects, zips and vi swap files
```

## Requirements

- Bash, `python3` and `zip`. The script checks for them and stops with a clear message if one is missing.
- Developed and tested in a Linux container with Python 3.8.10 and GNU `sed`.

## How to run it and select a feature

```bash
git clone https://github.com/ngabr1el/deploy_agent_ngabr1el.git
cd deploy_agent_ngabr1el
chmod +x deploy_agent.sh
./deploy_agent.sh
```

I chose an **interactive menu** over command-line flags because it is easier to demonstrate and every prompt validates its input.

| Option | Feature |
|---|---|
| 1 | Deploy a new project |
| 2 | Run an existing project |
| 3 | Archive logs |
| 4 | Exit |

The script moves into its own folder on start, so it can be launched from anywhere. Projects are created next to the script and `templates/` is always found.

## Feature 1: Deploy

1. **Pre-flight checks.** Confirms `python3` and `zip` exist and prints `python3 --version`. If either is missing, it prints every problem and returns to the menu.
2. **Project name.** Asks for a name and builds `attendance_tracker_<name>/`. Empty names and names with characters other than letters, numbers, `_` and `-` are rejected, so input like `../x` cannot point outside the repo.
3. **Existing folder.** If the folder exists, the script asks whether to overwrite. Only `y` or `Y` overwrites. Anything else aborts and changes nothing.
4. **Structure.** Creates `Helpers/` and `reports/` and checks that `mkdir` succeeded.
5. **Core files.** Copies `attendance_checker.py` and `config.json` unmodified from `templates/`. Both are compared against the templates with `cmp` and `diff` in my tests.
6. **Roster.** See the next section.
7. **Permissions.** `chmod +x` on `attendance_checker.py` and `chmod 600` on `Helpers/config.json` (owner read/write only, because it holds grading-sensitive thresholds). The script prints `ls -l` for both files as confirmation.
8. **Thresholds.** See "Threshold update".
9. **Verification.** The deploy ends by running the application. A successful start proves the structure, roster and config work together.

Deployed structure:

```
attendance_tracker_<name>/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
└── reports/            # empty until the app runs
```

### Roster options and `total_sessions`

`total_sessions` must always equal the number of prior sessions in the roster plus one, because it includes today's session.

| Option | What it does | `total_sessions` |
|---|---|---|
| A: copy | Asks how many students (1 to 10), then copies that many rows plus the header from `templates/assets.csv` with `head`. The sample rows carry 4 prior sessions. | stays `5` |
| B: generate | Asks how many students (1 to 10), then builds the rows in the script from arrays of names and emails, with Attendance Count and Absence Count both `0`. | changed to `1` with `sed` |

The student count must be a whole number in range. Anything else is rejected and asked again.

### Threshold update

After the roster, the script asks `Update the attendance alert thresholds? (y/n)`.

- `n` keeps the defaults (warning 75, failure 50).
- `y` asks for a new warning and failure value. A bare Enter keeps the default.
- Each value must be a whole number from 0 to 100, or it is rejected and asked again. Validation happens **before** `sed` runs, so letters, negatives, decimals and empty values never reach the file.
- Failure must be lower than warning, otherwise both are asked again.
- `sed -i` then rewrites only the `"warning": <number>` and `"failure": <number>` lines in `Helpers/config.json`. The layout and order of the file are unchanged. A `diff` against the template shows exactly those two lines changed, and the file is still `-rw-------` afterwards.

## Feature 2: Run

Menu option 2 lists existing projects and asks for the name. It validates the name, checks that the folder exists and that `attendance_checker.py`, `Helpers/assets.csv` and `Helpers/config.json` are all present (with a clear message instead of a Python traceback if not), and then runs:

```bash
cd attendance_tracker_<name> && python3 attendance_checker.py
```

The app is interactive, so it takes over the terminal. When it ends, the script reports `[OK] Application finished normally.` or the exit status.

## Feature 3: Archive logs

Menu option 3 is the archive trigger. Run it after a marking session. It asks for the project name, then copies the logs:

```
attendance_tracker_<name>/
└── archives/
    ├── attendance/
    │   └── attendance_YYYYMMDD_HHMMSS.log
    └── absent/
        └── absent_YYYYMMDD_HHMMSS.log
```

- `reports/attendance.log` goes to `archives/attendance/` and `reports/absent.log` goes to `archives/absent/`.
- The timestamp comes from `date +%Y%m%d_%H%M%S`. It is computed once, so both logs from one archive run share the same stamp.
- `cp` is used, not `mv`, so the originals stay in `reports/`.
- A log that does not exist (for example, nobody was absent, so there is no `absent.log`) prints `[SKIP]` and the script carries on.
- If neither log exists, the script says to run the app first.
- If a target file already exists (a second archive in the same second), it is skipped instead of overwritten.
- The script prints each archived path and a summary such as `Archive complete: 1 of 2 log(s) archived.`

## Signal handling: Ctrl+C and Ctrl+Z during deploy

### What triggers the archive

Pressing **Ctrl+C (SIGINT)** or **Ctrl+Z (SIGTSTP)** at any point while Feature 1 is setting up the project (from the first prompt until just before the app launches) triggers the handler. It:

1. Prints which signal was received.
2. Zips whatever exists of `attendance_tracker_<name>/` into `attendance_tracker_<name>_archive.zip` (in the repo folder) with the `zip` command.
3. Deletes the incomplete folder, but **only if the zip succeeded**, so nothing is ever lost.
4. Prints `Session closed.` and exits with status `1`.

Edge cases:

- If the interrupt happens before a new folder exists (at the name prompt or the overwrite prompt), there is nothing to zip. The script says so and leaves any existing project untouched.
- A second Ctrl+C while the cleanup runs is ignored, so the cleanup cannot be cut short.
- The traps are removed right before the app launches. During the marking session the app handles its own Ctrl+C (the script then reports exit status 130). Ctrl+Z at that point suspends the job as usual; resume it with `fg` or stop it with `kill %1`.

### How to test it

```bash
./deploy_agent.sh
```

Choose `1`, enter a name such as `sigtest`, and press **Ctrl+C** at `Choose A or B:`. For Ctrl+Z, continue to the `Update the attendance alert thresholds?` prompt and press **Ctrl+Z** there. Then check:

```bash
ls -d attendance_tracker_sigtest*
python3 -m zipfile -l attendance_tracker_sigtest_archive.zip
echo $?
```

Expected: only the `.zip` exists (no folder), and `echo $?` prints `1`.

### What the zip contains

It holds the project exactly as far as the deploy had got:

| Interrupted at | Zip contains |
|---|---|
| The roster question (A or B) | `attendance_checker.py`, `Helpers/config.json`, `reports/` |
| The threshold question | The same, plus `Helpers/assets.csv` |

## How I tested the deployed structure

- `ls -R attendance_tracker_<name>` to check `Helpers/` and `reports/` exist.
- `ls -l` on the deployed files to confirm `-rwxr-xr-x` for the checker and `-rw-------` for the config.
- `cmp` and `diff` against `templates/` to prove `attendance_checker.py` and `config.json` are unmodified (apart from the `total_sessions` and threshold edits).
- `cat Helpers/assets.csv` to check the roster rows for Option A and Option B.
- `grep total_sessions Helpers/config.json` to confirm `5` for Option A and `1` for Option B.
- Running the app after each deploy to confirm it starts and writes `reports/attendance.log` and `reports/absent.log`.
- `bash -n deploy_agent.sh` after every edit to check syntax.

## Known behaviours

- Marking the same project twice breaks the `total_sessions` rule, and the app prints a warning. Deploy a fresh project for each demo.
- Overwriting an existing project removes the old folder before the new one is built.
- Every `mkdir`, `cp`, `chmod` and `sed` is checked and prints an `[ERROR]` message on failure. I tested as `root`, which bypasses file permissions, so these paths were not triggered.

## Git workflow

Each step was built on its own branch and merged into `main` through a pull request.

| Branch | Content |
|---|---|
| `feature/deploy-agent` | Menu, pre-flight checks, naming, overwrite prompt |
| `feature/copy-and-roster` | Template copying, roster options A and B |
| `feature/permissions-thresholds` | `chmod` and the threshold `sed` update |
| `feature/run-and-verify` | Feature 2 and the verification run |
| `feature/archive-logs` | Feature 3 |
| `feature/signal-handling` | Ctrl+C and Ctrl+Z handling |
| `docs/readme` | This README |

## Video walkthrough

[watch the walkthrough video](https://youtu.be/vXDieSbNIOU)
