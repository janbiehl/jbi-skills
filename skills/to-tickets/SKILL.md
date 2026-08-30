---
name: to-tickets
description: Breaks a plan, spec, or the current conversation into a graph of thin vertical-slice tickets with explicit blocking edges, published as GitHub issues under an epic or as local markdown files. Use when the user wants to turn a plan into tickets, break a feature into work items, slice a spec into issues, or decompose a design before implementation.
argument-hint: "[spec path | issue URL]"
disable-model-invocation: true
# Read-only detection only. Issue creation and graph mutations stay behind a prompt.
allowed-tools: Bash(gh repo view:*) Bash(gh issue view:*) Bash(git rev-parse:*) Read Grep Glob
---

# To Tickets

Turn a plan into a graph of tickets. Each ticket is a thin vertical slice that cuts
through every layer end to end and declares which other tickets block it.

The skill publishes once and stops. It does not track status, re-label, or reconcile
the graph afterwards — the tracker owns what happens next.

## Pick the tracker

Default to GitHub issues. One command decides it:

```sh
gh repo view --json nameWithOwner -q .nameWithOwner
```

It fails outside a work tree, without a GitHub remote, or when `gh` is not
authenticated — all three cases where GitHub is not an option. On failure, fall back
to local files and say which of the three it was, so the user can fix it and re-run
if the fallback was not what they wanted.

State the resolved target in the review step (step 4) so the user can switch to local
in the same round they approve the breakdown.

## Process

### 1. Gather context

Accepted inputs:

- **The conversation** — the default when no argument is given.
- **A file path** in `$ARGUMENTS` — read it.
- **A URL or issue reference** in `$ARGUMENTS` — fetch it, including comments. Issue
  comments routinely carry decisions that never made it into the body.

Querying a tracker API for related work is out of scope. Work from what you were given.

### 2. Explore the codebase

Read enough to name things the way the project already names them: ticket titles and
bodies use the project's own domain vocabulary, and respect ADRs covering the area
being touched. A ticket that invents its own terms costs the implementer a translation
step on every read.

Where a small preparatory change would make the real change straightforward, make it
the first ticket rather than folding it into a slice.

### 3. Draft the slices

<vertical-slice-rules>

- Each slice cuts a narrow but complete path through every layer it touches — schema,
  API, UI, tests. Vertical, not one horizontal layer.
- A finished slice is demoable or verifiable on its own. This is the floor: a slice
  that can only be judged once a later slice lands is not a slice.
- Prefer many thin slices over few thick ones. Thin slices fail cheaply.
- Give each slice an id `T1`, `T2`, … assigned in dependency order, blockers first.

</vertical-slice-rules>

Give every ticket its **blocking edges**: the tickets that must finish before it can
start. A ticket with no blockers can start immediately. Record only edges that
genuinely gate the work — an edge that is really "these touch the same file" costs a
day of serialised work for nothing.

**Wide refactors are the exception.** A mechanical change whose blast radius fans
across the codebase — renaming a column, retyping a shared symbol — cannot land green
as a vertical slice. Sequence it as expand → migrate in batches → contract, one ticket
per step. Read `references/wide-refactors.md` when the plan contains one.

#### What goes in a ticket

A ticket is self-contained on **meaning**, not on **location**. It states the domain
rules, contracts, and decisions needed to build the thing, in full, so an implementer
never has to recover them from the plan, the epic, or the conversation that produced
it. It refers to code by stable anchors — a module, an endpoint, a domain term — not
by file paths or line numbers.

The reason is the graph: a ticket at depth 3 describes a codebase its blockers have
not built yet, so any path it names is a guess. A decision that was never written
down, by contrast, cannot be recovered at all.

One exception: when a prototype produced a snippet that pins a decision more precisely
than prose can — a state machine, a reducer, a schema, a type shape — inline it and
note that it came from a prototype. Trim to the decision, not a working demo. A schema
is a contract, not a location.

#### Acceptance criteria

Every ticket carries at least one. Each criterion is:

- **Observable** — a check, not an intention. `pnpm test auth.spec passes`, not
  `auth works`.
- **Mechanical where possible** — tests, type checks, command output, HTTP responses.
- **Specific** — names the artifact being checked. `POST /login with valid credentials
  returns 200 and a session cookie`, not `login endpoint works`.
- **Self-contained** — verifiable without a later ticket. If checking it needs T5, the
  criterion belongs in T5.

Where a step genuinely requires a human — a credential pasted in, a console clicked, a
stakeholder's sign-off — say so as a criterion. There is no separate ticket type.

#### Epics

More than one ticket means an epic. The epic states the goal and scope once, so the
tickets do not each re-argue why the work exists, and it holds the dependency graph in
a form a reader can see at a glance. A single ticket needs no epic.

### 4. Review with the user

Show the target tracker, then the breakdown in two views.

**Per-ticket list**, numbered by id:

- **Title** — short and descriptive
- **Blocked by** — ids, or "none"
- **What it delivers** — the end-to-end behaviour this ticket makes work

**Layered dependency graph**, always, even when the chain is linear. The list is where
a wrong edge hides; the graph is where it shows up as a ticket sitting one layer too
deep. Compute `layer = max(layer of blockers) + 1`, with unblocked tickets at layer 0.
Everything on one layer can run in parallel once the layers above are done.

```
Layer 0:  [T1: Session schema]      [T2: Config loader]
              |                          |
              +------------+-------------+
                           |
Layer 1:            [T3: Login flow]        [T4: Profile read API]
                           |                          |
                           +------------+-------------+
                                        |
Layer 2:                     [T5: End-to-end demo]
```

