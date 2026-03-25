# Translate-Developer Role-Aware PM Design

## Summary

Translate-Developer will shift from a generic developer-message translator toward a role-aware explainer optimized first for PMs and planners. The product will still translate short developer-written updates, but the primary experience will focus on rewriting the whole message into easy Korean, explaining difficult technical terms, surfacing only evidence-backed impact, and clearly stating what the current message still does not reveal.

## Approved Decisions

- Product shape: keep `Translate-Developer` as the same single-page app
- First target audience: `PM/기획자`
- Visible audience buttons: `PM/기획자`, `디자이너`, `비개발자`
- Default audience selection: `PM/기획자`
- Situation selection: hidden from the user and inferred internally by AI
- Input guidance: encourage users to paste surrounding Slack context, not only a single line
- Example style: show short thread-like message bundles instead of isolated single-sentence examples
- Result structure stays the same across audiences
- Result block order:
  - `쉽게 다시 쓴 내용`
  - `전문 용어 풀이`
  - `이 대화에서 보이는 영향`
  - `더 알려주면 정확해지는 부분`
- Tone: friendly colleague, not stiff analyst
- Accuracy rule: no guessing; only describe what the input supports
- Unknowns handling: explicitly and politely say what needs more context
- Initial model quality baseline: `gpt-5.4`
- Later comparison target: `gpt-5-mini`

## Problem

PMs and planners working with developers often fail at the same first step: they do not fully understand the technical language in short status messages. Once the terminology is unclear, they also struggle to understand the real product or schedule impact. The current app already simplifies messages, but it still behaves like a general translator rather than a role-aware explainer built around that PM-specific understanding problem.

## Goals

- Let a PM or planner paste developer-written text and immediately understand the message in plain Korean.
- Explain technical terms without hiding them.
- Surface only the impact that is supported by the pasted text.
- Teach the user when more context is needed instead of letting the model guess.
- Keep the UI simple by asking only who the explanation is for, not which technical situation it belongs to.

## Non-Goals

- No user-facing situation selector such as deploy, incident, or delay mode
- No speculative schedule or user-impact prediction
- No live meeting transcription or recording flow in this iteration
- No audience-specific result layouts with different block structure
- No persistence, login, or collaboration features in this iteration

## Product Behavior

### Entry Flow

1. The user lands on the page and sees a strong question: who should understand this explanation?
2. The audience buttons are visible, with `PM/기획자` selected by default.
3. The input area clearly asks for the original message plus surrounding context, not just a short isolated sentence.
4. Example content demonstrates a Slack-thread style input with enough background to avoid guessing.

### Translation Flow

1. The user selects an audience or leaves the default.
2. The user pastes a message or thread.
3. The AI receives the audience plus raw text.
4. The AI internally infers the likely situation and technical topic, but does not force the user to classify it.
5. The AI returns one strict structured result object.
6. The UI renders the four stable output blocks.

### Result Flow

- `쉽게 다시 쓴 내용` is the primary reading surface and should be visually dominant.
- `전문 용어 풀이` proves the translation and reduces anxiety around unknown terms.
- `이 대화에서 보이는 영향` stays conservative and only reflects evidence from the input.
- `더 알려주면 정확해지는 부분` explains unknowns in a soft, helpful tone.

## Output Contract

The output contract should be redesigned around the approved result structure instead of the current summary/action framing.

Recommended fields:

- `rewrittenMessage: string`
- `termExplanations: Array<{ term: string, explanation: string }>`
- `confirmedImpact: string`
- `needsMoreContext: string`

This contract maps directly to the four visible UI blocks. It also aligns the fallback engine and AI engine behind the same interface again.

## UX Direction

The experience should feel calm and helpful, not like a technical diagnostics panel.

- Audience buttons are large, obvious, and easy to scan.
- The input helper text should make context-pasting feel normal and expected.
- The rewritten message should read like a supportive coworker translating what the developer meant.
- The unknowns block should avoid cold phrases such as "확인할 수 없습니다" when a warmer alternative can stay equally accurate.
- The page should teach better input quality through both the guidance text and the result itself.

## Prompt Design

The prompt should be layered rather than written as one generic paragraph.

### Shared Rules

- explain only what is present in the input
- do not invent root causes, timing, scope, or impact
- keep the tone friendly and readable
- make each output field meaningfully different
- return only schema-compliant JSON

### Audience Presets

- `PM/기획자`: prioritize term explanation and practical impact comprehension
- `디자이너`: prioritize feature, UI, or workflow impact comprehension
- `비개발자`: prioritize general plain-language understanding

### Unknowns Policy

When the text is incomplete, the model should say so directly but gently. It should not fill the missing space with likely-but-unstated assumptions.

## Architecture

### Frontend

- Add audience selection into app state.
- Preserve one shared result layout across all audiences.
- Update helper copy and examples to emphasize context-rich input.
- Reorder or relabel blocks to match the new product framing.

### API Layer

- Send both `input` and `audience` to `/api/translate`.
- Keep using structured outputs with a strict schema.
- Move audience-specific rules and no-guess logic into a dedicated prompt-building layer.

### Fallback Layer

- Update the local rule engine to emit the new contract.
- Keep the fallback conservative, especially in the impact and unknowns fields.
- It is acceptable for the fallback to be simpler than the AI path as long as the contract stays stable.

## Error Handling

- Empty or weak input: keep current validation and nudge toward more context
- AI failure: continue using fallback mode
- Missing context: render a helpful unknowns block rather than hallucinating detail
- Both AI and fallback fail: show a retry message, not a fabricated interpretation

## Testing Strategy

- Schema tests for the redesigned output contract
- API tests for audience-aware prompt routing and no-guess normalization
- UI tests for audience button rendering, default selection, new block labels, and updated helper copy
- Rule-engine tests for the new fallback contract and conservative unknowns behavior

## Success Criteria

- A PM can paste a developer message and understand the core meaning without a developer re-explaining it.
- The rewritten message reads naturally and does not sound robotic or overly formal.
- Technical terms are explained instead of silently removed.
- Impact text stays accurate and conservative.
- Missing context is surfaced clearly enough that users learn to paste better raw input next time.
