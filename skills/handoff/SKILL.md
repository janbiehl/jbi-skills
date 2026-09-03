---
name: handoff
description: Writes a durable handoff document for whoever picks the work up next — a person, a fresh session, or another agent — capturing where things stand, what was decided and why, what was tried and rejected, and the next concrete step, grounded in the repository's actual state. With --resume it reads the newest handoff back, re-grounds it against git, and reports what has drifted since it was written. Use when work is being handed over, a session is ending with something unfinished, or a previous handoff needs picking up.
argument-hint: "[topic] | --resume [slug]"
disable-model-invocation: true
# Writing is the only side effect and it stays inside .scratch/. --resume must
# stay read-only: it briefs, it never continues the work it describes.
allowed-tools: Read Write Grep Glob Bash(date:*) Bash(ls:*) Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git branch:*) Bash(git rev-parse:*) Bash(git merge-base:*) Bash(git check-ignore:*)
---

# Hand work over

Writes down where the work stands so someone else can continue it without this
session's context. Output is one file under `.scratch/handoffs/` plus a summary
in chat. This skill never edits source, never commits, and writes nowhere else.

The document is written for two readers at once. A person reads the top and
knows what happened; an agent handed the path reads **Start here** and knows
what to do first. There is no mode switch, and no section addressed to only one
of them.

## The four rules that make a handoff worth trusting

1. **The dead ends are the payload.** What was tried and abandoned, and why, is
   the part the receiver cannot reconstruct from the diff. A handoff that records
   only the clean narrative hands over the half a competent reader would have
   worked out anyway, and lets them walk straight back into the approach that
   already failed.

2. **Every claim about the code names a path.** Where things stand, what is
   half-done, what is stubbed — each carries the file it is true of, with a line
   number where the file is long. A claim that cannot be checked against the repo
   is a memory of a codebase rather than a description of one.

3. **Absence is stated.** Unknowns go in **Open questions**, not into confident
   prose. "I did not check whether the migration runs on an empty database" is
   worth more than a next step written as if it had been checked.

4. **Nothing is invented to fill a heading.** A section with nothing real in it
   is deleted, not filled with "none" or a restatement of another section. The
   contract is which headings mean what, not that all of them appear.

## Current state

!`date +'%Y-%m-%d %H:%M'`

!`git status --short --branch 2>&1 | head -20`

!`git log --oneline -8 2>&1`

!`ls -1 .scratch/handoffs 2>/dev/null | tail -5`

## Pick the mode