On the local path, also propose the plan slug (`Plan slug: auth-rebuild — change?`),
derived from the source title, so it is settled in the same round.

Then ask: is the granularity right, are the blocking edges real, should anything be
merged or split? Iterate. Treat a clear approval as terminal — do not add a
confirmation round.

### 5. Validate before publishing

Check, and fix silently where the fix is unambiguous — a typo'd reference, a reference
to a ticket that was merged away:

1. Ids are unique.
2. Every `blocked_by` entry names a ticket in this plan.
3. The graph is acyclic.
4. Every ticket has at least one acceptance criterion.

Re-run after fixing. Escalate only when no obvious fix exists. Publishing a cycle
produces a set of tickets none of which can ever start.

### 6a. Publish to GitHub

Write each body to a temp file and pass `--body-file`; issue bodies contain backticks,
newlines, and checklists that do not survive shell quoting intact.

Publish the epic first, then tickets in dependency order, so each body can cite real
issue numbers. Keep a mapping from ticket id to issue number and node id as you go.

```sh
url=$(gh issue create --title "<title>" --body-file "$body")
num=${url##*/}
id=$(gh issue view "$num" --json id -q .id)
```

Attach each ticket to the epic. `subIssueUrl` takes the URL `gh issue create` already
returned, which saves a lookup:

```sh
gh api graphql -f query='
  mutation($epic: ID!, $childUrl: String!) {
    addSubIssue(input: {issueId: $epic, subIssueUrl: $childUrl}) { clientMutationId }
  }' -f epic="$EPIC_ID" -f childUrl="$url"
```

Then add one blocking edge per dependency. This one needs both node ids:

```sh
gh api graphql -f query='
  mutation($issue: ID!, $blocker: ID!) {
    addBlockedBy(input: {issueId: $issue, blockingIssueId: $blocker}) { clientMutationId }
  }' -f issue="$TICKET_ID" -f blocker="$BLOCKER_ID"
```

The native relations are the source of truth for the graph. No readiness labels are
applied: a label saying "blocked" or "ready" is wrong the moment a blocker closes, and
nothing here comes back to fix it.

#### Mark the epic

An epic is a different kind of issue from the tickets under it, and that is worth
recording — unlike readiness, a type never goes stale, so marking it costs nothing to
maintain. Availability differs by repo, so detect first:

```sh
gh api graphql -f query='
  query($o: String!, $n: String!) {
    repository(owner: $o, name: $n) { issueTypes(first: 20) { nodes { id name isEnabled } } }
  }' -f o="$OWNER" -f n="$REPO"
```

**Types available** (`issueTypes` returns nodes — organisation-owned repos). Pick an
enabled type named `Epic` if the org defined one, otherwise `Feature` for the epic and
`Task` for the tickets. Apply it after creation:

```sh
gh api graphql -f query='
  mutation($issue: ID!, $type: ID!) {
    updateIssueIssueType(input: {issueId: $issue, issueTypeId: $type}) { clientMutationId }
  }' -f issue="$ISSUE_ID" -f type="$TYPE_ID"
```

**Types unavailable** (`issueTypes` is `null` — user-owned repos, where the feature
does not exist). Put an `epic` label on the epic only, creating it if absent. The
tickets get nothing; sub-issue containment already tells a reader what they are.

Never call `createIssueType`. Defining a new type changes the whole organisation's
issue vocabulary, which is not this skill's decision to make — if the org wants an
`Epic` type, an admin creates it once and this skill picks it up on the next run.

Verify the result — `gh issue view --json` cannot see any of these fields, so read
them back through GraphQL:

```sh
gh api graphql -f query='
  query($owner: String!, $repo: String!, $n: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $n) {
        parent { number }
        blockedBy(first: 50) { nodes { number title } }
      }
    }
  }' -f owner="$OWNER" -f repo="$REPO" -F n="$num"
```

Report the epic URL and the ticket numbers by layer. Do not close or modify the source
issue if the plan came from one.

### 6b. Publish to local files

```text
.scratch/<plan-slug>/
  README.md          # the epic
  t1-<slug>.md
  t2-<slug>.md
```

One ticket per file, never a combined file. `README.md` is the epic and is written
last, once the ids are final.

## Templates

These are contracts — publish this structure, not an approximation of it.

<epic-template>

## Goal

What this delivers and why, in a paragraph. The tickets do not repeat this.

## Scope

- In scope: …
- Out of scope: …

## Source

Where the plan came from — an issue reference, a spec path, or "planning conversation".
Omit when there is nothing stable to point at.

## Tickets

| # | Ticket | Blocked by |
| :- | :--- | :--- |
| T1 | … | — |
| T2 | … | T1 |

## Dependency graph

The layered graph from step 4, in a fenced block.

</epic-template>

<ticket-template>

## Context

The domain rules, contracts, and decisions needed to build this without reading the
epic, the plan, or the conversation. Stable anchors, not file paths.

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective — not a
layer-by-layer implementation list.

## Acceptance criteria

- [ ] …
- [ ] …

## Blocked by

- #12 — <title>

or "None — can start immediately". On GitHub this restates the native relation for a
human reader; the relation is what any tool should read.

</ticket-template>

<local-ticket-template>

---
id: T2
title: Login flow
blocked_by: [T1]
---

# T2: Login flow

Same four sections as the ticket template above. `blocked_by` carries the graph; the
body's "Blocked by" section lists ids rather than issue numbers.

</local-ticket-template>
