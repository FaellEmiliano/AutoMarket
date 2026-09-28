# AutoMarket

AutoMarket is an educational programming game built with **Godot**, designed to teach programming logic through the automation of a supermarket.

Instead of solving isolated exercises, the player writes code that interacts directly with the game world: serving customers, managing stock, calculating change and automating increasingly complex tasks.

One of the project's main technical features is a **custom programming language interpreter implemented from scratch in GDScript** and integrated into the game's runtime.

## Highlights

- Educational game focused on programming logic and problem solving
- Custom programming language integrated into the gameplay
- Lexer, parser, AST and runtime/executor implemented in GDScript
- Support for variables, expressions, conditionals and loops
- Functions, recursion and control flow
- Arrays and game-specific built-in functions
- Stock, customer, transaction, sensor and upgrade systems
- In-game code editor and terminal
- Save system and progression mechanics
- Web export support

## Custom Interpreter

The game includes its own interpreter so player-written code can control systems inside the game.

The execution pipeline follows the general structure:

```text
Source Code
	↓
  Lexer
	↓
 Tokens
	↓
  Parser
	↓
   AST
	↓
 Executor / Runtime
	↓
 Game Systems
```

The interpreter supports programming concepts such as:

- variable declarations
- arithmetic and logical expressions
- `if` / `else`
- `while` and `for` loops
- functions and function calls
- recursion
- `return`
- `break` and `continue`
- arrays
- strings and booleans
- custom built-ins connected to the game

This allows the programming challenges to be part of the actual game simulation rather than a separate exercise screen.

## Architecture

The project is divided into systems with separate responsibilities.

```text
AutoMarket/
├── autoload/       # Global managers and shared state
├── interpreter/    # Programming language implementation
├── systems/        # Gameplay systems
├── scenes/         # Godot scenes and UI
├── data/           # Game data
├── tests/          # Interpreter and system tests
├── docs/           # Project documentation
└── assets/         # Visual and UI assets
```

Some of the main game systems include:

- `InterpreterSystem`
- `StockSystem`
- `TransactionManager`
- `SensorSystem`
- `UpgradeManager`
- `ChallengeSystem`
- `DeliverySystem`

These systems communicate with the game while keeping the interpreter separated from most gameplay logic.

## Initial integrated challenge

New games begin with **Mercado Automatizado** and a single free-form `Principal` file containing a simple Python-like Hello World. Players may keep checkout and stock logic together or create any number of files with arbitrary names; every Python-like file has access to the same market APIs. The initial balance is R$180 and five units of each catalog product. This is deliberately partial stock: buying one supplier lot of every product costs R$135, while a fixed purchase of ten units of every product costs R$270 and is rejected by the shared budget. The setup therefore supports valid early replenishment without making capacity or budget calculations irrelevant.

The challenge is evaluated from gameplay events rather than source-code shape or file identity. Completion requires three valid sales while at least one automation is active, at least one successful purchase made by a script, and a real recovery of a product that dropped below its catalog minimum. Manual purchases remain available but do not count as automation evidence.

## Technologies

- **Godot 4.7**
- **GDScript**
- Git / GitHub
- Custom lexer and parser
- Abstract Syntax Tree (AST)
- Custom runtime / interpreter

## Why I built it

AutoMarket started as an educational game project and evolved into an exploration of language implementation, software architecture and game systems.

The main challenge has been designing a programming environment that is simple enough for learning while still allowing increasingly complex algorithms and keeping execution synchronized with the game.

## Status

The project is under active development.

Current work includes expanding the programming language, increasing the complexity of the challenges and improving the in-game code editor to provide an experience closer to a real IDE.

## Running the project

1. Install a compatible version of Godot 4.
2. Clone the repository:

```bash
git clone https://github.com/FaellEmiliano/AutoMarket.git
```

3. Open `project.godot` in Godot.
4. Run the project.

## Author

Developed by **Rafael Gomes** as part of my studies in Software Development and educational game development.
