/**
 * Level-specific prompt adapters for the Socratic tutor.
 */

/**
 * Return teaching style instructions based on the student's level.
 *
 * @param {'beginner'|'basic'|'intermediate'|'advanced'} level
 * @returns {string}
 */
export function getLevelInstructions(level) {
  switch (level) {
    case 'beginner':
      return 'Use everyday analogies. Avoid technical jargon. Assume no prior Swift knowledge. Explain what variables and types are if needed.';
    case 'basic':
      return 'Student knows variables, types, and basic control flow. Use simple technical terms. Can reference basic programming concepts.';
    case 'intermediate':
      return 'Student knows Swift basics including optionals, closures, structs/classes. Use standard Swift terminology. Can discuss design patterns briefly.';
    case 'advanced':
      return 'Student is experienced. Use precise CS terminology. Discuss performance, memory, concurrency tradeoffs. Challenge their understanding.';
    default:
      return 'Use everyday analogies. Avoid technical jargon. Assume no prior Swift knowledge.';
  }
}

/**
 * Generate the AI's opening message prompt for a new session.
 *
 * @param {object} concept - Concept object from curriculum.json
 * @param {'beginner'|'basic'|'intermediate'|'advanced'} level
 * @param {'ko'|'en'} language
 * @returns {string}
 */
export function getFirstMessagePrompt(concept, level, language) {
  const title = language === 'ko' ? concept.title_ko : concept.title_en;

  if (language === 'ko') {
    return (
      `지금부터 "${title}" 개념을 함께 공부합니다.\n` +
      `학생의 수준: ${level}.\n` +
      `따뜻하게 인사하고, 이 개념이 왜 중요한지 한 문장으로 설명한 뒤, ` +
      `학생이 이미 알고 있는지 확인하는 첫 질문을 하세요.`
    );
  }

  return (
    `We are now studying the concept "${title}".\n` +
    `Student level: ${level}.\n` +
    `Greet them warmly, explain in one sentence why this concept matters, ` +
    `then ask an opening question to gauge what they already know.`
  );
}
