# Wide refactors

Read this when the plan contains a mechanical change whose blast radius fans across
the codebase — renaming a database column, retyping a shared symbol, changing a
signature every module calls. Everything else in the plan still gets vertical slices.

## Why they break vertical slicing

A vertical slice promises a complete path through the layers that is green on its own.
A wide refactor breaks that promise mechanically: the edit that renames the symbol
breaks every call site at once, and there is no narrow path through the layers that
contains the damage. Forcing it into a tracer bullet produces one enormous ticket that
is red for its entire life, which is the failure mode this skill exists to avoid.

Recognise one by the ratio: the change is conceptually trivial and touches hundreds of
sites. That is a wide refactor, not a feature.

## Expand, migrate, contract

Sequence it as three kinds of ticket.

**Expand** — one ticket. Add the new form beside the old one. Both exist; nothing
calls the new form yet; the build stays green because nothing was taken away. New
column added alongside the old, new overload beside the existing signature, new type
exported next to the deprecated alias.

**Migrate** — several tickets, each blocked by the expand ticket. Move call sites to
the new form in batches sized by blast radius: one package, one directory, one bounded
context per ticket. Every batch is green on its own, because the old form still exists
for everything not yet migrated. Size the batches so a batch is reviewable — the point
of batching is that a human can read the diff, not that the work is subdivided.

**Contract** — one ticket, blocked by every migrate ticket. Delete the old form once
no caller remains. This is the ticket that makes the refactor real; without it the
codebase carries both forms indefinitely, which is worse than where it started.

The resulting graph is a diamond: one expand at layer 0, the migrate batches spread
across layer 1, the contract alone at layer 2.

## When the batches cannot be green alone

Some changes have no expand step — a schema constraint that cannot be duplicated, a
protocol version both ends must agree on. Keep the same sequence, but let the batches
share an integration branch and add a final integrate-and-verify ticket blocked by all
of them. Green is promised only at that last ticket.

Say so explicitly in the ticket bodies. A ticket that will not be green on its own
violates the rule the rest of the plan follows, and an implementer who does not know
that will assume they broke something.
