# Skills

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) skills, kept
in one repository and linked into `~/.claude/skills` so edits here are live in
the next session.

[SKILLS.md](SKILLS.md) is the house standard every skill in here follows — what
qualifies as a skill, how it is named and laid out, what goes in the
frontmatter, and how workflow skills drive subagents. Read it before adding one.

## Skills

| Skill | What it does |
| --- | --- |
| [`brainstorm`](skills/brainstorm/SKILL.md) | Interviews you one question at a time until both sides hold the same picture, then writes up the decisions. |
| [`to-tickets`](skills/to-tickets/SKILL.md) | Breaks a plan into a graph of thin vertical-slice tickets with explicit blocking edges. |
| [`orchestrate`](skills/orchestrate/SKILL.md) | Drives a GitHub epic to a draft PR, one sub-issue at a time, through implement, review, and verify subagents. |
| [`verify`](skills/verify/SKILL.md) | Runs the project's own review, build, and test gates, fixes what fails, and reports a per-gate verdict. |
| [`test-drive`](skills/test-drive/SKILL.md) | Drives the running app through what landed in a time window — or through one named feature — and judges each against its acceptance criteria. |

## Install

Every skill is self-contained, so you can link all of them or just one.

**macOS, Linux, WSL, Git Bash**

```bash
./scripts/link-skills.sh
```

**Windows (PowerShell)**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\link-skills.ps1
```

Then start a new Claude Code session and type `/` to see the skills.

## Usage

Both scripts take the same three commands and act on every skill in `skills/`
unless you name specific ones.

| Command | Effect |
| --- | --- |
| `link` (default) | Create a link for each skill in the skills directory |
| `unlink` | Remove links that point into this repository |
| `status` | Report the state of each skill, change nothing |

| Option | sh | PowerShell |
| --- | --- | --- |
| Pick a different skills directory | `-t, --target DIR` | `-Target DIR` |
| Show what would happen | `-n, --dry-run` | `-DryRun` |
| Replace links pointing elsewhere | `-f, --force` | `-Force` |
| Help | `-h, --help` | `Get-Help .\scripts\link-skills.ps1` |

```bash
./scripts/link-skills.sh link brainstorm verify   # link two skills
./scripts/link-skills.sh status                   # what is linked right now
./scripts/link-skills.sh unlink --dry-run         # preview a full removal
```

```powershell
.\scripts\link-skills.ps1 link brainstorm verify
.\scripts\link-skills.ps1 status
.\scripts\link-skills.ps1 unlink -DryRun
```

## How linking works

Each `skills/<name>/` directory is linked to `<skills dir>/<name>`. Claude Code
follows the link and reads `SKILL.md` from this repository, so a `git pull` or a
local edit takes effect in the next session without reinstalling anything.

The skills directory is `$CLAUDE_CONFIG_DIR/skills` when that variable is set,
otherwise `~/.claude/skills`. Override it with `--target` / `-Target`.

**Windows links.** The PowerShell script creates *directory junctions*, which an
unprivileged user is allowed to create. Real symbolic links need Developer Mode
or an elevated shell; pass `-Symbolic` if you want them anyway. Claude Code
follows either. Under WSL or Git Bash, use the shell script instead — it creates
ordinary symlinks.

**What the scripts will not do.** Neither script ever removes a real file or
directory. If something already occupies a skill's name, it reports the conflict
and leaves it in place for you to move aside. `--force` only replaces *links*
that point somewhere else, and `unlink` only removes links that point back into
this repository.
