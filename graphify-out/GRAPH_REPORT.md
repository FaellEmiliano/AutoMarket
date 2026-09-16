# Graph Report - feature-scriptMenu  (2026-09-14)

## Corpus Check
- 45 files · ~67,869 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 310 file(s) not represented in the graph (top: .uid 110, .gd 107, .import 43)

## Summary
- 75 nodes · 39 edges · 44 communities (6 shown, 38 thin omitted)
- Extraction: 62% EXTRACTED · 38% INFERRED · 0% AMBIGUOUS · INFERRED: 15 edges (avg confidence: 0.91)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Project Governance
- Shop Interior
- Issue Management
- Interpreter Architecture
- Domain Documentation
- IDE Run State
- Back Navigation
- Clear Action
- Close Action
- Error Status
- New Item Action
- IDE Search
- IDE Sleep State
- Help Button
- Collapse Control
- Explorer Control
- More Options
- Next Navigation
- Output Control
- Previous Navigation
- Stop Control
- Anxious Character
- Shop Background
- Village Background
- GitHub Button
- Start Button
- Customer Character
- Character Faces
- Happy Character
- App Icon 144
- App Icon 180
- App Icon 512
- App Icon
- Menu Variant
- Menu Board
- Purchase Note
- Rice Product
- Chocolate Product
- Flour Product
- Beans Product
- Strawberry Product
- Grape Product
- Game Title
- Game Controller

## God Nodes (most connected - your core abstractions)
1. `AutoMarket Agent Guidelines` - 9 edges
2. `Domain Documentation Rules` - 4 edges
3. `GitHub Issue Tracker Workflow` - 4 edges
4. `AutoMarket` - 3 edges
5. `Custom Programming Language Interpreter` - 3 edges
6. `Canonical Triage Label Mapping` - 3 edges
7. `Pixel Art Shop Interior` - 3 edges
8. `Godot MCP Policy` - 2 edges
9. `Interpreter Safety Constraints` - 2 edges
10. `Educational Gameplay Constraints` - 2 edges

## Surprising Connections (you probably didn't know these)
- `AutoMarket Agent Guidelines` --references--> `Domain Documentation Rules`  [EXTRACTED]
  AGENTS.md → docs/agents/domain.md
- `AutoMarket Agent Guidelines` --references--> `GitHub Issue Tracker Workflow`  [EXTRACTED]
  AGENTS.md → docs/agents/issue-tracker.md
- `AutoMarket Agent Guidelines` --references--> `Canonical Triage Label Mapping`  [EXTRACTED]
  AGENTS.md → docs/agents/triage-labels.md
- `Godot MCP Policy` --conceptually_related_to--> `Godot Web Export Support`  [INFERRED]
  AGENTS.md → README.md
- `Interpreter Safety Constraints` --rationale_for--> `Custom Programming Language Interpreter`  [INFERRED]
  AGENTS.md → README.md

## Hyperedges (group relationships)
- **AutoMarket Engineering Governance** — agents_automarket_agent_guidelines, docs_agents_domain_domain_docs, docs_agents_issue_tracker_github_issue_tracker, docs_agents_triage_labels_triage_labels [EXTRACTED 1.00]
- **Educational Interpreter Integrity** — agents_interpreter_safety, agents_gameplay_education, agents_verification_process, readme_custom_interpreter [INFERRED 0.85]
- **Shop Scene Composition** — assets_sprites_background_stocked_shelves, assets_sprites_background_checkout_counter, assets_sprites_background_open_shop_floor [EXTRACTED 1.00]

## Communities (44 total, 38 thin omitted)

### Community 0 - "Project Governance"
Cohesion: 0.29
Nodes (8): AutoMarket Agent Guidelines, Educational Gameplay Constraints, Godot MCP Policy, Incremental Change Policy, Save Compatibility Policy, Verification Process, AutoMarket, Godot Web Export Support

### Community 1 - "Shop Interior"
Cohesion: 0.40
Nodes (5): Cash Register, Checkout Counter, Open Shop Floor, Pixel Art Shop Interior, Stocked Product Shelves

### Community 2 - "Issue Management"
Cohesion: 0.50
Nodes (5): GitHub Issue Tracker Workflow, Pull Requests as Triage Surface, Wayfinding Issue Workflow, Ready for Agent, Canonical Triage Label Mapping

### Community 3 - "Interpreter Architecture"
Cohesion: 0.50
Nodes (4): Interpreter Safety Constraints, Custom Programming Language Interpreter, Interpreter Execution Pipeline, AutoMarket Game Systems

### Community 4 - "Domain Documentation"
Cohesion: 0.50
Nodes (4): ADR Conflict Disclosure, Domain Documentation Rules, Canonical Domain Vocabulary, Single-Context Domain Layout

### Community 5 - "IDE Run State"
Cohesion: 1.00
Nodes (3): IDE Running Icon, Right-Pointing Play Symbol, IDE Running State

## Knowledge Gaps
- **52 isolated node(s):** `AutoMarket Game Systems`, `Single-Context Domain Layout`, `Pull Requests as Triage Surface`, `IDE Back Arrow Icon`, `Back Navigation` (+47 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 57 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **38 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AutoMarket Agent Guidelines` connect `Project Governance` to `Issue Management`, `Interpreter Architecture`, `Domain Documentation`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **Why does `Domain Documentation Rules` connect `Domain Documentation` to `Project Governance`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Why does `Interpreter Safety Constraints` connect `Interpreter Architecture` to `Project Governance`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `AutoMarket Game Systems`, `Single-Context Domain Layout`, `Pull Requests as Triage Surface` to the rest of the system?**
  _52 weakly-connected nodes found - possible documentation gaps or missing edges._