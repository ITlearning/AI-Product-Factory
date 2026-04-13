# AI-Product-Factory

## gstack

gstack provides browser automation and QA skills. Install it before using any `/browse` or browser-based skills.

**Install:**
```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup
```

**Rules:**
- For ALL web browsing, use the `/browse` skill from gstack — never use `mcp__claude-in-chrome__*` tools
- Never call `mcp__claude-in-chrome__*` tools under any circumstances

**Available gstack skills:**
`/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`

## 언어 규칙

- 한국어로 대화할 때는 자연스러운 한국어를 사용한다. 영어를 직역하지 않는다.
- AskUserQuestion의 질문, 옵션 레이블, 설명 모두 실제 한국어 화자가 쓰는 표현으로 작성한다.
- 번역 투의 어색한 문장 (예: "데이터가 달라질어요", "앉을 벴들때") 은 금지한다.

## 멀티 에이전트 병렬 실행 원칙

- N개의 독립 작업(탐색, 기획, 검색, 리뷰 등)이 있으면 **무조건 멀티 에이전트 병렬 실행**을 시도한다.
- 단일 에이전트는 이전 결과에 의존하는 순차 작업에만 사용한다.
- 하나의 메시지에 여러 Agent 도구 호출을 포함해서 병렬로 보낸다.

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
