---
name: brainstorm
description: Interviews the user about a feature, change, or design one question at a time until both sides hold the same picture, then writes up the decisions. Every question comes with a short summary, a running estimate of how many questions are left, and at least three options with pros and cons. Use whenever the user wants to brainstorm, discuss, think through, stress-test, or align on a feature, plan, or approach before building it — including phrasings like "let's brainstorm", "let's discuss", "walk me through the options", "how should we design X", "lass uns das durchsprechen", or an idea described without a decision attached.
argument-hint: "[feature, plan, or file to discuss]"
disallowed-tools: AskUserQuestion
allowed-tools: Read Grep Glob
---

# Brainstorm a feature

Interview the user about $ARGUMENTS until you both hold the same picture of what
gets built, then hand back a written record of what was decided.

If no subject was passed, take it from the recent conversation. If there is none,
ask what to discuss — that opener is not question 1.

## Ground rules

**Never call `AskUserQuestion`.** Every question goes in the message text. The
tool renders short labels only; this interview needs a summary paragraph, a
progress line, and a pro/con list under each option, none of which survive it.
The frontmatter blocks the tool for the invoking turn only, so treat this rule as
standing for the whole conversation.

**One question per message.** Two questions in one message get one answer, and
the second decision quietly gets made by whoever writes the code later.

**Recommend, don't survey.** The first option is your recommendation and is
labelled as such. A list of neutral alternatives moves the work back onto the
user, which is the opposite of the point. When you genuinely have no preference,
say that explicitly and give the tiebreaker you would use.

**Ground the options in this codebase.** Before the first question, read what the
feature touches: the modules involved, the patterns it should match, how similar
things are already solved here. Enough to make the trade-offs concrete — not a
full audit. Options that would fit any project are a sign this step was skipped.

**Disagree once, then commit.** If a choice is a mistake, say so plainly with the
reason, and record it. If the user holds their position, take it as decided and
move on — do not relitigate it in a later question.

## Workflow

1. **Orient.** Read the relevant code. Note what is already decided by existing
   structure — those are constraints, not questions.
2. **Map the decisions.** List the consequential open decisions. Order them by
   blast radius: a decision that constrains other decisions comes first, so its
   answer can prune the ones below it.
3. **Show the map.** Open with the agenda — one plain line per decision you
   expect to cover — so the user sees the whole shape before answering anything.
4. **Ask**, one at a time, in the format below.
5. **Re-map after every answer.** An answer closes some branches and opens
   others. The estimate moves with it.
6. **Stop when converged**, then write the summary.

Skip anything already settled — by the codebase, by an earlier answer, or by the
user's opening message. Asking about a decision the user already made reads as
not having listened.

## Opening message

Before the first question, post the agenda: one plain-language line per decision
you expect to cover, in the order you plan to ask them.

```markdown
Here is what I think we need to settle, roughly in this order:

1. **<Topic>** — <what the decision is, in one plain sentence>
2. **<Topic>** — <...>
3. **<Topic>** — <...>

Any answer is fine — a letter, a mix, or something not on the list.
```

The agenda is a forecast, like the estimate. Re-post it only when it changes
materially — a decision dropped, two new ones opened — and say in a clause what
moved. Do not repeat it under every question, and do not repeat the "any answer
is fine" line either.

## Question format

```markdown
**Question 3 · Where config lives** · 2 answered · ~4 more expected

<Two or three sentences in plain language: what has to be decided, and why it
matters for this feature. State the consequence, not the category.>

**A. <Option name>** — recommended
- Pro: <concrete benefit here, not in general>
- Con: <what it costs>

**B. <Option name>**
- Pro: <...>
- Con: <...>

**C. <Option name>**
- Pro: <...>
- Con: <...>

**Detail** *(optional)*

<A paragraph or two, a code sketch, or a reference to what you found in the
code. Only when the summary and the pro/con lines genuinely cannot carry it.>
```

Rules for the parts:

- **Topic.** Two to four words naming the decision, taken from the agenda line
  it came from. It tells the user which part of the system is on the table
  before they read anything else. Name the thing being decided, not the
  category — "Where config lives", not "Configuration".
- **Header line.** Questions answered so far, plus how many more you expect. The
  second number is a forecast, not a quota — it is allowed to rise. When it moves
  by more than about two, say why in a clause ("that opened up caching, so a few
  more than I thought").
- **Summary.** Two to three sentences, in plain language. The first one says what
  is on the table without assuming the user has the code open; spell out any
  codebase term, file name, or abbreviation the first time it appears. Enough
  that the user can decide without scrolling up; short enough to read in one
  pass.
- **Options.** At least three, real ones. If the third is filler, the question is
  really a yes/no — ask it as a yes/no with the two honest alternatives plus the
  option of deferring. Include "do nothing / defer this" wherever that is a
  genuine choice, and say what breaks if it is deferred.
- **Pros and cons.** One line each, one or two of each. Specific to this
  codebase. "More flexible" and "adds complexity" are placeholders, not answers.
- **Detail.** Optional, and last, so the question stays decidable without it.
  Use it when the constraint needs more room than a line: a trade-off with a
  second-order consequence, something found in the code worth quoting with a
  `file.ts:42` reference, or a sketch of what an option would actually look like.
  Leave it out entirely when the summary and options already say everything —
  a Detail block under every question trains the reader to skip it, which
  defeats the point of having one.
- **No new decisions in Detail.** It explains the question that was already
  asked. If it contains something the user has to choose, that is the next
  question, not a footnote to this one.

## Reading answers

- A letter is a decision. Record it and move on.
- A partial or mixed answer ("A, but not the migration part") is also a decision.
  Restate it in one line so the record is unambiguous, then continue.
- A question back is not an answer. Answer it, then re-ask, adjusting the options
  if the exchange changed them.
- "I don't know" means the option set is wrong or the decision was premature.
  Narrow it, or park it as an explicit assumption and move on.

## When to stop

Converged means: every consequential decision is answered or explicitly parked,
no open branch is left dangling, and the user could describe the design to
someone else without you in the room. Not: the estimate hit zero.

Stop early when the user says they have enough. Stop and say so when the
remaining questions are implementation details that the code will answer faster
than the conversation will.

## Final summary

Close with this, in the chat:

```markdown
## What we decided

| # | Decision | Choice | Why |
| :- | :--- | :--- | :--- |
| 1 | <the decision> | <what was chosen> | <the reason given> |

## Parked

- <decision deferred> — <what triggers revisiting it>

## Assumptions

- <anything answered by assumption rather than by the user>

## Open risks

- <what could still go wrong, and the earliest signal it is going wrong>
```

Leave out a section that has no entries rather than writing "none". If the user
wants this on disk, write it where they ask; do not create files unprompted.
