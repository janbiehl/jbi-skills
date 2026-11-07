# Style guide for technical articles

House rules for the draft. They apply to German and English texts alike; the
German-specific rules are marked. The medium's own style guide overrides
anything here.

## Contents

- [Structure](#structure)
- [Sentences](#sentences)
- [Terminology](#terminology)
- [Numbers and units](#numbers-and-units)
- [Code](#code)
- [Figures, tables, boxes](#figures-tables-boxes)
- [Sources](#sources)
- [Phrases to avoid](#phrases-to-avoid)

## Structure

- **Open with the reader's problem**, not with history or a definition. The
  first paragraph says what the article is about and why the reader should care;
  the Kernaussage appears in it or right after it.
- **One thought per paragraph**, usually three to six sentences. A paragraph
  that needs "außerdem" halfway through holds two thoughts.
- **Content headings.** "Warum der Cache bei Lastspitzen kippt", not
  "Problemanalyse". A reader who skims only the headings should get the argument.
- **Show, then generalise.** The example comes early in a section, the rule
  after it. Abstract first, example last loses the reader in between.
- **The conclusion adds something** — a recommendation, a next step, a limit —
  instead of repeating the sections. No "Zusammenfassend lässt sich sagen".

## Sentences

- Average sentence under ~20 words; a long one now and then is fine, a run of
  them is not.
- **Active voice and verbs.** "Der Scheduler verteilt die Jobs" rather than
  "Die Verteilung der Jobs erfolgt durch den Scheduler". (German) Watch
  *Nominalstil*: "-ung", "-heit", "-keit" stacked with "erfolgen", "durchführen",
  "vornehmen" is a verb hiding in a noun.
- **Say who does it.** "Man" and the passive hide the actor; in a technical text
  the actor is usually the point (the user, the service, the compiler).
- **Concrete over general.** "Die Antwortzeit stieg von 80 ms auf 1,2 s" beats
  "die Performance verschlechterte sich deutlich".
- **No hedging stack.** One "in der Regel" is information; "könnte unter
  Umständen eventuell" is noise.
- Address and perspective stay as agreed in the briefing for the whole text.

## Terminology

- **One term per concept**, the whole way through. If it is "Endpunkt" in
  section 2, it is not "Schnittstelle" in section 4 — the reader will assume
  they are two things.
- **Abbreviations** spelled out at first use: "Role-Based Access Control
  (RBAC)". Skip it only for what every reader of the medium knows (HTTP, API).
- **English terms of the field stay English** when that is how practitioners
  say them ("Pull Request", "Deployment"). Do not force a translation nobody uses,
  and do not anglicise what has a common German word.
- (German) **Compounds with English or abbreviated parts are hyphenated**:
  "Docker-Container", "API-Schlüssel", "Open-Source-Projekt". Product names keep
  their own spelling.
- (German) **Gendern** as agreed in question 8. When the agreement is "neutral
  formulieren", use plural and role nouns ("Entwicklungsteam", "Lesende" only
  where it reads naturally) rather than a mix of forms.

## Numbers and units

- A space between number and unit, non-breaking where the format allows it:
  `100 ms`, `16 GB`, `25 %` (German), `25%` (English).
- (German) Decimal comma and thousands point or thin space: `1,5 s`,
  `12.000 Anfragen`. (English) `1.5 s`, `12,000 requests`.
- (German) In running text, numbers up to twelve are usually written out
  ("drei Dienste") — except with units, in tables, and in technical values.
- Units are SI or the field's standard; do not mix `MB` and `MiB` in one text.
- Every number traces to the interview or the material, or it carries
  `[PRÜFEN: …]`.

## Code

- **Inline code** for every identifier, file name, command, and value:
  `appsettings.json`, `kubectl apply`.
- **Listings** are short and do one thing. Name the language on the fence. A
  listing over ~25 lines is either an excerpt — say so — or belongs in a linked
  repository.
- **Every listing is introduced in the text** before it appears ("Listing 2
  zeigt …") and explained after it, at the lines that matter. A listing nobody
  points to is skipped by the reader.
- Code must be correct for the versions stated in the article. Shortened code
  marks the cut (`// …`).
- Number listings when the medium does: "Listing 1: <Bezeichnung>".

## Figures, tables, boxes

- Number figures and tables; each has a caption that says what to see in it,
  not just what it is: "Abbildung 2: Die Latenz steigt erst ab 500 parallelen
  Verbindungen", not "Abbildung 2: Latenz".
- Reference each one in the text before it appears.
- A table is for comparing along the same criteria. Three facts in a row are a
  sentence.
- An info box (Kasten) holds what a part of the audience needs and the rest can
  skip: a definition, a prerequisite, a side note. It is not where the
  argument goes.

## Sources

- Use the medium's citation style. Default: numbered references in the text,
  `[1]`, and a numbered list at the end with author or publisher, title, and URL.
- Cite only sources the user or the material provided, or that the user
  approved. Never construct a plausible-looking reference.
- Quotes are verbatim, attributed, and come from the material — or they are not
  quotes.

## Phrases to avoid

Filler and marketing language cost a technical author credibility, and the
patterns below make a text read as machine-written. Scan the draft for them
before measuring.

**Openers and transitions**
- "In der heutigen (schnelllebigen / digitalen) Welt …", "In today's fast-paced world …"
- "Es ist wichtig zu beachten, dass …", "Es sei darauf hingewiesen …", "It is worth noting …"
- "Zusammenfassend lässt sich sagen …", "Abschließend …" as the first word of the conclusion
- "Doch was bedeutet das konkret?" and other rhetorical questions used as a bridge
- "Tauchen wir ein …", "Let's dive in …"

**Inflated words**
- revolutionär, bahnbrechend, nahtlos, Game-Changer, robust (without saying
  against what), leistungsstark, innovativ, ganzheitlich, Mehrwert, Synergien
- "einfach", "schnell", "nur" for things that are only easy for the author —
  they make the stuck reader feel stupid

**Patterns**
- A list of three for everything; real arguments rarely come in exact triples
- "nicht nur …, sondern auch …" more than once in the text
- Em-dash or Gedankenstrich in every other sentence
- Bold scattered through running text; bold is for terms at first definition
- Emojis, unless the medium is social and the user wants them
- A closing paragraph that repeats each section in order
