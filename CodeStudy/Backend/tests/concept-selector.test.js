import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { selectDailyConcept } from '../src/concept-selector.js';

describe('selectDailyConcept', () => {
  it('returns the first beginner concept for a beginner with no mastered concepts', () => {
    const concept = selectDailyConcept('beginner', []);
    assert.ok(concept);
    assert.strictEqual(concept.id, 'swift-variables');
    assert.strictEqual(concept.order, 1);
    assert.strictEqual(concept.level, 'beginner');
  });

  it('skips mastered concepts and returns the next one', () => {
    const concept = selectDailyConcept('beginner', ['swift-variables']);
    assert.ok(concept);
    assert.strictEqual(concept.id, 'swift-type-annotations');
    assert.strictEqual(concept.order, 2);
  });

  it('returns first concept for review when all beginner concepts are mastered', () => {
    const allBeginner = [
      'swift-variables', 'swift-type-annotations', 'swift-if-else',
      'swift-for-loops', 'swift-optionals', 'swift-functions',
      'swift-arrays', 'swift-dictionaries', 'swift-string-interpolation',
      'swift-switch', 'swift-while-loops', 'swift-tuples',
    ];
    const concept = selectDailyConcept('beginner', allBeginner);
    assert.ok(concept);
    assert.strictEqual(concept.id, 'swift-variables');
  });

  it('basic level can access beginner and basic concepts', () => {
    const allBeginner = [
      'swift-variables', 'swift-type-annotations', 'swift-if-else',
      'swift-for-loops', 'swift-optionals', 'swift-functions',
      'swift-arrays', 'swift-dictionaries', 'swift-string-interpolation',
      'swift-switch', 'swift-while-loops', 'swift-tuples',
    ];
    const concept = selectDailyConcept('basic', allBeginner);
    assert.ok(concept);
    assert.strictEqual(concept.id, 'swift-closures');
    assert.strictEqual(concept.level, 'basic');
  });

  it('intermediate level can access beginner, basic, and intermediate', () => {
    const concept = selectDailyConcept('intermediate', []);
    assert.ok(concept);
    assert.strictEqual(concept.id, 'swift-variables');
    assert.strictEqual(concept.order, 1);
  });

  it('advanced level can access all concepts', () => {
    const concept = selectDailyConcept('advanced', []);
    assert.ok(concept);
    assert.strictEqual(concept.id, 'swift-variables');
  });

  it('advanced user gets advanced concepts after mastering lower levels', () => {
    const lowerLevelIds = [];
    // All beginner + basic + intermediate = orders 1-38
    const allIds = [
      'swift-variables', 'swift-type-annotations', 'swift-if-else',
      'swift-for-loops', 'swift-optionals', 'swift-functions',
      'swift-arrays', 'swift-dictionaries', 'swift-string-interpolation',
      'swift-switch', 'swift-while-loops', 'swift-tuples',
      'swift-closures', 'swift-enums', 'swift-structs-classes',
      'swift-properties', 'swift-methods', 'swift-initializers',
      'swift-optional-chaining', 'swift-guard-let', 'swift-map-filter-reduce',
      'swift-extensions', 'swift-access-control', 'swift-type-casting',
      'swift-subscripts',
      'swift-protocols', 'swift-error-handling', 'swift-generics',
      'swift-swiftui-state', 'swift-swiftui-lists', 'swift-swiftui-navigation',
      'swift-codable', 'swift-result-type', 'swift-keypaths',
      'swift-property-wrappers', 'swift-opaque-types', 'swift-swiftui-environment',
      'swift-combine-basics',
    ];
    const concept = selectDailyConcept('advanced', allIds);
    assert.ok(concept);
    assert.strictEqual(concept.id, 'swift-async-await');
    assert.strictEqual(concept.level, 'advanced');
  });

  it('returns concepts in order', () => {
    const concept1 = selectDailyConcept('beginner', []);
    const concept2 = selectDailyConcept('beginner', [concept1.id]);
    assert.ok(concept1.order < concept2.order);
  });

  it('handles unknown level gracefully (defaults to beginner)', () => {
    const concept = selectDailyConcept('unknown-level', []);
    assert.ok(concept);
    assert.strictEqual(concept.level, 'beginner');
  });

  it('handles empty masteredIds gracefully', () => {
    const concept = selectDailyConcept('beginner');
    assert.ok(concept);
    assert.strictEqual(concept.id, 'swift-variables');
  });
});
