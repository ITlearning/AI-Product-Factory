# Translate-Developer MVP Design

## Summary

Translate-Developer is a single-page web app that rewrites short developer-written messages into language a non-technical reader can follow. The MVP starts with a rule-based transformation engine and keeps a stable engine interface so an LLM-backed engine can be added later without reshaping the product UI or output schema.

## Approved Product Decisions

- Product shape: login-free single-page web app
- Primary input: short developer explanations or Slack-style messages
- Primary audience: non-technical general users
- Translation style: preserve key technical terms when needed, but attach easier explanations
- Output blocks:
  - one-line summary
  - easy explanation
  - what matters now
  - action the reader should understand
  - original vs simplified wording comparison
- Delivery strategy: rule-based MVP first, LLM-ready architecture later

## Problem

Developer communication is often accurate but inaccessible to non-technical readers. The immediate pain is not full document translation; it is understanding short status updates such as bug explanations, release blockers, and implementation notes. The MVP should solve that narrow problem well enough that the before/after transformation feels obvious in a demo and useful in real team communication.

## Goals

- Let a user paste a short developer message and get a structured plain-language explanation in one step.
- Make the output easy to scan, not just easier to read.
- Support deterministic demo quality with no AI cost or model dependency.
- Keep the transformation engine replaceable so LLM quality can be tested later.

## Non-Goals For MVP

- No login, account system, or saved history
- No share links or server persistence
- No document upload, meeting transcript support, or long-form PR parsing
- No multilingual translation
- No admin dashboard or analytics backend

## Product Experience

### User Flow

1. The user lands on the page and immediately sees what the product does.
2. The user can paste a short technical message or tap a prefilled example.
3. The user runs the translation.
4. The page renders structured result cards and a before/after wording view.
5. The user can edit the input and rerun instantly.

### Input Constraints

- Optimized for 1 to 5 sentences
- Best for release notes, bug explanations, implementation status, and short incident updates
- If the message is too long, the UI should nudge the user to shorten it rather than pretending the result is reliable

### Output Contract

Every engine response should conform to one stable shape:

- `summary`
- `easyExplanation`
- `importantNow`
- `actionForReader`
- `termPairs[]`

`termPairs` stores original terms or phrases and their simplified equivalents so the UI can render a clear comparison section. A future LLM engine must return the same shape.

## UX Direction

The product should feel purposeful and direct, not like a generic form page. The page should emphasize trust and comprehension:

- Hero copy explains the promise in plain Korean
- One strong input area dominates the fold
- Results are chunked into clear blocks with distinct hierarchy
- The comparison section visibly proves the transformation
- Mobile and desktop layouts both keep the input and result relationship obvious

During implementation, UI decisions should be reviewed with the `ui-ux-pro-max` skill before and during visual refinement. That review is part of the delivery expectation for this project.

## Technical Design

### Frontend

Recommended MVP stack:

- TypeScript-based SPA
- Small componentized UI
- Client-side transformation only
- Static deploy target

This keeps the first release cheap and portable. The engine stays local for deterministic behavior and instant response.

### Engine Boundary

Define a single translation engine interface:

```ts
type TranslationResult = {
  summary: string;
  easyExplanation: string;
  importantNow: string;
  actionForReader: string;
  termPairs: Array<{ original: string; simplified: string }>;
};

type TranslationEngine = {
  translate(input: string): TranslationResult;
};
```

Initial implementation uses a `RuleEngine`. Future work can add `LlmEngine` behind the same interface.

### Rule Engine Responsibilities

- Normalize whitespace and split input into manageable clauses
- Detect technical keywords and map them to simpler terms or explanations
- Identify urgency or blocker signals such as errors, delays, failures, deploy issues, and missing work
- Rewrite sentence framing into non-technical phrasing
- Populate the structured output fields deterministically

### Rule Sources

The first version should use a small, editable ruleset:

- terminology dictionary
- phrase replacement rules
- severity and urgency cues
- action extraction heuristics
- example fixtures for regression tests

This ruleset must be easy to extend without touching UI code.

## Error Handling

- Empty input: disable submit or show lightweight validation
- Overlong input: explain that MVP works best on shorter messages
- Weak confidence case: still return a readable fallback, but indicate that the message was too broad or vague
- Missing rule match: produce generic simplification rather than failing hard

## Testing Strategy

- Unit tests for rule normalization, keyword mapping, urgency extraction, and output shaping
- UI tests for main interaction flow and validation states
- Regression fixtures with representative developer messages

The key requirement is protecting behavior before future cleanup or LLM substitution work.

## Deployment Assumption

The MVP should be deployable as a static frontend. No backend is required for the first release. This keeps hosting simple and lets the product be validated before persistence or LLM cost is introduced.

## Future Extensions

- LLM-backed engine selection
- role presets such as PM, customer support, or operations
- error-message specific mode
- meeting-summary mode
- shareable result links backed by persistence

## Success Criteria

- A non-technical user can understand the output of representative short developer messages without needing a developer to re-explain them.
- The output sections feel meaningfully different, not like the same sentence repeated five ways.
- The app is deployable with no server dependency.
- The engine can be swapped later without redesigning the UI contract.
