/**
 * Socratic prompt engine.
 *
 * Assembles the system prompt from 3 layers:
 *   1. Socratic methodology rules
 *   2. Concept data from curriculum.json
 *   3. Level-specific adaptation
 */

import { curriculum as curriculumData } from '../data/curriculum.js';
import { getLevelInstructions } from './level-adapters.js';

function loadCurriculum() {
  return curriculumData;
}

/**
 * Find a concept by ID in the curriculum.
 *
 * @param {string} conceptId
 * @returns {object|undefined}
 */
function findConcept(conceptId) {
  const curriculum = loadCurriculum();
  return curriculum.find((c) => c.id === conceptId);
}

// ---------------------------------------------------------------------------
// Layer 1: Socratic methodology rules
// ---------------------------------------------------------------------------
function buildMethodologyLayer(language) {
  return `You are a Socratic Swift/iOS tutor. You NEVER give direct answers.

RULES:
1. Ask questions to guide the student to discover answers themselves.
2. One concept at a time. Maximum 3 lines per response.
3. Correct answer: briefly confirm why correct, then go deeper immediately.
4. Wrong answer (1st attempt): give a hint, let them retry.
5. Wrong answer (2nd attempt): explain the answer, then move on.
6. "I don't know" or confusion: pivot to a simpler example or analogy.
7. 3-5 turns to converge on mastery of one concept.
8. Code and Swift keywords always in English. Explanations in ${language}.
9. No emojis in teaching content.

SESSION COMPLETION:
After 3-5 productive turns, ask ONE confirmation question.
If the student answers correctly, include the exact marker [MASTERY] at the END of your response.
This marker signals the client — do NOT explain or mention it to the student.`;
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
 * @param {string} conceptId - Concept ID from curriculum.json
 * @param {'beginner'|'basic'|'intermediate'|'advanced'} userLevel
 * @param {'ko'|'en'} language - Response language
 * @returns {string} Assembled system prompt
 */
export function buildSystemPrompt(conceptId, userLevel, language = 'ko') {
  const concept = findConcept(conceptId);
  if (!concept) {
    throw new Error(`Concept not found: ${conceptId}`);
  }

  const lang = language === 'en' ? 'English' : 'Korean';

  const layers = [
    buildMethodologyLayer(lang),
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
