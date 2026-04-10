import { curriculum as curriculumData } from './data/curriculum.js';

function loadCurriculum() {
  return curriculumData;
}

/**
 * Levels accessible for each user level.
 * Higher levels can access lower-level concepts too.
 */
const LEVEL_ACCESS = {
  beginner: ['beginner'],
  basic: ['beginner', 'basic'],
  intermediate: ['beginner', 'basic', 'intermediate'],
  advanced: ['beginner', 'basic', 'intermediate', 'advanced'],
};

/**
 * Select the next concept for a user based on their level and mastered concepts.
 *
 * @param {string} level - beginner | basic | intermediate | advanced
 * @param {string[]} masteredIds - array of concept IDs already mastered
 * @returns {object | null} The next concept to study, or null if curriculum is empty
 */
export function selectDailyConcept(level, masteredIds = []) {
  const curriculum = loadCurriculum();
  const accessibleLevels = LEVEL_ACCESS[level] || ['beginner'];
  const masteredSet = new Set(masteredIds);

  // Filter to accessible concepts and sort by order
  const accessible = curriculum
    .filter((c) => accessibleLevels.includes(c.level))
    .sort((a, b) => a.order - b.order);

  if (accessible.length === 0) return null;

  // Find the first unmastered concept
  const next = accessible.find((c) => !masteredSet.has(c.id));

  if (next) return next;

  // All mastered — return the first concept for review (fallback)
  return accessible[0];
}
