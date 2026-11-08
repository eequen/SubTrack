# Automatic flashcards via an external AI (proposal)

**Status:** proposal only — not implemented, no schema change, no new dependency.
Do not build before the Phase 6 checkpoint and team sign-off (see section 13).

---

## 1. The idea

SubTrack does not call an AI and does not parse PDFs. Instead it hands the
student a **copy-ready prompt** with a **strict output contract**. The student
pastes the prompt into any AI chat app (ChatGPT, Claude, Gemini, …), attaches
their PDF or notes, and gets back a JSON block. They paste that block into
SubTrack, which validates it, shows a preview, and saves a deck. Studying is
offline from then on.

This is "bring your own AI":

- No API key, no cost, no network code inside SubTrack (constraint 2 and 8).
- No PDF extractor, no OCR, no AI dependency (constraint 12 / section 12).
- The external AI does the "understanding"; SubTrack does the **validation**.
- Deterministic, testable import — the hard part is the parser, not the model.

The canonical prompt text lives in
[`docs/prompts/flashcards_v1.txt`](prompts/flashcards_v1.txt) and the machine
schema in [`docs/prompts/flashcards_v1.schema.json`](prompts/flashcards_v1.schema.json).
When this is built, the app must ship that exact prompt text (as a Dart
constant) so the doc and the app cannot drift.

---

## 2. Scope

### In scope (if approved)

- A "Import cards with AI" screen that shows the prompt and a Copy button.
- A paste box plus optional file import (`.json`, `.txt`).
- Strict parsing and validation of the reply.
- A preview where the student edits/deletes cards, names the deck, and picks
  the subject before anything is saved.
- Decks and cards stored locally; study mode (flip, next/previous, shuffle).
- Decks included in the local `.zip` backup (Phase 4).

### Out of scope for v1

- Any in-app AI call, API key, Supabase Edge Function, or background job.
- PDF/DOCX/OCR extraction inside the app.
- Cloud backup of decks (see section 10).
- Spaced repetition, streaks, statistics.
- Auto-generated multiple-choice quizzes (possible later; see section 14).

---

## 3. Flow

```
Subject screen
  └─ Flashcards
       └─ Import with AI
            1. App shows the warning + prompt + [Copy prompt]
            2. Student: AI app → attach PDF → paste prompt → send
            3. AI replies with the JSON contract
            4. Student copies the reply
            5. SubTrack: paste into the box (or import .json/.txt)
            6. App parses + validates → preview (edit / delete / rename)
            7. Student picks the subject → [Save deck]
            8. Deck opens; study mode works offline
```

Nothing is written to the database until step 7. A failed import leaves the
database untouched.

---

## 4. The import contract — `subtrack.cards.v1`

### 4.1 Shape

```json
{
  "schema": "subtrack.cards.v1",
  "deck": "Cell Biology — Chapter 3",
  "cards": [
    {
      "front": "What is the powerhouse of the cell?",
      "back": "The mitochondrion."
    },
    {
      "front": "What does the cell membrane do?",
      "back": "Controls what enters and leaves the cell."
    }
  ]
}
```

### 4.2 Unreadable-document reply

If the AI cannot read the attachment (scanned page, password-protected PDF,
photo too blurry), the prompt asks for:

```json
{ "schema": "subtrack.cards.v1", "error": "cannot read document" }
```

The app shows a friendly message and suggests a clearer scan or a smaller
chapter. `error` and `cards` must not both be present.

### 4.3 Field rules

| Field | Required | Rule |
|---|---|---|
| `schema` | yes | Exactly `subtrack.cards.v1` (case-sensitive). |
| `deck` | prompt requires it; parser tolerates missing | Trimmed, 1–80 characters. Missing/blank → `Imported cards` (student can rename in the preview). |
| `cards` | yes, unless `error` | Array of 1–300 objects. |
| `cards[].front` | yes | Trimmed, 1–180 characters. |
| `cards[].back` | yes | Trimmed, 1–500 characters. Newlines allowed (`\n`). |
| `error` | alternative to `cards` | 1–300 characters. |

