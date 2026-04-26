/**
 * Socratic prompt engine.
 *
 * Assembles the system prompt from 3 layers:
 *   1. Socratic methodology rules (track-aware: Swift/iOS vs Backend/Spring)
 *   2. Concept data from curriculum (track-specific)
 *   3. Level-specific adaptation
 */

import { curriculum as swiftCurriculum } from '../data/curriculum.js';
import { curriculum as backendCurriculum } from '../data/curriculum_backend.js';
import { getLevelInstructions } from './level-adapters.js';

const VALID_TRACKS = ['swift', 'backend'];

/**
 * Track-specific curriculum lookup. Falls back to swift for backward
 * compatibility (older clients won't send track).
 */
function loadCurriculum(track = 'swift') {
  if (track === 'backend') return backendCurriculum;
  return swiftCurriculum;
}

/**
 * Find a concept by ID in the curriculum for given track.
 *
 * @param {string} conceptId
 * @param {string} [track='swift']
 * @returns {object|undefined}
 */
function findConcept(conceptId, track = 'swift') {
  const curriculum = loadCurriculum(track);
  return curriculum.find((c) => c.id === conceptId);
}

// ---------------------------------------------------------------------------
// Layer 1: Socratic methodology rules (track-aware)
// ---------------------------------------------------------------------------
function buildMethodologyLayer(language, track = 'swift') {
  // Track별 어법/예시 차이만 다르고 소크라테스식 원칙은 동일.
  const tutorIdentity = track === 'backend'
    ? 'You are a Socratic Kotlin/Spring backend tutor.'
    : 'You are a Socratic Swift/iOS tutor.';

  const codeKeywordRule = track === 'backend'
    ? 'Code and Kotlin/Spring keywords always in English. Explanations in ${language}.'
    : 'Code and Swift keywords always in English. Explanations in ${language}.';

  return `${tutorIdentity} You NEVER give direct answers.

RULES:
1. Ask questions to guide the student to discover answers themselves.
2. One concept at a time. Maximum 3 lines per response.
3. Correct answer: briefly confirm why correct, then go deeper immediately.
4. Wrong answer (1st attempt): give a hint, let them retry.
5. Wrong answer (2nd attempt): explain the answer, then move on.
6. "I don't know" or confusion: pivot to a simpler example or analogy.
7. 3-5 turns to converge on mastery of one concept.
8. ${track === 'backend' ? 'Code and Kotlin/Spring keywords' : 'Code and Swift keywords'} always in English. Explanations in ${language}.
9. No emojis in teaching content.

SESSION COMPLETION (STRICT — follow exactly):
Step 1: After 3-5 productive turns, ask ONE confirmation question. Do NOT include [MASTERY] in this response.
Step 2: Wait for the student to answer.
Step 3: ONLY if the student answers correctly, include [MASTERY] at the END of your NEXT response.

CRITICAL RULES:
- NEVER include [MASTERY] and a question mark (?) in the same response.
- NEVER include [MASTERY] in a response that asks a new question.
- [MASTERY] goes ONLY in a response that confirms the student's correct answer, with NO further questions.
- The [MASTERY] marker signals the client — do NOT explain or mention it to the student.`;
}

// ---------------------------------------------------------------------------
// Layer 2: Concept data
// ---------------------------------------------------------------------------
function buildConceptLayer(concept, language = 'ko') {
  const suffix = language === 'en' ? '_en' : '_ko';
  // Support both old (teaching_hints) and new (teaching_hints_ko/_en) field names
  const hints = concept[`teaching_hints${suffix}`] || concept.teaching_hints || {};
  const analogies = concept[`analogies${suffix}`] || concept.analogies || [];
  const analogy = analogies.length > 0 ? analogies[0] : 'N/A';
  const fallback = concept.simpler_fallback || 'N/A';

  return `CONCEPT: ${concept.title_ko} (${concept.title_en})
- What it is: ${hints.what || 'N/A'}
- Why it exists: ${hints.why || 'N/A'}
- How to use it: ${hints.how || 'N/A'}
- Watch out: ${hints.watchOut || 'N/A'}
- Analogy: ${analogy}
- If student is stuck, fall back to: ${fallback}`;
}

// ---------------------------------------------------------------------------
// Layer 3: Level adaptation
// ---------------------------------------------------------------------------
function buildLevelLayer(level) {
  return `STUDENT LEVEL INSTRUCTIONS:\n${getLevelInstructions(level)}`;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Build the full system prompt for a Socratic tutoring session.
 *
 * @param {string} conceptId - Concept ID from curriculum
 * @param {'beginner'|'basic'|'intermediate'|'advanced'} userLevel
 * @param {'ko'|'en'} language - Response language
 * @param {'swift'|'backend'} [track='swift'] - Learning track
 * @returns {string} Assembled system prompt
 */
export function buildSystemPrompt(conceptId, userLevel, language = 'ko', track = 'swift') {
  const safeTrack = VALID_TRACKS.includes(track) ? track : 'swift';
  const concept = findConcept(conceptId, safeTrack);
  if (!concept) {
    throw new Error(`Concept not found: ${conceptId} (track: ${safeTrack})`);
  }

  const lang = language === 'en' ? 'English' : 'Korean';

  const layers = [
    buildMethodologyLayer(lang, safeTrack),
    buildConceptLayer(concept, language),
    buildLevelLayer(userLevel),
  ];

  return layers.join('\n\n');
}

/**
 * Extract the [MASTERY] marker from LLM response text.
 *
 * @param {string} text - Raw LLM output
 * @returns {{ text: string, mastered: boolean }}
 */
export function extractMastery(text) {
  const marker = '[MASTERY]';
  const mastered = text.includes(marker);
  const cleaned = text.replace(/\s*\[MASTERY\]\s*/g, ' ').replace(/\s+/g, ' ').trim();
  return { text: cleaned, mastered };
}

/**
 * Reset the cached curriculum (useful for testing).
 */
export function _resetCurriculumCache() {
  _curriculum = null;
}
