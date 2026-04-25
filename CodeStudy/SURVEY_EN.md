# CodeStudy In-App Survey — English (Cycle 2 / Stage 1)

English-language version of the post-mastery survey. Mirrors `SURVEY.md` (Korean).

- **Purpose**: Demand discovery for English-speaking users (Show HN / Reddit / Product Hunt cohorts)
- **Trigger**: Right after a user dismisses SessionCompleteView (mastery), once per user (`surveyShown` UserDefaults flag)
- **Target responses**: 5-10 (Stage 1 success criteria)
- **Incentive**: Lottery — 5 winners × $5 Starbucks gift card (total ~$25, fixed regardless of response volume)

---

## Google Forms setup

### Form Title
```
CodeStudy Quick Feedback
```

### Form Description
```
Congrats on mastering this concept! 🎉

I'm trying to build a better learning app and would love your thoughts.
Just 1-2 minutes of your time would mean a lot.

✨ 5 random respondents will get a $5 Starbucks gift card ☕️
   (Email required to enter, sent within a week after Stage 1 closes)

— Tabber
```

---

## Questions (8 total: 5 required + 3 optional)

### Q1. Which best describes you? *

**Type:** Multiple choice (single) — **Required**

- iOS / Swift developer (current)
- Developer in another language or platform (current)
- Bootcamp or coding school student
- CS / engineering student
- Self-taught learner (non-CS background)
- Other

---

### Q2. How did you first hear about CodeStudy? *

**Type:** Multiple choice (single) — **Required**

- Hacker News (Show HN)
- Reddit (r/iOSProgramming, r/swift, etc.)
- Product Hunt
- Twitter / X
- Friend or coworker
- App Store search
- Other

---

### Q3. How was your learning experience so far? *

**Type:** Linear scale 1-5 — **Required**

- 1: Not great
- 5: Loved it

---

### Q4. Will you still be using CodeStudy a month from now? *

**Type:** Multiple choice (single) — **Required**

- Yes, daily or near-daily
- A few times a week
- Maybe once in a while
- Not sure
- Probably not

---

### Q5. What part helped you the most? *

**Type:** Short answer — **Required**

Placeholder: `One sentence is enough`

---

### Q6. What was disappointing or could be better? (optional)

**Type:** Paragraph (long answer) — Optional

Placeholder: `Be honest — I read every response`

---

### Q7. Any feature you wish CodeStudy had? (optional)

**Type:** Paragraph (long answer) — Optional

---

### Q8. Email address (optional)

**Type:** Short answer (Email validation ON) — Optional

Description text:
```
Required to enter the Starbucks gift card draw. I may also reach out
for a 15-minute chat if your feedback sparks more questions — totally
opt-in. Email is only used for these two purposes.
```

---

## Why this order?

- Light objective questions first → open-ended at the end (typical funnel)
- Q1-Q2 = *funnel attribution* (channel ROI: which post/community drives users?)
- Q3-Q4 = *retention signal* (the gap between satisfaction and continuation is the real insight)
- Q5 = *value prop discovery* (user's own words validate the product promise)
- Q6-Q7 = *roadmap input* (optional, drop-off OK)
- Q8 = *interview pipeline* (one 15-minute conversation > 100 surveys)

## Why a lottery?

- Pay-everyone: with 30 responses → $150, with 100 responses → $500. Cost unbounded.
- Lottery (5 winners): fixed ~$25 regardless of response count. Predictable budget.
- Quality bonus: less incentive to rush since reward isn't guaranteed.

---

## Google Forms tips

### 1. Response collection
- **Responses** tab → **Link to Sheets** → auto-creates a spreadsheet
- All responses accumulate there (time-series analysis later)

### 2. Show progress bar
- **Settings** → **Presentation** → **Show progress bar** ON
- Reinforces the "1-2 minutes" promise

### 3. Don't require login
- **Settings** → **Responses** → **Limit to 1 response** OFF
- Anonymity > strict deduplication. Our app already enforces 1-per-user via UserDefaults.

### 4. Get the URL into the app
- Top-right **Send** → link icon → copy URL
- Format: `https://docs.google.com/forms/d/e/1FAIpQLSe.../viewform` (or `forms.gle/...`)
- Paste into the Vercel env var `SURVEY_URL_EN` (see Backend section below)

### 5. (Optional) Anonymous ID prefill
- Build → **Get pre-filled link** to find entry IDs
- iOS can append `?entry.123456789={anonymousID}` for cohort analysis
- Still anonymous (UUID, no PII), enables cross-referencing with logged behavior

---

## Backend wiring (already implemented — see commit log)

Tabber adds the env var:

```bash
cd /Users/tabber/AI-Product-Factory/CodeStudy/Backend
vercel env add SURVEY_URL_EN production
# → paste English Google Forms URL when prompted

vercel --prod
# → 30-second redeploy
```

The `/api/config` endpoint will then return both URLs:

```json
{
  "schemaVersion": 2,
  "surveyEnabled": true,
  "surveyURL":   "https://forms.gle/...ko",
  "surveyURLEn": "https://forms.gle/...en"
}
```

iOS picks the right URL via `config.surveyURL(for: profile.language)`.

---

## Operational workflow

### Response collection (Cycle 2 Stage 1)
1. Create the English Google Form using this doc
2. Set `SURVEY_URL_EN` in Vercel + redeploy
3. Ship 1.1.0 → English-locale users see English form on next mastery
4. Korean users still see Korean form (existing flow preserved)

### Lottery draw (Stage 1 close)
1. Filter valid responses (Q5 or Q6/Q7 with substantive answer — not "lol", "n/a", etc.)
2. From valid + email-provided pool, pick 5 winners randomly (Sheets `RANDBETWEEN` or random.org)
3. Send Starbucks gift cards (US: starbucks.com/giftcards, or third-party like Rybbon / Tango Card for international delivery)
4. Notify winners via email (optional but a nice touch)

### Invalid response criteria (no gift card)
- Single-word filler in Q5: "lol", "...", "none"
- Obvious bots / joke responses
- Same email submitted multiple times (UserDefaults can be bypassed on jailbroken devices)

### Closing the loop
- Once "who is using this and why" is clear (target: 5-10 quality responses across both languages)
- Tabber sets the Form to "Not accepting responses" in Google Forms settings
- iOS app: no action needed — the `surveyShown` flag prevents re-prompts

---

## Tone notes for translators / future revisions

- **Voice**: warm, direct, builder-to-builder. Avoid corporate survey speak.
- **Sign-off**: First-person `— Tabber` matters. Removes the "form letter" feel.
- **Lottery framing**: don't bury the incentive — call it out clearly with the ☕️ emoji.
- **Q5 placeholder**: "One sentence is enough" lowers the bar to respond. Critical for completion rate.
- **Q6 placeholder**: "I read every response" signals the developer cares. This sentence alone can double quality of feedback.

## Updated 2026-04-25
- Initial English version created alongside Cycle 2 English-market rollout
- Cost target: $25 fixed (5 × $5)
- Delivery method TBD (Starbucks app US-only — international users may need third-party gift card service)