Additional rules:

- **Character limits are Unicode code points** (so emoji and accented letters
  count once), measured after trimming.
- **Plain text only.** Any HTML tag (`<a …>`, `<br>`, `<img …>`, `<style …>`)
  is rejected; angle brackets used as math ("a < b") are fine.
- **No markdown** is required or rendered. `*`, `#`, and `-` are allowed as
  literal characters; the app shows them verbatim.
- **Duplicates** are detected on a normalized front (lowercase, trimmed,
  whitespace collapsed, surrounding punctuation removed). Duplicates inside
  one import are dropped with a warning, not an error.
- Unknown top-level fields are ignored (forward compatibility), but a
  different `schema` value is rejected.

---

## 5. The copy-ready prompt (v1)

Design rules behind the wording:

1. It is **English** (models follow English instructions most reliably) but
   tells the model to keep the **document's language** for card content, so
   Tagalog/Taglish notes stay in Tagalog/Taglish.
2. It forbids outside knowledge — accuracy matters more than coverage.
3. It caps lengths **inside the prompt** so validation rarely rejects a card.
4. It asks for JSON only, no code fences, no commentary — the most common
   failure modes are addressed explicitly.
5. It defines the unreadable-document escape hatch.

Exact text (identical to `docs/prompts/flashcards_v1.txt`):

```text
You are creating study flashcards from the document attached to this message.

Follow these rules exactly:
1. Use ONLY facts stated in the document. Do not add outside knowledge.
2. Make 20 to 40 cards. One fact per card.
3. "front" is a short question or a term (maximum 180 characters).
4. "back" is the answer or definition (maximum 500 characters).
5. Write both sides in the same language as the document.
6. Do not duplicate cards. Do not include headers, page numbers, or your own comments.
7. Plain text only: no HTML, no markdown, no bullet symbols. You may use \n for a line break inside "back".
8. "deck" is a short name for the document (maximum 80 characters).
9. Reply with ONE JSON object and nothing else. Do not wrap it in code fences.

Output exactly this shape:
{"schema":"subtrack.cards.v1","deck":"Short deck name","cards":[{"front":"Question or term","back":"Answer or definition"}]}

If you cannot read the attached document, reply with exactly:
{"schema":"subtrack.cards.v1","error":"cannot read document"}
```

The screen also shows, above the Copy button:

> This only copies text. SubTrack never connects to the internet. Your PDF is
> shared with whichever AI app you use, so avoid sensitive documents.

---

## 6. Fallback format: Q/A blocks

Some AI apps refuse to output raw JSON (they wrap it or "helpfully" explain
it). If JSON parsing fails, the importer tries a simple line format:

```
Q: What is the powerhouse of the cell?
A: The mitochondrion.

Q: What does the cell membrane do?
A: Controls what enters and leaves the cell.
```

Rules:

- `Q:` and `A:` at the start of a line, case-insensitive.
- A blank line ends a card; a new `Q:` also ends the previous card.
- Multiple `A:` lines are joined with `\n`.
- Same length limits as the JSON contract; same duplicate handling.
- Source language is whatever the student pasted.

If both parsers fail, the app shows the parse error (section 7.3), never a
partial save.

---

## 7. Parsing and validation

### 7.1 Pipeline

1. **Size guard** — input over 200 KB (UTF-8) is rejected before parsing.
2. **Clean** — trim; strip a leading/trailing triple-backtick fence
   (with or without a `json` tag) if present; if the text is not pure JSON,
   take the substring from the first `{` to the last `}`.
3. **Parse JSON** — `jsonDecode`. On failure, try the Q/A fallback.
4. **Schema check** — `schema` must be `subtrack.cards.v1`. A missing/different
   value is a hard error with a "regenerate using the prompt" message.
5. **Error reply check** — `error` present → show its message; save nothing.
6. **Field validation** — required strings, trimming, length caps, HTML check,
   card count (1–300).
7. **Deduplicate** — normalize fronts; drop repeats; count them for the
   warning banner.
8. **Preview** — build an in-memory `ParsedDeck`; no database writes yet.

