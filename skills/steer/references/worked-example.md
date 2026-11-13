# Worked example — the Pulse day, 2026-11-13

> **Project-specific. Illustration only.** Names, PR numbers and checks
> belong to that repository. Do not copy them into another project.

**Setup.** The user handed over two running sessions with ISO PRs: #2879
(remote access) and #2880 (recovery mode). They asked the steering session to
orchestrate both merges, and later a six-item follow-up list after a field
incident (silent data-lake compaction failure).

**What happened, in order:**

1. #2879 was green, and the user said "merge #2879". It was squash-merged
   pinned to `f6a136f`. The recovery session was told to bring main in. Its
   Auto-fix rule meant it merged main rather than rebasing.
2. The user pasted an integration lead: the recovery sudo rules were keyed to
   user `pulse`, while #2879 moved its rules to a group. That was routed to
   the recovery session as six points. The answer came back
   point by point: fixed, covered or left. All VM checks ran on the local
   builder. Then "merge #2880" was merged pinned to `451a3b5`, and main's
   tree was checked equal to that head.
3. Lake items 1, 2 and 5 started in parallel, each in its own worktree on
   Opus, with "do not edit X, session Y owns it" in each brief.
4. #2882 got an independent review that found real defects. One finding
   was a product fork (an alert would reach every hosted customer), which went
   to the user as option A or B. They chose B, which was built as #2883,
   stacked on #2882.
5. The 5-hour usage limit stopped three sessions. After the reset, each
   one was messaged to continue, and the user got a state table.
6. "Mark ready when e2e is green" stalled because nothing wakes a
   session on green. The user asked why polling isn't allowed. The answer was
   that the rule was read too strictly, and a single waiting command was
   offered.
7. #2884 (Diagnostics lake block) was merged on its own VM result, then
   #2882. Main turned red: #2884's subtest asserted "not available", but
   with #2882's table a fresh box reads "no runs recorded yet". The fix was
   routed to the session already in that test code, and other sessions were
   told not to fix it themselves.
8. #2882 and #2883 were merged together, #2882 first. #2883 then conflicted
   (squashed base), so main was merged into it in a scratch worktree, the
   diff was checked to be exactly its own nine files, and it was merged pinned.
   CI on that last commit was not waited for. That was disclosed afterwards;
   it should have been said before.
9. For the resource-weights PR, a memory limit of 80% was proposed. "Why
   80?" got the answer that it wasn't derived from anything, with a table
   of what is actually known. The user chose 80, shipped as a "guard against
   a runaway service, not a tuned value".
10. Lake repair went through `brainstorm` (answered "A", "A", "D", …), then
    `to-tickets` into a nine-ticket epic. Only the unblocked T1 was started,
    with the user's words "the design is not open for re-discussion" in the
    brief.
11. T1's independent review found a blocker that green tests missed. It
    could have led the next ticket to write off a whole lake. The user made
    review-on-every-PR a standing rule and asked for the same reviewer to be
    pinged for the second pass.

**User preferences that came up that day** (all in memory there):

- workers on Opus;
- VM tests once at the end, on the local builder and not in CI;
- clean up stale worktrees unasked;
- a dedicated review session for every PR;
- interviews in prose, one question at a time;
- rough issues;
- do not auto-archive the steering session.

**A brief that worked (the T1 implementer), in outline:** what the product is
and where the data lake lives. The incident and the customer waiting. The epic
and which tickets wait on this one. "The design is settled and not open for
re-discussion". The lake owner's open PR and the function to stay out of. The
user's preferences. Where to look, file by file. Facts already verified
against the pinned library version. Traps (a destructive codegen command, run
tests in the foreground). How the output will be consumed by later tickets.
Draft PR, no merge.
