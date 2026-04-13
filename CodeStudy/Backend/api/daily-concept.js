import { selectDailyConcept } from '../src/concept-selector.js';

export async function GET(req) {
  const url = new URL(req.url);
  const level = url.searchParams.get('level');
  const language = url.searchParams.get('lang') || 'ko';
  const studiedParam = url.searchParams.get('studied') || '';
  const studiedIds = studiedParam
    ? studiedParam.split(',').map((s) => s.trim()).filter(Boolean)
    : [];

  if (!level) {
    return new Response(JSON.stringify({ error: 'level parameter is required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const result = selectDailyConcept(level, studiedIds);

  if (!result) {
    return new Response(JSON.stringify({ error: `Unknown level: ${level}` }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Build localized response: include tip for requested language (or both)
  const suffix = language === 'en' ? '_en' : '_ko';
  const response = {
    ...result,
    // Provide a single tip field for the requested language (backward compat)
    tip: result[`tip${suffix}`] || result.tip_ko || result.tip,
  };

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}