### 7.2 Limits

| Limit | Value | Why |
|---|---|---|
| Input size | 200 KB | ~300 cards with long backs; keeps parsing instant. |
| Cards per import | 300 | Beyond this, split the document. |
| `deck` | 80 chars | Fits a card title without wrapping. |
| `front` | 180 chars | One question per card. |
| `back` | 500 chars | A short definition, not an essay. |
| Imported deck name fallback | `Imported cards` | Never save a nameless deck. |

### 7.3 Error messages (user-facing)

| Code | Message |
|---|---|
| `too_large` | That reply is too big to import. Ask the AI to split the document into smaller parts. |
| `parse_failed` | That doesn't look like the prompt's format. Copy the AI's whole reply, including the braces, and paste it again. |
| `wrong_schema` | Those cards were made for a different format version. Copy the prompt again and ask the AI to regenerate them. |
| `unreadable` | The AI couldn't read the document. Try a clearer PDF, a text-based PDF, or one chapter at a time. |
| `no_cards` | No cards were found. Ask the AI to try again with 20–40 cards. |
| `too_many_cards` | That's {n} cards; the limit is 300. Ask the AI to split the document into two decks. |
| `card_too_long` | Card {i} is too long. Ask the AI to shorten it, or edit it in the preview. |
| `html_not_allowed` | Card {i} contains HTML. Ask the AI for plain text. |
| `missing_field` | Card {i} is missing its {front/back}. Regenerate the reply with the prompt. |

Errors appear before the preview; the student stays on the import screen with
their text intact so they can fix and retry.

---

## 8. Preview and save

The preview screen shows:

