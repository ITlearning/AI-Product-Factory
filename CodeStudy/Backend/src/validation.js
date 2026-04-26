const VALID_LEVELS = ['beginner', 'basic', 'intermediate', 'advanced'];
const VALID_LANGUAGES = ['ko', 'en'];
const VALID_TRACKS = ['swift', 'backend'];

/**
 * Validate a tutor request body.
 * @param {unknown} body
 * @returns {{ valid: true } | { valid: false, error: string }}
 */
export function validateTutorRequest(body) {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be a JSON object' };
  }

  if (!Array.isArray(body.messages)) {
    return { valid: false, error: 'messages must be an array' };
  }

  if (typeof body.conceptId !== 'string' || body.conceptId.trim() === '') {
    return { valid: false, error: 'conceptId must be a non-empty string' };
  }

  if (typeof body.sessionId !== 'string' || body.sessionId.trim() === '') {
    return { valid: false, error: 'sessionId must be a non-empty string' };
  }

  if (!body.userProfile || typeof body.userProfile !== 'object') {
    return { valid: false, error: 'userProfile must be an object' };
  }

  if (!VALID_LEVELS.includes(body.userProfile.level)) {
    return {
      valid: false,
      error: `userProfile.level must be one of: ${VALID_LEVELS.join(', ')}`,
    };
  }

  if (!VALID_LANGUAGES.includes(body.userProfile.language)) {
    return {
      valid: false,
      error: `userProfile.language must be one of: ${VALID_LANGUAGES.join(', ')}`,
    };
  }

  // track is optional — older clients may not send it. Default to 'swift'.
  // If sent, must be in valid set.
  if (body.track !== undefined && !VALID_TRACKS.includes(body.track)) {
    return {
      valid: false,
      error: `track must be one of: ${VALID_TRACKS.join(', ')}`,
    };
  }

  return { valid: true };
}
