import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// We need a temporary curriculum.json for testing.
// The module loads from src/data/curriculum.json relative to socratic-rules.js.
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const dataDir = path.join(__dirname, '..', '..', 'src', 'data');
const curriculumFile = path.join(dataDir, 'curriculum.json');

const MOCK_CURRICULUM = [
  {
    id: 'swift-optionals',
    title_ko: '옵셔널',
    title_en: 'Optionals',
    level: 'beginner',
    order: 1,
    teaching_hints: {
      what: 'A type that can hold a value or nil',
      why: 'Swift uses optionals to handle the absence of a value safely',
      how: 'Declare with ? and unwrap with if-let, guard-let, or !',
      watchOut: 'Force unwrapping (!) crashes if the value is nil',
    },
    analogies: ['A gift box that might be empty'],
    simpler_fallback: 'Think of a variable as a box. Optional means the box might have nothing inside.',
  },
  {
    id: 'swift-closures',
    title_ko: '클로저',
    title_en: 'Closures',
    level: 'intermediate',
    order: 5,
    teaching_hints: {
      what: 'Self-contained blocks of functionality',
      why: 'Closures enable functional programming patterns in Swift',
      how: 'Use { (params) -> ReturnType in body } syntax',
      watchOut: 'Retain cycles when capturing self',
    },
    analogies: ['A recipe card you can pass around'],
    simpler_fallback: 'Think of a closure as a mini-function you can store in a variable.',
  },
];

let createdDataDir = false;

function ensureCurriculum() {
  try {
    mkdirSync(dataDir, { recursive: true });
    createdDataDir = true;
  } catch {
    // already exists
  }
  writeFileSync(curriculumFile, JSON.stringify(MOCK_CURRICULUM, null, 2));
}

// We dynamically import the module after writing the curriculum file,
// so we must manage the cache carefully.
let buildSystemPrompt;
let extractMastery;
let _resetCurriculumCache;

describe('socratic-rules', async () => {
  beforeEach(() => {
    ensureCurriculum();
    if (_resetCurriculumCache) _resetCurriculumCache();
  });

  afterEach(() => {
    if (_resetCurriculumCache) _resetCurriculumCache();
  });

  // Dynamic import once (the curriculum file must already exist)
  ensureCurriculum();
  const mod = await import('../../src/prompts/socratic-rules.js');
  buildSystemPrompt = mod.buildSystemPrompt;
  extractMastery = mod.extractMastery;
  _resetCurriculumCache = mod._resetCurriculumCache;

  it('includes all 3 layers in the system prompt', () => {
    const prompt = buildSystemPrompt('swift-optionals', 'beginner', 'ko');

    // Layer 1: Socratic rules
    assert.ok(prompt.includes('You are a Socratic Swift/iOS tutor'));
    assert.ok(prompt.includes('[MASTERY]'));
    assert.ok(prompt.includes('RULES:'));

    // Layer 2: Concept data
    assert.ok(prompt.includes('옵셔널 (Optionals)'));
    assert.ok(prompt.includes('A gift box that might be empty'));
    assert.ok(prompt.includes('Force unwrapping'));

    // Layer 3: Level instructions
    assert.ok(prompt.includes('STUDENT LEVEL INSTRUCTIONS'));
    assert.ok(prompt.includes('everyday analogies'));
  });

  it('uses different instructions for different levels', () => {
    const beginnerPrompt = buildSystemPrompt('swift-optionals', 'beginner', 'ko');
    const advancedPrompt = buildSystemPrompt('swift-optionals', 'advanced', 'ko');

    assert.ok(beginnerPrompt.includes('everyday analogies'));
    assert.ok(!beginnerPrompt.includes('precise CS terminology'));

    assert.ok(advancedPrompt.includes('precise CS terminology'));
    assert.ok(!advancedPrompt.includes('everyday analogies'));
  });

  it('uses Korean language label when language is ko', () => {
    const prompt = buildSystemPrompt('swift-optionals', 'beginner', 'ko');
    assert.ok(prompt.includes('Explanations in Korean'));
  });

  it('uses English language label when language is en', () => {
    const prompt = buildSystemPrompt('swift-optionals', 'beginner', 'en');
    assert.ok(prompt.includes('Explanations in English'));
  });

  it('throws when concept is not found', () => {
    assert.throws(
      () => buildSystemPrompt('nonexistent', 'beginner', 'ko'),
      /Concept not found: nonexistent/,
    );
  });

  it('extractMastery strips [MASTERY] and returns mastered=true', () => {
    const result = extractMastery('Great job understanding optionals! [MASTERY]');
    assert.equal(result.mastered, true);
    assert.equal(result.text, 'Great job understanding optionals!');
    assert.ok(!result.text.includes('[MASTERY]'));
  });

  it('extractMastery returns mastered=false when no marker', () => {
    const result = extractMastery('Can you explain what an optional is?');
    assert.equal(result.mastered, false);
    assert.equal(result.text, 'Can you explain what an optional is?');
  });

  it('extractMastery handles [MASTERY] in the middle of text', () => {
    const result = extractMastery('Good answer! [MASTERY] Well done.');
    assert.equal(result.mastered, true);
    assert.equal(result.text, 'Good answer! Well done.');
  });
});
