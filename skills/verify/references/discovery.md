# Discovering the project's declared commands

Read during step 1. This file is about *finding* commands, never about supplying
them. No command in this file is a default to fall back on — there are none.

## Contents

- [Precedence](#precedence)
- [Where CI definitions live](#where-ci-definitions-live)
- [Reading a pipeline into gate commands](#reading-a-pipeline-into-gate-commands)
- [Contributor docs](#contributor-docs)
- [Task-runner manifests](#task-runner-manifests)
- [Matching a command to a gate](#matching-a-command-to-a-gate)
- [Aggregates](#aggregates)
- [Deciding `not runnable here`](#deciding-not-runnable-here)
- [What to record](#what-to-record)

## Precedence

CI pipeline, then contributor docs, then task-runner manifests. Earlier wins on
conflict. The reason is prediction: CI is the definition of a change this project
will accept, so a local run that mirrors it tells you something about the remote
outcome. Docs and manifests describe convenience entry points, which drift.

Start by listing the repository root. Work from the files that are actually
there. Do not probe for the conventional manifest of an ecosystem you assume the
project uses — an assumed file that happens to exist is still an assumption, and
the command it yields is unverified.

## Where CI definitions live

| CI system | Location |
| :--- | :--- |
| GitHub Actions | `.github/workflows/*.yml` |
| GitLab CI | `.gitlab-ci.yml`, plus anything it pulls in via `include:` |
| Azure Pipelines | `azure-pipelines.yml`, `.azure-pipelines/` |
| Jenkins | `Jenkinsfile` |
| CircleCI | `.circleci/config.yml` |
| Buildkite | `.buildkite/pipeline.yml` |
| Bitbucket Pipelines | `bitbucket-pipelines.yml` |
| Drone / Woodpecker | `.drone.yml`, `.woodpecker.yml` |
| TeamCity | `.teamcity/` |

More than one may be present — a repo mid-migration often has two. Prefer the one
whose runs are wired to pull requests; if that is not decidable from the files,
report the ambiguity in the **Not verified** section rather than picking silently.

## Reading a pipeline into gate commands

Extract only the steps that *run* something. Skip checkout, toolchain setup,
caching, artifact upload, and notification steps — they are runner plumbing, not
verification.

- **Resolve indirection** where the file defines it: variables, anchors, reusable
  job templates, and steps that call a task-runner target. A step that invokes a
  named target means the target is the command; record both.
- **Matrix jobs** collapse to one representative command. Note in the report that
  the pipeline runs it across a matrix this run did not reproduce.
- **Conditioned steps** — those gated to a branch, a tag, a schedule, or a label —
  may not apply to this change. Include one only when its condition holds for the
  target, and say so.
- **Ordering in the pipeline is not the order to run in.** Gates run cheapest
  first (format, build, unit, integration, e2e). Follow the pipeline only where it
  encodes a real dependency, such as a stage that consumes another's artifacts.

## Contributor docs

`CLAUDE.md`, `README`, `CONTRIBUTING`, or a docs directory. Look for a section on
building, testing, or local development, and take commands as written. A doc
command that contradicts CI loses, but is worth a line in the report — the drift
itself is useful to know about.

## Task-runner manifests

Whatever declares named, runnable entry points in this repo: a make-style target
file, a task-runner config, a script block inside the project's own manifest.
Read the names and, where present, their descriptions. Only entries that plainly
correspond to a gate count; a manifest full of deploy and codegen targets
contributes nothing here, and that is a normal outcome.

## Matching a command to a gate

Match on what the project's own labels claim, not on the tool being invoked:

| Gate | Labels that indicate it |
| :--- | :--- |
| Format | format, fmt, lint, style, check-style, whitespace, analyzers |
| Build | build, compile, package, bundle, publish-artifacts |
| Unit | test, unit, spec |
| Integration | integration, it, api-test, contract, db-test |
| E2E | e2e, end-to-end, acceptance, browser, ui-test, smoke |

When two candidates fit one gate, prefer the CI one; if both are in CI, prefer
the one that runs on every pull request over one restricted to a branch or tag.
When a project's own vocabulary cuts differently from this table — its "smoke"
job is a build check, say — follow the project. The table is a starting point,
not an authority over the repo it is being applied to.

A gate with no match is `not configured`. That is a finding, not a failure.

## Aggregates

One entry point often covers several gates. Record the command once against the
first gate it covers, and mark the others `merged into <gate>`.

Do not split an aggregate by inventing a filter, a tag selector, or a project
subset to separate unit from integration. Constructing that filter means guessing
which convention this repo uses to distinguish them, and a guess that runs a
subset reports coverage the run did not have. Report the merge honestly instead —
"unit and integration ran together under `<command>`" is accurate and useful;
three separate rows from one command are neither.

## Deciding `not runnable here`

A gate is `not runnable here` when its command exists but this environment cannot
satisfy it: a service or container it needs, a credential, a browser or device
runtime, a runner-only tool. Check first whether the project ships a way to bring
those up locally and whether its docs point at it — if so, that is part of the
gate, so use it. If not, record the gate as `not runnable here` with the specific
missing piece named. "e2e not runnable here, requires a live database the repo
provides no local setup for" is actionable; "e2e skipped" is not.

## What to record

For every gate, before running anything: the command verbatim, the file it came
from, and any condition attached to it. The report shows the source, which is
what lets someone check the precedence rule was applied correctly instead of
taking the verdict on trust.
