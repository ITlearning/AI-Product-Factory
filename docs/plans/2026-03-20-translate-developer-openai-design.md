# Translate-Developer OpenAI Integration Design

## Summary

Translate-Developer will move from a primarily rule-based translator to an AI-first translator powered by OpenAI, while preserving the current rule engine as an automatic fallback path. The deployment target is Vercel, using a serverless function so the browser never calls OpenAI directly and the API key stays in server-side environment variables.

## Approved Decisions

- Deployment: Vercel
- API topology: browser -> Vercel serverless function -> OpenAI API
- Default model: `gpt-4.1-mini`
- Output mode: structured JSON mapped to the existing UI sections
- User experience: AI first, automatic fallback to rule engine on failure
- Streaming: not in MVP; return the full result at once

## Why This Change

The current rule engine is useful for demos and fallback safety, but it will not scale well to diverse real-world developer phrasing. AI-based translation is the practical path for better accuracy, especially when inputs vary in tone, structure, and specificity. The role of the rule engine changes from primary translator to resilience layer.

## Product Behavior

### Happy Path

1. User enters a short developer message.
2. Browser sends the message to `/api/translate`.
3. Vercel serverless function calls OpenAI with a structured-output prompt.
4. The function validates the JSON response shape.
5. The UI renders the translated result and indicates that AI was used.

### Failure Path

If the OpenAI call fails because of timeout, quota, bad output shape, network error, or server-side exception:

1. The browser receives an error response from the API route.
2. The frontend automatically runs the current rule engine locally.
3. The UI still renders a result.
4. A small status badge or message indicates that fallback mode was used.

This keeps the user experience simple while preserving service continuity.

## Architecture

### Frontend

The existing single-page UI stays in place. The frontend state model expands to support:

- loading state
- engine source (`ai` or `fallback`)
- API error details for debug-safe internal handling

The UI should not expose raw API failures directly unless the fallback also fails.

### Serverless Function

Add a Vercel function at a route such as `/api/translate`.

Responsibilities:

- validate request payload
- build the OpenAI prompt
- call the OpenAI Responses API
- request a structured JSON result
- validate and sanitize the returned object
- send normalized JSON back to the browser

The function must not leak the API key or full upstream failure internals to the client.

### OpenAI API Usage

Use OpenAI `Responses API` with `gpt-4.1-mini` and structured output constrained to the app’s output schema.

Target response fields:

- `summary`
- `easyExplanation`
- `importantNow`
- `actionForReader`
- `termPairs[]`

`termPairs[]` remains an array of:

- `original`
- `simplified`

The API contract must stay compatible with the current UI so the rendering layer does not care whether the result came from AI or fallback rules.

## Prompt Design

The prompt should explicitly instruct the model to:

- rewrite for a non-technical general audience
- preserve essential meaning
- explain technical terms simply rather than deleting them blindly
- separate immediate importance from next action
- return only the schema-compliant JSON object
- avoid inventing facts not present in the input

It should also bias toward:

- concise Korean
- short, readable sentences
- practical explanation over abstract paraphrase

## Response Validation

The serverless function should validate:

- all required keys exist
- all top-level fields are strings except `termPairs`
- `termPairs` is an array of objects
- each term pair includes `original` and `simplified`

If validation fails, treat it as an AI failure and allow fallback behavior.

## Security And Deployment

- Store `OPENAI_API_KEY` only in Vercel environment variables
- Never expose the key to frontend code
- Keep OpenAI calls on the serverless layer only
- Avoid logging raw user inputs unless explicitly needed for debug mode

Recommended environment variables:

- `OPENAI_API_KEY`
- optional `OPENAI_MODEL` defaulting to `gpt-4.1-mini`

## UX Changes

Add a small source indicator in the result area:

- `AI 번역`
- `기본 번역 모드`

The label should be informative but not distracting. The main user experience should still feel like one product, not two separate systems.

## Error Handling

- Empty input: handled on the client before request
- API timeout or 5xx: fallback locally
- Invalid AI JSON: fallback locally
- Both AI and fallback fail: show a user-friendly retry message

## Testing Strategy

- Unit tests for server-side response normalization and validation
- Frontend tests for:
  - loading state
  - AI success path
  - fallback path after API failure
- regression tests for schema parsing and UI source badge rendering

## Success Criteria

- AI responses fit the current UI without manual cleanup
- Fallback works automatically when AI fails
- The browser never contains the OpenAI API key
- The deployed app works cleanly on Vercel with environment-based configuration