- Deck name (editable, prefilled from `deck`).
- Subject picker (required; defaults to the semester's first subject).
- "N cards" plus warnings: "2 duplicates were skipped."
- A scrollable list of cards: front, back, Edit, Delete. Editing opens a
  small dialog with the same length limits.
- Buttons: **Save deck** (primary) and **Cancel**.

Saving runs in **one transaction**: insert the deck, then its cards. If any
insert fails, roll back and show an error — no half-imported decks. On success,
open the new deck.

Deleting the deck later cascades to its cards. Deleting the subject cascades
to its decks (existing hierarchy rule, section 8).

---

## 9. Proposed data model (draft — NOT applied)

New drift tables, migration **v3**:

```
decks
  id            integer, primary key, autoincrement
  subject_id    integer, FK subjects.id, ON DELETE CASCADE
  name          text, 1–80 chars
  source        text, default 'manual'   -- 'manual' | 'ai_import'
  created_at    datetime, default now

cards
  id            integer, primary key, autoincrement
  deck_id       integer, FK decks.id, ON DELETE CASCADE
  front         text, 1–180 chars
  back          text, 1–500 chars
  position      integer, default 0
  created_at    datetime, default now
```

Notes:

- A deck belongs to a **subject**, matching the existing hierarchy and the
  Subject screen entry point. An activity-level deck can come later without
  moving data if we add a nullable `activity_id`.
- `source` is included now because adding a column later costs another
  migration; it also gives the paper a clean manual-vs-AI comparison.
- This migration needs explicit team approval (constraint 10). It is not
  written yet.

---

## 10. Backup policy

- **Local `.zip` backup (Phase 4): include decks and cards.** Update
  `BackupRepo` export/import lists and the round-trip test. This is required
  so a wallet-style local restore does not lose decks.
- **Cloud backup (Phase 5): exclude decks in v1.** Cloud tables would need
  new SQL, RLS policies, upload/restore ordering, and quota accounting. The
  UI states "Decks stay on this phone" next to the cloud row so the behavior
  is honest rather than surprising.
- Revisit cloud support after the defense if the feature is kept.

---

## 11. Privacy and safety

- SubTrack makes **no network calls** for this feature. There is no SDK, no
  key, no telemetry.
- The prompt screen warns that the PDF goes to whichever AI app the student
  chooses; sensitive documents should not be uploaded.
- The app **never reads the clipboard automatically** (Android 12+ shows a
  privacy toast and it feels creepy). The student pastes into a text field.
- Imported text is rendered as plain text; no HTML or WebView is involved.
- Input caps prevent memory spikes from a giant paste.
- Nothing is saved until the preview is confirmed.

---

## 12. Test cases

### Parser and validation (unit tests in `core/`)

| ID | Input | Expected |
|---|---|---|
| J1 | Valid JSON object | Deck + cards parsed, counts match. |
| J2 | JSON wrapped in a triple-backtick json fence | Parsed; fence stripped. |
| J3 | "Sure! Here are your cards:" + JSON + "Let me know…" | Braces extracted; parsed. |
| J4 | Missing `deck` | Fallback name `Imported cards`. |
| J5 | `schema` missing or `v2` | `wrong_schema`, nothing saved. |
| J6 | `cards: []` | `no_cards`. |
| J7 | 301 cards | `too_many_cards`. |
| J8 | Front 181 chars | `card_too_long` with card index. |
| J9 | Back containing `<br>` | `html_not_allowed`. |
| J10 | "a < b" in a back | Accepted (not a tag). |
| J11 | Duplicate fronts differing by case/space/punctuation | One kept; warning count = 1. |
| J12 | `{"schema":"…","error":"cannot read document"}` | `unreadable` message. |
| J13 | 100 KB of garbage | `parse_failed`, no crash. |
| J14 | Input 250 KB | `too_large` before parse. |
| J15 | Q/A blocks, blank-line separated | Parsed with `\n` joins. |
| J16 | Tagalog/Taglish and emoji | Preserved; limits count code points. |
| J17 | `\r\n` line endings | Normalized to `\n`. |
| J18 | Unknown extra top-level field | Ignored, import succeeds. |

### UI (widget tests)

| ID | Scenario | Expected |
|---|---|---|
| W1 | Open Import with AI | Prompt text visible; Copy button copies exactly `flashcards_v1.txt`. |
| W2 | Paste valid JSON → Preview | Deck name, subject picker, card list shown. |
| W3 | Delete a card in preview → Save | Saved deck has one fewer card. |
| W4 | Edit a card in preview → Save | Stored text matches the edit. |
| W5 | Invalid paste | Error shown; no deck row created. |
| W6 | Cancel from preview | No deck row created. |
| W7 | Save | Deck appears under the chosen subject; opens study mode. |

### Prompt quality check (manual, before writing app code)

Run the prompt against **3 documents × 3 runs**:

1. A text-based PDF chapter (10–20 pages).
2. A long handout (50+ pages).
3. A scanned/image PDF.

Record: JSON parses (yes/no), card count, duplicates, and factual errors found
in a 10-card sample. Pass bar: **9/9 parses** for documents 1–2, and document 3
must return the `error` object (not invented cards). If the bar is missed,
tighten the prompt before building the importer.

---

## 13. Effort and decision gate

| Slice | Estimate |
|---|---|
| Decks + cards migration, repositories, tests | 0.5–1 day |
| Deck list, card editor, study mode | 2–3 days |
| Import screen (prompt, copy, paste, file import) | 0.5 day |
| Parser + validation + preview/edit | 1–2 days |
| Local `.zip` backup inclusion | 0.5–1 day |
| **Total** | **5–7 days** |

Gate: build only **after** `v0.6-edit` is merged and Phase 6 polish is on
track, with a hard **2-day cap on the import slice** (the rest of the feature
must already exist). If the team is behind, this stays a future-work section
in the paper.

---

## 14. Open questions for the team

1. Deck scope: **subject** (recommended) or activity?
2. Local-only decks in v1 with a visible note, or full cloud backup?
3. Is the 20–40 card default right for your subjects, or should it be 15–25?
4. Does the prompt need a Tagalog version, or is "same language as the
   document" enough?
5. Do we want a "share deck" export (the same JSON) for teammates? Nearly
   free once the parser exists.
6. Is a simple offline MCQ mode worth it later (distractors drawn from other
   cards in the deck, no AI), or is flip-and-study enough?
