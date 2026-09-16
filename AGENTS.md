# AutoMarket — AGENTS.md

## Core rules

- Use the Godot MCP as the primary interface for editing, running, debugging, and testing the game.
- Default Godot project root: `D:\AutoMarket\AutoMarket`.
- In Orca worktrees, operate on the active worktree, not the main checkout.
- Use direct executables/UI automation only when the Godot MCP cannot perform the required operation; state the limitation first.
- Prefer the smallest correct change. Preserve existing public interfaces and stable systems.
- Verify real files, APIs, node paths, signals, classes, and functions before using them.
- Do not mix unrelated refactors or cosmetic changes into functional work.

## Project

AutoMarket is an educational Godot game with web export support. Players automate game systems by writing code in the project's custom scripting language.

Relevant interpreter/runtime areas may include:
- lexer;
- parser;
- AST;
- printer/debug representation;
- executor/runtime;
- scopes and call stack;
- built-ins;
- synchronous/incremental/asynchronous execution;
- validators/analyzers;
- editor/runtime integration.

Do not assume a single language backend or runtime path. Confirm the active implementation before changing interpreter behavior.

## Godot

When changing scenes, scripts, or resources:
- verify node paths;
- preserve existing signal connections;
- avoid duplicate signal connections;
- respect node lifecycle/readiness;
- do not invent autoloads, singletons, or event buses;
- keep domain logic outside UI when an appropriate layer already exists;
- preserve web-export compatibility;
- avoid blocking the main thread;
- investigate the source of `null` values instead of masking them.

For UI work, preserve responsiveness, readability, and behavior across relevant resolutions.

## Interpreter

Interpreter changes require extra care.

Check all affected layers when relevant:
- lexer/tokens;
- parser;
- AST;
- printer/debug output;
- runtime/executor;
- scopes/call stack;
- built-ins;
- validation/analysis;
- errors;
- editor integration;
- tests/examples.

Preserve existing semantics unless explicitly changed, including control flow, precedence, scope behavior, call stack behavior, collection semantics, entry-point rules, execution budgets, and incremental execution.

Do not perform deep interpreter rewrites without explicit need.

Loops/recursion must not freeze Godot. Respect execution limits, stepping, interruption, and async/incremental mechanisms.

Every functional interpreter change should include a minimal working script and, when relevant, an error/regression case.

## Gameplay

Gameplay changes must preserve the educational goal.

Check:
- the programming concept being taught;
- trivial bypasses;
- exploits;
- regressions of earlier challenges;
- clarity of player feedback;
- reward/time/cost consistency.

Prefer simple inputs/outputs, observable rules, and deterministic results.

## Saves and progression

Before changing persisted data, inspect the save system.

When format changes are necessary:
- preserve compatibility when practical;
- provide migration/defaults;
- never silently erase progress;
- document meaningful format changes.

Check money, upgrades, stock, customers, deliveries, rewards, and progression for exploits/regressions.

# Agent orchestration

The top-level agent is the **coordinator/maestro**.

Use Orca only when delegation adds value. Small/local tasks should be handled directly.

Use Orca for:
- independent parallel work;
- multi-system investigation;
- multi-file implementation;
- specialized review;
- large UI/gameplay/interpreter work;
- tasks that benefit from separate planning, implementation, and review.

Use the installed `orca-cli` and `orchestration` skills for Orca operations.

## Coordinator responsibilities

The coordinator must:
1. understand scope and acceptance criteria;
2. inspect docs/code/Graphify as needed;
3. decide direct execution vs orchestration;
4. build a small dependency DAG when orchestrating;
5. choose model + reasoning **explicitly for every worker**;
6. create isolated worktrees when parallel writes are needed;
7. send only necessary context;
8. monitor results, questions, failures, and blockers;
9. review/integrate worker output;
10. run final validation and inspect the integrated diff.

The coordinator should not implement the whole feature itself when safe delegation is clearly useful.

## Mandatory model routing

Never let workers inherit the coordinator model/effort by default.

Before every worker launch, explicitly choose:
- model;
- reasoning effort;
- role/scope;
- worktree;
- completion criteria.

### GPT-5.6 Luna
Use for:
- repository exploration;
- locating files/symbols/references;
- Graphify-assisted lookup;
- read-only investigation;
- simple tests;
- docs;
- repetitive/mechanical work;
- small isolated edits.

Reasoning: `low` by default, `medium` when analysis is needed.

### GPT-5.6 Terra
Use for:
- normal implementation;
- multi-file changes;
- debugging;
- moderate refactors;
- integration work;
- non-trivial Godot/UI/gameplay changes.

Reasoning: `medium` by default, `high` for difficult work.

### GPT-5.6 Sol
Reserve for:
- architecture;
- difficult/ambiguous debugging;
- major refactors;
- high-risk interpreter changes;
- critical review;
- escalation after Terra is insufficient.

Do not use Sol for routine workers.

### Escalation
Prefer: `Luna -> Terra -> Sol`

Escalate only when the task fails, remains uncertain, becomes more complex, or needs stronger architectural judgment.

Before escalating, check whether the real problem is missing context, poor decomposition, stale dependencies, or the wrong worktree.

## Nested orchestration

Workers must not create other workers by default.

The coordinator may explicitly designate a Terra worker as a **subcoordinator** when its task is large enough to benefit from decomposition.