| `$ARGUMENTS` | Mode | Go to |
| :--- | :--- | :--- |
| `--resume` | Read the newest handoff back | [Resume](#resume) |
| `--resume <slug>` | Read that handoff back | [Resume](#resume) |
| empty | Write a handoff covering the whole session | [Write](#write) |
| anything else | Write a handoff scoped to that topic | [Write](#write) |

## Write

Copy this checklist into your reply and tick items off:

- [ ] 1. Fix the scope
- [ ] 2. Gather the state
- [ ] 3. Write the file
- [ ] 4. Report

### 1. Fix the scope

With no argument, the handoff covers the whole session. With a topic, it covers
that thread of it and nothing else — which matters, because the injected git
state above covers the whole working tree either way. Decide for each changed
path whether it belongs to the topic, and say so in **State on disk**: a receiver
who pulls this branch sees every change, and needs to know which ones this
document is about.

Derive the slug from the scope, not from the branch: two to four words, lowercase,
hyphenated, naming the work rather than the ticket number. `payment-retry-backoff`,
not `handoff-2` or `feat-1234`.

Say in one line what the scope is before writing anything, so a misread topic
costs a sentence rather than a document.

### 2. Gather the state

The session supplies the *why*; git supplies the *what*. Where the two disagree,
git wins and the disagreement is worth a line — a decision you remember making
but that is not in the tree was not made.

Read the actual diff of the paths in scope rather than recalling them. What was
written an hour ago and what is on disk now are different things, and the
receiver gets the disk.

Then answer these, and treat a blank answer as a section to delete rather than a
prompt to invent:

| Question | Where the answer comes from |
| :--- | :--- |
| What is done and working? | the diff, the tests that pass |
| What is half-done, and how far? | the diff, `TODO` markers, stubbed returns |
| What was decided, and why that way? | the session — this is the part nothing else records |
| What was tried and abandoned? | the session, and any reverted or stashed work |
| What is the very next thing to do? | wherever the work stopped |
| What is not known? | anything asserted this session without being checked |

### 3. Write the file

Run `git check-ignore -q .scratch` first. When it fails, add one line to the
report saying the handoff will show up in `git status`, and let the user decide.
Do not edit `.gitignore`.

Take the timestamp from the injected `date` output above — do not guess it, and
do not reuse one from an earlier file. Write
`.scratch/handoffs/<YYYY-MM-DD>-<HHMM>-<slug>.md` in the format below.

### 4. Report

Print the path, the scope in one line, the **Start here** block verbatim, and the
next step. Not the whole document — the receiver reads the file, and the person
who just invoked this was there for the rest of it.

Then say how to hand it over: the file is in a gitignored directory, so it does
not travel on its own. The receiver needs the path, or the file's contents pasted
to them.

## Output format

`.scratch/handoffs/<YYYY-MM-DD>-<HHMM>-<slug>.md` — a contract. Keep the
frontmatter keys and the headings verbatim; `--resume` reads them back. Delete
any section that has nothing real in it.

```markdown
---
handoff: <human title, one line>
slug: <slug>
written-at: <YYYY-MM-DD HH:MM>
scope: whole session | <the topic, one line>
status: in progress | blocked | decided, not started
branch: <name> | none
base: <sha of the commit the work sits on>
tracker: issue #<n> | pr #<n> | none
paths:
  - <every path this handoff makes a claim about>
---

# <title> — handoff

## Start here

<Three to six lines addressed to whoever picks this up. What to read first, in
what order, and what to do before touching anything. Written so an agent given
only this path can act on it, and a person can read it without scrolling.>

## Where things stand

<Plain language, with paths. What works, what is half-written and how far it
got, what is stubbed. Enough that the receiver can tell the difference between
"not started" and "started and looks finished but is not".>

## Decisions and why

| Decision | Why | Where it shows up |
| :--- | :--- | :--- |

## Tried and rejected

| Approach | Why it was dropped |
| :--- | :--- |

## Next step

<One concrete action, specific enough to start on. Not "continue the refactor" —
the file, the function, and what to do to it.>

## Open questions

- <what is not known, and who or what would answer it>

## State on disk

| Path | State | In scope |
| :--- | :--- | :--- |

<One line on anything uncommitted, stashed, or deliberately left dirty.>
```

## Resume

Read-only. This mode briefs; it does not continue the work it describes. Ending a
resume with an edit is the failure this mode exists to prevent — the receiver has
not read the document yet, and the document may be stale.

- [ ] 1. Select the handoff
- [ ] 2. Re-ground it
- [ ] 3. Brief

### 1. Select the handoff

`--resume` with no slug takes the last entry from the injected listing above —
the `<date>-<time>` prefix makes filename order chronological order. `--resume
<slug>` takes the newest file whose name ends in that slug.

No `.scratch/handoffs/` directory, or no match for the slug, is a stop: say what
was looked for and what is there instead. Do not fall back to the newest file
when a slug was named, and do not reconstruct a handoff from git.

Name the file and its `written-at` before reading further, so a wrong pick is
visible now rather than after the brief.

### 2. Re-ground it

The document describes a tree that may have moved. Check it before repeating any
of it:

```sh
git rev-parse --abbrev-ref HEAD
git merge-base --is-ancestor <base> HEAD
git log --oneline <base>..HEAD -- <every path in the frontmatter>
git status --short -- <every path in the frontmatter>
```

| Finding | What it means for the brief |
| :--- | :--- |
| On a different branch than `branch:` | Say so first. Everything below may be about work not present here. |
| `base` is not an ancestor of `HEAD` | The branch was rebased or reset. Paths still resolve; SHAs in the document do not. |
| Commits touched paths in scope | List them. The next step may already be done, or done differently. |
| Nothing moved | Say that in one line — a clean brief is a finding, not an empty result. |
| Not a git repository | Say no check was possible, and that the document is undated evidence. |

Where the document and the tree disagree, the tree wins and the brief says which
line of the document is now wrong.

### 3. Brief

Print this and stop:

```markdown
**Handoff:** `<path>` — <title>
**Written:** <written-at> (<n> days ago) · **Scope:** <scope> · **Status:** <status>

<the Start here block, verbatim>

**Next step as written:** <the next step>

**Drift since:** <branch, base, and paths — or "nothing moved">
**Now wrong:** <each line of the document the tree contradicts — omit when none>

**Open questions carried over:** <list — omit when none>
```

Nothing after this without the user saying what to do. The brief is the whole
output of this mode.

## Anti-patterns

| Do not | Instead |
| :--- | :--- |
| Write the tidy version of the session | Record the approach that failed and the reason, in **Tried and rejected** |
| Fill every heading | Delete the sections with nothing in them |
| Summarise the diff | The receiver can read the diff; write what the diff does not say |
| Write "continue where I left off" as the next step | Name the file, the function, and the change |
| Recall what the code looks like | Read the paths in scope before writing about them |
| Continue the work during `--resume` | Print the brief and stop |
