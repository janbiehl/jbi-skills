# Skill Design Specification

House standard for every skill in this repository. It fixes the decisions that
should not be re-argued per skill: what qualifies as a skill, how skills are
named and laid out, what goes in the frontmatter, how the body is written, and
how workflow skills that drive subagents are structured.

**Target platform:** Claude Code only. The full Claude Code frontmatter surface
is allowed. Skills here are *not* required to be uploadable to claude.ai, Cowork,
or the Skills API — those paths accept only six frontmatter fields and would
reject most of what we use.

**Distribution:** symlinks. Each skill directory is linked into
`~/.claude/skills/<name>`. Claude Code follows the symlink and reads `SKILL.md`
from the target, so edits in this repo are live in the next session.

**Standing constraint:** every skill is self-contained. A skill is a unit that
can be linked on its own, on a machine where no other skill in this repo exists,
and still work. See §2.

---

## Contents

- [1. What qualifies as a skill](#1-what-qualifies-as-a-skill)
- [2. Self-containment](#2-self-containment)
- [3. Repo layout](#3-repo-layout)
- [4. Naming](#4-naming)
- [5. Frontmatter contract](#5-frontmatter-contract)
- [6. The description field](#6-the-description-field)
- [7. Writing the body](#7-writing-the-body)
- [8. Progressive disclosure](#8-progressive-disclosure)
- [9. Context lifecycle](#9-context-lifecycle)
- [10. Orchestration patterns](#10-orchestration-patterns)
- [11. Safety rules](#11-safety-rules)
- [12. Anti-patterns](#12-anti-patterns)
- [13. Template](#13-template)

---

## 1. What qualifies as a skill

Write a skill when the same instructions, checklist, or multi-step procedure
gets pasted into chat repeatedly, or when a section of CLAUDE.md has grown from
a fact into a procedure. A skill's body loads only when used, so reference
material that would bloat CLAUDE.md costs nothing until it is needed.

Pick the right mechanism before writing anything:

| Need | Mechanism |
| :--- | :--- |
| Facts that apply to every turn in a repo | CLAUDE.md |
| A procedure, checklist, or body of domain knowledge loaded on demand | **Skill** |
| A persona with its own system prompt and tool set, delegated to repeatedly | Subagent — but see §2.5 before making a skill depend on one |
| Access to an external system's API | MCP server |
| A one-off instruction | Just say it in the prompt |

A skill is the right answer when the value is *procedural knowledge*, not access
and not identity. A skill may spawn subagents; a skill is not a substitute for
one.

**One skill, one job.** If a description needs "and also" to be honest, split it.
Overlapping descriptions make the model pick wrong, and the cost of a wrong pick
is a whole wasted turn.

---

## 2. Self-containment

Every skill stands alone. Link one skill directory onto a machine where nothing
else from this repo exists, and it works.

**Rules:**

1. **No cross-skill file reads.** A skill reads only files inside its own
   directory (`${CLAUDE_SKILL_DIR}/...`) and files in the user's project. Never
   `../other-skill/references/x.md` — under symlink installation that path
   resolves into this repo, which is not guaranteed to be present, and the skill
   breaks silently on someone else's machine.

2. **No skill invokes another skill.** A skill must not require, suggest as a
   precondition, or call `/another-skill`. It may *mention* one as an optional
   next step for the user, phrased so the workflow still completes if that skill
   is not installed.

3. **No implicit ordering.** A skill must not assume another skill ran first. If
   it needs an input, it detects the input, and says clearly what to do when it
   is absent.

4. **Duplicate rather than share.** Two skills needing the same 30 lines of
   guidance each get their own copy. A shared file is a dependency; a copy is
   not. This spec is the mechanism for keeping copies consistent — consistency by
   convention, not by reference. If the duplicated block grows past roughly a
   page, that is the signal the two skills are really one.

5. **Subagent prompts ship with the skill.** A skill that spawns workers keeps
   their prompts in its own directory (`agents/worker.md`) and passes the content
   as the subagent's prompt, using a built-in agent type. Do not depend on a
   custom agent type being registered in `~/.claude/agents/` or `.claude/agents/`
   — a symlinked skill cannot install one, so that dependency fails on any
   machine that has not been set up by hand.

**What is allowed:** handing off through artifacts on disk. One skill writes a
plan directory, another consumes it. That is a *data contract*, not a code
dependency, and it holds only if:

- the format is documented inside each skill that touches it, not in a shared
  file;
- the consumer works on any input matching the format, whoever wrote it —
  including a human;
- the consumer fails with a clear message when the input is missing or
  malformed, rather than assuming a producer ran.

**Why:** skills are linked individually, adopted individually, and copied into
other people's setups individually. A dependency graph turns a one-line `ln -s`
into a setup procedure, and turns a missing file into a confusing mid-task
failure. The token cost of duplication is zero — bodies load only when invoked.

---

## 3. Repo layout

```text
skills/
  <skill-name>/
    SKILL.md          # required — the only file always loaded when triggered
    references/       # optional — markdown loaded on demand
    scripts/          # optional — executed via bash, never loaded into context
    assets/           # optional — templates, fixtures, files used in output
    agents/           # optional — subagent prompts this skill spawns (§2.5)
SKILLS.md             # this specification
```

Rules:

- Everything a skill needs lives under its own directory. There is no shared
  directory at the repo root that skills read from — see §2.
- `SKILL.md` is the only required file. Do not create empty `references/` or
  `scripts/` directories speculatively.
- Reference files link **directly from SKILL.md**, one level deep. Claude
  partially reads files reached through a chain of references (often via
  `head -100`), which yields incomplete information. `SKILL.md → advanced.md →
  details.md` is a defect.
- Any reference file over ~100 lines starts with a table of contents, so a
  partial read still reveals the full scope of what the file holds.
- Name files by content: `form_validation_rules.md`, not `doc2.md`. Claude
  navigates the directory like a filesystem and picks files by name.
- Forward slashes in every path, always.
- Bundled scripts are addressed as `${CLAUDE_SKILL_DIR}/scripts/foo.py`, never
  by a relative path — the working directory at invocation time is the user's
  project, not the skill directory.

**Installation.** Link each skill, do not copy. `scripts/link-skills.sh`
(macOS, Linux, WSL, Git Bash) and `scripts/link-skills.ps1` (native Windows) do
this for every skill in `skills/`, or for the ones you name:

```bash
./scripts/link-skills.sh link <skill-name>
```

They are idempotent, they never remove a real file or directory, and `status`
reports what is currently linked. See the README for the full option list.

Personal skills override project skills of the same name, and any skill
overrides a bundled skill of the same name. That is a reason to namespace
(§3), not a feature to rely on.

---

## 4. Naming

**The directory name is the command.** For a personal (symlinked) skill, the
frontmatter `name` field is only a display label — `/skill-name` comes from the
directory. Keep `name` identical to the directory name anyway, so nothing drifts
if a skill later moves into a plugin, where `name` *does* set the command.

Rules:

- Lowercase letters, numbers, and hyphens. Max 64 characters. No `claude` or
  `anthropic` — those are reserved and rejected.
- **Use the plain, natural command name.** `/brainstorm`, not
  `/jbi-brainstorm`. These are commands typed dozens of times a day; a namespace
  prefix taxes every one of them to prevent a collision that is rare and
  immediately visible when it happens.
- **Prefix only to resolve an actual collision.** `~/.claude/skills/` is a flat
  namespace shared with bundled skills and every other personal skill, and a
  name collision silently shadows the other skill. When the natural name is
  already taken by a bundled skill or a skill in a project you work in, prefix
  or rephrase — do not ship the shadow.
- Use a verb phrase for skills that *do* something (`brainstorm`, `audit-plan`)
  and a noun phrase for skills that *are* knowledge (`blazor-conventions`). The
  shape of the name should tell the reader which of the two it is.
- Banned: `helper`, `utils`, `tools`, `docs`, `data`, and anything else that
  would be a plausible name for half the repo.
- Terminology stays consistent within and across skills. One term per concept —
  always "slice", never "chunk"/"unit"/"item" for the same thing. Inconsistency
  costs the model parsing effort on every read.

---

## 5. Frontmatter contract

All fields are optional to Claude Code; this spec makes `name` and `description`
mandatory. Declare a field only when it changes behaviour — unused fields are
noise in a file whose job is to be scanned quickly.

```yaml
---
name: example                  # required; matches the directory name
description: ...               # required; see §5
argument-hint: "[plan-slug]"   # when the skill takes arguments
disable-model-invocation: true # when the skill has side effects
allowed-tools: Bash(git status:*) Read Grep
context: fork                  # when the skill runs as an isolated task
agent: Explore                 # only with context: fork
background: false              # only with context: fork
---
```

Field rules:

| Field | House rule |
| :--- | :--- |
| `name` | Required. Equal to the directory name. |
| `description` | Required. See §5. |
| `argument-hint` | Required whenever the body reads `$ARGUMENTS`, `$0`, or a named argument. It is the only thing the user sees at the `/` prompt. |
| `arguments` | Use named arguments (`arguments: [issue, branch]` → `$issue`, `$branch`) once there is more than one positional. `$0`/`$1` in a long body is unreadable. |
| `disable-model-invocation` | **Required `true` for any skill with side effects** — commits, pushes, PR comments, deploys, messages, file mutation outside a scratch dir. The model must not decide *when* those happen. Note the trade-off: the description then leaves the always-loaded listing, so the skill becomes strictly user-invoked. |
| `user-invocable: false` | Only for pure background knowledge that is meaningless as a command. |
| `allowed-tools` | Grant the narrowest patterns that cover exactly what the body tells Claude to run. The grant is turn-scoped and clears on the next user message; it does not restrict anything. Never grant a bare `Bash`. |
| `disallowed-tools` | Use on autonomous loops that must not stop to ask — e.g. removing `AskUserQuestion`. |
| `context: fork` | Only for skills whose body is an actionable task. A guidelines-only skill forked into a subagent produces nothing. See §9. |
| `agent` | Only alongside `context: fork`. Defaults to `general-purpose`. `Explore` and `Plan` skip CLAUDE.md and git status, which keeps a research fork cheap. |
| `background` | Set `false` when the invoking turn needs the result. Default is background. |
| `model` / `effort` | Set only with a stated reason in a comment or in the body. Silent overrides surprise the user and are hard to trace. |
| `paths` | Use for knowledge skills that apply to one file type or package, so they stop competing for attention everywhere else. |
| `hooks` | Last resort. Hooks registered by a skill persist for the whole session; prefer instructions unless behaviour must be enforced deterministically. |
| `metadata` | Free-form, ignored by Claude Code. Do not invent conventions we then have to maintain. |

Malformed YAML does not fail loudly: Claude Code loads the body with empty
metadata, so `/skill-name` still works while automatic triggering silently
never happens. Validate before shipping:

```bash
claude plugin validate ~/.claude/skills
```

---

## 6. The description field

The description is the single highest-leverage line in the skill. It is the only
part loaded at startup, and it is what the model matches a request against when
choosing among a hundred candidates.

Rules:

1. **Third person, always.** "Breaks a plan into vertical slices" — not "I can
   help you break down plans" and not "You can use this to…". The text is
   injected into the system prompt; a shifting point of view degrades matching.
2. **State what it does *and* when to use it.** Both halves, in that order.
   All "when to use" information lives here, never in the body — the body is not
   loaded at decision time.
3. **Include the words a user would actually type**, including the sloppy ones:
   file extensions, tool names, command names, German terms if the user says
   them.
4. **Be pushy.** The observed failure mode is under-triggering, not
   over-triggering. Prefer "Use this whenever the user mentions X, Y, or Z, even
   if they don't say 'skill'" over a neutral summary.
5. **Front-load.** `description` plus `when_to_use` is truncated at 1,536
   characters in the listing, and Claude Code shortens descriptions further when
   many skills are installed. Put the primary trigger in the first sentence.
   Keep the whole thing under ~400 characters unless the trigger surface is
   genuinely wide.
6. **No XML tags.** Max 1,024 characters. Non-empty.

Good:

```yaml
description: Breaks a plan, spec, or design into vertical slices as task files on disk. Use when the user wants to turn a plan into tasks, schedule work, or break down a feature — including phrasings like "split this up", "make tickets", or "was sind die nächsten Schritte".
```

Bad — vague, first person, no triggers:

```yaml
description: I can help you with planning and task management.
```

If a skill is not triggering, the description is the first and usually the only
thing to fix. If a skill triggers too often, make it more specific before
reaching for `disable-model-invocation`.

---

## 7. Writing the body

**Assume the model is smart.** Only add context it does not already have.
Interrogate every paragraph: does Claude need this explanation, or is it a
tutorial about a thing it already knows? A skill that explains what a PDF is has
already failed.

**Imperative voice.** "Read the slice file, then run the test suite." Not "You
should probably start by reading…".

**Explain the why, don't shout.** Writing `ALWAYS` and `NEVER` in caps is a
yellow flag: it means the reason was not written down. A model that understands
*why* test accounts must be filtered generalizes to the case the skill did not
anticipate; one that was only shouted at does not. Reserve emphatic language for
the few genuinely non-negotiable steps.

**Match freedom to fragility:**

| Situation | Form |
| :--- | :--- |
| Many valid approaches, context decides | Prose guidance and heuristics |
| A preferred pattern with acceptable variation | Pseudocode or a parameterized script |
| Fragile, order-dependent, or destructive | An exact command to run, with "do not add flags" |

**One default, with an escape hatch.** "Use `X`. For the scanned-PDF case, use
`Y` instead." Never a menu of five libraries — a list of options makes the model
deliberate instead of act.

**Show, don't describe.** For anything where output shape matters, give
input/output pairs. Two concrete examples beat a paragraph describing the style.

**Templates.** Give the exact skeleton when the format is a contract (a report
another skill parses, a commit message). Give a "sensible default, adapt as
needed" skeleton when it is a starting point. Say which one it is.

**Workflows.** For a multi-step procedure, number the steps and give a checklist
the model can copy into its response and tick off. This is what stops step 4
from being skipped when steps 1–3 went well.

**Feedback loops.** Where quality is verifiable, close the loop explicitly:
run the validator → fix → re-run → only then proceed. The validator can be a
script or a reference document the model checks its work against; both work.

**No time-sensitive statements.** "Before August, use the old API" rots. Put
superseded material under a `## Old patterns` heading in a `<details>` block, or
delete it.

**Length.** Keep `SKILL.md` under 500 lines. Approaching that limit is the
signal to add a layer of hierarchy (§7), not to compress prose.

---

## 8. Progressive disclosure

Three loading levels, three different costs:

| Level | Loaded | Cost |
| :--- | :--- | :--- |
| `name` + `description` | Always, at startup | ~100 tokens per installed skill |
| `SKILL.md` body | When the skill is invoked | Its full length, for the rest of the session |
| `references/`, `scripts/`, `assets/` | Only when read or executed | Zero until touched |

Design consequences:

- `SKILL.md` is a table of contents plus the parts needed on *every* run.
  Everything conditional moves into `references/` behind a one-line pointer that
  says what the file contains and when to read it.
- Split by domain, not by size. A skill covering three frameworks gets
  `references/aws.md`, `references/gcp.md`, `references/azure.md`, so a request
  about one never loads the other two.
- Bundled content is effectively free. Ship the complete API reference, the full
  schema, the large example set — the constraint is on `SKILL.md`, not on the
  directory.
- Prefer a bundled script over generated code for anything deterministic and
  repeated. It is more reliable, costs no context (only its output is read), and
  produces the same result every time. If three test runs all made the model
  write the same helper, that helper belongs in `scripts/`.
- State the intent explicitly for every bundled script: "Run
  `${CLAUDE_SKILL_DIR}/scripts/x.py`" (execute) versus "See
  `scripts/x.py` for the algorithm" (read). The default is execute.
- Scripts solve problems, they do not defer them. Handle the missing file and
  the permission error inside the script instead of failing and leaving the model
  to guess. Justify every constant in a comment — a magic `TIMEOUT = 47` the
  author cannot explain is one the model certainly cannot.

---

## 9. Context lifecycle

Claude Code renders `SKILL.md` into the conversation once, as a single message,
and it **stays there across subsequent turns**. The file is not re-read. This
has direct authoring consequences:

- Every line is a recurring cost for the rest of the session, not a one-time
  one. This is the real argument for conciseness.
- Do not write instructions that assume a fresh read ("re-read this file before
  each step"). Write guidance that still reads correctly ten turns later.
- Re-invoking a skill whose rendered content is unchanged adds only a note, not
  a second copy. Content that differs — changed arguments, new output from an
  injected command — is appended in full.
- `allowed-tools` does **not** persist like the content does: the grant clears
  on the next user message. A long-running workflow will hit permission prompts
  after the first turn. Design for that, or re-invoke.
- After auto-compaction, only the first 5,000 tokens of each invoked skill are
  re-attached, within a 25,000-token shared budget. Put the load-bearing rules
  early in the file; a critical constraint buried at line 400 may not survive.
- A skill that "stops working" mid-session is almost always still in context and
  simply being out-competed. The fix is a stronger description and clearer
  instructions, not repetition.

---

## 10. Orchestration patterns

House rules for the workflow skills that make up most of this repo. Three shapes,
and each skill should be recognizably one of them:

**A. Knowledge skill** — conventions, domain facts, platform gotchas. No steps,
no side effects. Model-invocable, often scoped with `paths`. Never `context: fork`
(a subagent handed guidelines with no task returns nothing).

**B. Task skill** — a bounded procedure the user triggers: `/handoff`,
`/audit-plan`. Numbered steps, an explicit output format,
`disable-model-invocation: true` if it writes anything outside a scratch
directory.

**C. Orchestrator skill** — drives subagents through a multi-slice workflow.
The rules below are mainly about these.

### Rules for orchestrators

1. **State lives outside context, not in it.** Plans, work items, and progress
   go somewhere durable — files under a predictable path, or the tracker the work
   already lives on. Context is lost to compaction; neither of those is. An
   orchestrator must be able to resume from that store alone after a fresh start.
   Keep it to one store: status held in two places drifts.

2. **Nothing passes on its author's word.** The agent that implements is not the
   agent that verifies, and a verifier that also wrote the code will pass its own
   work. Keep the verifier read-only in its tool grant. A worker that fixes what
   it reviewed is fine — as long as the independent verifier runs after it, on
   the result.

3. **Subagent contracts are explicit.** Every spawned agent gets: the exact path
   of the file describing its task, the tools it may use, and the *structured
   report format* it must return. The orchestrator parses that report — so
   specify its headings verbatim.

4. **Workers ship with the orchestrator.** Keep each worker's prompt in the
   skill's own `agents/` directory and spawn it against a built-in agent type,
   passing the prompt content. A skill that requires a custom agent type to be
   registered separately is not self-contained (§2.5) and will fail wherever that
   registration is missing.

5. **Subagents return data, not prose.** Their final message is a return value
   consumed by the orchestrator, not a human-facing summary.

6. **The orchestrator owns git.** Workers never commit, push, or touch branch
   state. Concentrating side effects in one place is what makes a failed slice
   recoverable. Stage by explicit path, and where more than one worker writes in
   a slice, stage the union of what they report — a path nobody stages stays
   dirty and lands in the next slice's commit.

7. **Gate on verification, not on optimism.** Advance to the next slice only on
   an explicit PASS, and run verification last, so it judges the tree that will
   actually be committed. On FAIL, the orchestrator decides — retry, narrow, or
   stop and report — and never silently continues.

8. **Isolation when workers write in parallel.** Parallel agents mutating the
   same tree corrupt each other; give them worktrees or run them sequentially.
   Read-only fan-out needs no isolation and should be parallel.

9. **Report what was skipped.** A workflow that caps, samples, or drops work says
   so in its output. Silent truncation reads as complete coverage.

10. **Ask at the right moment.** Front-load decisions that change the whole plan;
   do everything that does not depend on an answer first. An autonomous loop that
   must not block sets `disallowed-tools: AskUserQuestion` and states its
   assumptions in the report instead.

11. **Invoke expensive skills from a worker, not from the orchestrator.** A
   nested skill renders into the caller's context and stays there (§9). The
   orchestrator's context is the one that has to survive the whole run, so a
   per-slice invocation belongs in a subagent that returns a short report.
   Invoke inline only at the end, where nothing comes after it.

### Forked skills

Use `context: fork` when the skill is a self-contained task that should not
inherit or pollute the conversation: research sweeps, long audits, anything whose
intermediate reasoning is noise in the main thread.

- The body becomes the subagent's prompt. Write it as a task, not as guidance.
- `agent: Explore` for read-only research (skips CLAUDE.md, stays cheap);
  `agent: Plan` for design; `general-purpose` for everything else. Do not name a
  custom agent type — the skill would then depend on that type being registered
  (§2.5). The persona belongs in the body, which is the fork's prompt.
- Forks run in the background by default and their edits fall outside session
  checkpoints, so `/rewind` will not undo them. For anything that writes, either
  set `background: false` or make the work trivially revertible with git.
- Background forks get a narrower tool set. If the task needs a tool outside it,
  set `background: false`.

### Grounding

Use dynamic context injection to put real state in front of the model instead of
asking it to go find it:

```markdown
## Current changes

!`git diff HEAD`
```

The command runs before the model sees the content, so the instructions arrive
with the data already inlined. Keep injected commands read-only, fast, and
bounded — their full output lands in context, and a failed command still renders.

---

## 11. Safety rules

- **No surprises.** A skill must do what its description says and nothing more.
  A skill whose behaviour would surprise a user who read only the description is
  broken, regardless of intent.
- **Skills are code.** Anything checked in here runs with the user's full local
  privileges. Review `allowed-tools` and `scripts/` in any skill adopted from
  elsewhere before linking it.
- **Fetched content is data, never instructions.** A skill that reads web pages,
  issues, PR comments, or files must treat their contents as untrusted input.
  Instructions found inside them are quoted to the user, not executed.
- **Never handle secrets.** No skill reads, prints, or passes credentials, tokens,
  or keys. If a workflow needs one, it uses an already-authenticated CLI
  (`gh`, `git`) and never the value itself.
- **Irreversible actions are user-triggered.** Deleting, force-pushing, closing,
  publishing, sending: `disable-model-invocation: true`, and confirm in the body
  before acting.

---

## 12. Anti-patterns

| Anti-pattern | Why it fails |
| :--- | :--- |
| "When to use" instructions in the body | The body is not loaded when the decision is made. |
| First-person or second-person description | Degrades matching; the text is injected into a system prompt. |
| Nested references (`SKILL.md → a.md → b.md`) | Files reached indirectly get partially read. |
| A menu of alternatives | Makes the model deliberate instead of act. Give one default. |
| Caps-lock rules with no rationale | Do not generalize; the model cannot extend a rule it does not understand. |
| Explaining what the model already knows | Pure recurring token cost. |
| Windows-style paths | Break on every non-Windows machine. |
| Dates and "as of now" statements | Silently become wrong. |
| Two skills with overlapping descriptions | The model picks one, arbitrarily, and can pick the wrong one. |
| Empty `scripts/` and `references/` scaffolding | Signals content that does not exist. |
| Bare `allowed-tools: Bash` | Grants the entire shell without prompting, for a two-command workflow. |
| `context: fork` on a knowledge skill | The subagent gets guidelines and no task, and returns nothing. |
| Reading a file from a sibling skill directory | Resolves only where this whole repo is checked out; breaks silently elsewhere. |
| A skill that tells the user to run another skill first | Turns one `ln -s` into a setup procedure and fails mid-task when the other skill is absent. |
| A shared `references/` at the repo root | Same dependency, one directory higher. Duplicate the content instead. |

---

## 13. Template

```markdown
---
name: example
description: <What it does, in third person>. Use when <explicit triggers, including the phrasings a user would actually type>.
argument-hint: "[thing]"
disable-model-invocation: true
allowed-tools: Read Grep Bash(git status:*)
---

# <Human-readable title>

<One or two sentences: what this produces and what it assumes. No tutorial.>

## Workflow

Copy this checklist and tick items off as you go:

- [ ] Step 1: <...>
- [ ] Step 2: <...>
- [ ] Step 3: <...>

### Step 1: <...>

<Imperative instruction. State the why where it is not obvious.>

### Step 2: <...>

Run `${CLAUDE_SKILL_DIR}/scripts/check.py <arg>`. If it reports errors, fix them
and run it again before continuing — <reason>.

## Output format

<Exact template when the shape is a contract; a labelled default when it is a
starting point.>

## References

- <Topic>: see [references/<topic>.md](references/<topic>.md) — read when <condition>.
```

---

## Sources

- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Extend Claude with skills (Claude Code)](https://code.claude.com/docs/en/skills)
- [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- Anthropic `skill-creator` skill, bundled with the anthropic-agent-skills marketplace