Maximum depth:

`Coordinator -> Subcoordinator -> Helper`

Helpers must never delegate further.

Subcoordinators should offload cheap supporting work to Luna when useful, especially:
- codebase lookup;
- Graphify queries;
- symbol/reference discovery;
- read-only investigation;
- simple test generation;
- documentation;
- mechanical validation;
- small isolated edits.

Prefer top-level decomposition when those subtasks are already known before dispatch.

Do not create nested workers when orchestration overhead exceeds expected token/context savings.

Subcoordinators should summarize helper results instead of forwarding full transcripts.

# Worktrees and parallelism

- Parallel writing workers must use separate worktrees.
- Never allow two workers to write to the same worktree simultaneously.
- Do not parallelize tasks that heavily overlap files/state.
- Use explicit DAG dependencies for serial work.
- Worktrees prevent physical conflicts, not semantic conflicts.
- Confirm active worktree/branch before edits and integration.

Read-only investigators usually do not need their own write-oriented worktree unless required by the runtime.

# Graphify

When `graphify-out/` exists and is reasonably current:
1. read `GRAPH_REPORT.md` before broad exploration;
2. use Graphify to locate architecture/dependencies/impact;
3. narrow subsequent code reading;
4. verify critical details in real code.

Use Graphify for:
- architecture discovery;
- dependency analysis;
- impact analysis;
- task boundaries;
- locating related systems;
- planning Orca DAGs.

Graphify guides navigation; code remains the source of truth.

Update the graph after meaningful structural changes. Do not rebuild it unnecessarily.

# Matt Pocock skills

Use installed skills as engineering workflow tools, not mandatory ceremony.

For large/ambiguous features, prefer when useful:

`grill-with-docs -> prototype? -> to-prd -> to-tickets -> Orca DAG -> implementation -> review`

Skip steps that add no value.

Use `prototype` only when a technical uncertainty is expensive enough to justify an experiment.

## `/implement`

`/implement` is an execution skill, not the coordinator.

In orchestrated work, prefer:

`Orca task -> isolated worker/worktree -> /implement <ticket/spec> -> tests/review -> commit/result -> coordinator`

The coordinator owns decomposition, model routing, DAGs, integration, and cross-worker review.

A worker using `/implement` should implement only its assigned ticket/spec and must not redefine the project plan.

For small tasks, `/implement` may be used directly without Orca.

Use TDD/review skills when they materially improve confidence.

# Context discipline

Workers receive only what they need:
- task objective;
- acceptance criteria;
- relevant architecture/files;
- dependencies;
- established decisions;
- applicable AGENTS.md constraints.

Do not forward full conversation history when a summary is enough.

Worker output should be concise:
- summary;
- files changed;
- decisions;
- tests/checks run;
- unresolved problems.

# Recommended roles

## Investigator
Read-only when possible. Return relevant files, current flow, dependencies, likely cause, risks, and safe edit points.

## Implementer
Make only scoped changes, respect prior decisions, validate locally, and avoid unrelated work.

## Interpreter reviewer
Check lexer/parser/AST/runtime/scopes/built-ins/stepping/validators for regressions and missing tests.

## Godot reviewer
Check scenes, signals, node paths, lifecycle, state, responsiveness, runtime integration, and web compatibility.

## Gameplay reviewer
Check educational intent, clarity, trivial bypasses, exploits, economy, progression, and regressions.

## Final reviewer
Review the integrated result, not only isolated worker branches.

# Workflow

For non-trivial work:
1. read relevant docs;
2. use Graphify when useful;
3. inspect current code/behavior;
4. define scope and acceptance criteria;
5. choose direct execution or orchestration;
6. use planning/spec skills when useful;
7. create a small DAG;
8. route each worker to an explicit model + reasoning level;
9. use isolated worktrees for parallel writes;
10. run safe independent tasks in parallel;
11. collect results and resolve blockers;
12. review/integrate;
13. validate with tests and Godot MCP;
14. inspect the final diff;
15. remove accidental/out-of-scope changes;
16. update docs/Graphify when justified;
17. report the result concisely.

Do not stop at analysis when implementation was requested.

Do not claim success without relevant verification.

# Verification

Use existing repository tests/commands first.

When automated tests are insufficient:
- create/use a minimal reproduction;
- validate parsing/execution for interpreter changes;
- validate node paths/signals for Godot changes;
- validate behavior in the editor when relevant;
- inspect the diff;
- state what was and was not tested.

For worktree-based changes, run critical checks again after integration.

Do not add heavy tooling/dependencies just to test a small change.

# Completion criteria

A task is complete when:
- requested behavior is implemented;
- root cause is addressed, not masked;
- scope is respected;
- no accidental diff remains;
- relevant checks passed;
- worker outputs are integrated/reviewed;
- remaining risks are disclosed.

Final report:
- what changed;
- main files changed;
- checks performed;
- relevant architectural decisions;
- remaining risks only when they exist.

# Repository agent docs

- Issue tracker: `docs/agents/issue-tracker.md`
- Triage labels: `docs/agents/triage-labels.md`
- Domain docs: `docs/agents/domain.md`

Use GitHub Issues for durable/spec-level work. Orca-internal tasks may stay ephemeral when they do not need long-term tracking.
