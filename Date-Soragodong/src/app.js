import React, { useState, useCallback, useEffect, useRef, useMemo } from "react";
import { drawCourse } from "./utils/course.js";
import { buildResultUrl } from "./utils/url.js";
import cards from "./data/cards.json" with { type: "json" };

const { createElement: h, Fragment } = React;

const CATEGORIES = [
  { key: "place",     label: "갈 곳",   icon: "🗺️", poolKey: "갈_곳",   filterKey: "placeFilter" },
  { key: "food",      label: "먹을 곳", icon: "🍱", poolKey: "먹을_곳", filterKey: "foodFilter" },
  { key: "transport", label: "탈 것",   icon: "🚌", poolKey: "탈_것",   filterKey: "transportFilter" },
  { key: "budget",    label: "금액",    icon: "💰", poolKey: "금액",     filterKey: "budgetFilter" },
];

/** Procedural star field — renders once */
function StarField() {
  const stars = useMemo(() => {
    const result = [];
    const count = 60;
    for (let i = 0; i < count; i++) {
      const size = Math.random() * 2.5 + 0.8;
      const x = Math.random() * 100;
      const y = Math.random() * 70;
      const dur = (Math.random() * 3 + 2).toFixed(1);
      const delay = (Math.random() * 4).toFixed(1);
      result.push(h("div", {
        key: i,
        className: "star",
        style: {
          width: `${size}px`,
          height: `${size}px`,
          left: `${x}%`,
          top: `${y}%`,
          "--twinkle-dur": `${dur}s`,
          "--twinkle-delay": `${delay}s`,
          opacity: Math.random() * 0.5 + 0.3,
        }
      }));
    }
    return result;
  }, []);
  return h("div", { className: "stars", "aria-hidden": "true" }, ...stars);
}

export function App() {
  // Active (expanded) category chip panel
  const [expanded, setExpanded] = useState(null);
  // Selected chips per category: { [filterKey]: Set<string> }
  const [selected, setSelected] = useState({
    placeFilter: new Set(),
    foodFilter: new Set(),
    transportFilter: new Set(),
    budgetFilter: new Set(),
  });
  const [drawError, setDrawError] = useState(false);

  const toggleExpand = useCallback((key) => {
    setExpanded(prev => prev === key ? null : key);
  }, []);

  const toggleChip = useCallback((filterKey, value) => {
    setSelected(prev => {
      const next = new Set(prev[filterKey]);
      next.has(value) ? next.delete(value) : next.add(value);
      return { ...prev, [filterKey]: next };
    });
  }, []);

  const handleAsk = useCallback(() => {
    const filters = {};
    for (const cat of CATEGORIES) {
      const s = selected[cat.filterKey];
      if (s.size > 0) filters[cat.filterKey] = [...s];
    }
    try {
      const course = drawCourse(filters);
      const url = buildResultUrl(course, window.location.origin);
      window.location.href = url;
    } catch (e) {
      console.error("drawCourse failed:", e);
      setDrawError(true);
    }
  }, [selected]);

  return h("div", { className: "app", role: "main" },
    h(StarField),

    // Decorative
    h("div", { className: "deco deco-moon", "aria-hidden": "true" }, "🌙"),
    h("div", { className: "deco deco-blossom-1", "aria-hidden": "true" }, "🌸"),
    h("div", { className: "deco deco-blossom-2", "aria-hidden": "true" }, "🌸"),
    h("div", { className: "deco deco-blossom-3", "aria-hidden": "true" }, "🌸"),

    // Status bar (decorative)
    h("div", { className: "status-bar", "aria-hidden": "true" },
      h("span", { className: "status-time" }, "9:41"),
      h("span", { className: "status-icons" }, "📶 🔋")
    ),

    // Hero
    h("section", { className: "hero", "aria-label": "소라고동 소개" },
      h("div", { className: "shell-wrap", "aria-hidden": "true" },
        h("div", { className: "shell-glow-ring" }),
        h("div", { className: "shell-glow-ring" }),
        h("div", { className: "shell-glow-ring" }),
        h("div", { className: "shell-glow-ring" }),
        h("span", { className: "shell-emoji", role: "img", "aria-label": "소라고동" }, "🐚")
      ),
      h("h1", { className: "hero-title" }, "데이트 소라고동"),
      h("p", { className: "hero-subtitle" }, "오늘의 데이트를 소라고동님께 물어보세요")
    ),

    // Category cards
    h("section", { className: "card-section", "aria-label": "카테고리 선택" },
      h("div", { className: "card-grid", role: "group" },
        CATEGORIES.map(cat => {
          const isExpanded = expanded === cat.key;
          const hasSelection = selected[cat.filterKey].size > 0;
          return h("button", {
            key: cat.key,
            className: "category-card",
            "aria-pressed": hasSelection || isExpanded ? "true" : "false",
            onClick: () => toggleExpand(cat.key),
            "aria-label": `${cat.label} ${isExpanded ? "접기" : "선택"}`,
          },
            h("span", { className: "card-icon", "aria-hidden": "true" }, cat.icon),
            h("span", { className: "card-label" }, cat.label),
            hasSelection && h("span", { className: "card-check", "aria-hidden": "true" }, "✓")
          );
        })
      ),

      // Chip panel for expanded category
      expanded && (() => {
        const cat = CATEGORIES.find(c => c.key === expanded);
        if (!cat) return null;
        const pool = cards[cat.poolKey] || [];
        return h("div", { className: "chip-panel" },
          h("div", { className: "chip-panel-title" },
            `${cat.icon} ${cat.label} — 선택하면 그 중에서만 뽑아요`
          ),
          h("div", { className: "chip-list" },
            pool.map(item =>
              h("button", {
                key: item,
                className: "chip",
                "aria-pressed": selected[cat.filterKey].has(item) ? "true" : "false",
                onClick: () => toggleChip(cat.filterKey, item),
              }, item)
            )
          )
        );
      })()
    ),

    // CTA
    h("button", {
      className: "cta-btn",
      onClick: handleAsk,
      "aria-label": "소라고동님께 오늘의 데이트 물어보기",
    }, "소라고동님께 물어보기 🐚"),

    drawError && h("p", {
      className: "draw-error",
      role: "alert",
    }, "소라고동님이 잠시 자리를 비우셨어요 🐚 잠시 후 다시 시도해주세요.")
  );
}
