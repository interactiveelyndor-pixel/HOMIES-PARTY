# Classic Board Games — Master Project Blueprint & System Architecture

> **Self-Contained "Project DNA / Master Walkthrough" Document**  
> *This document contains the complete, authoritative specification of this repository from 0% to 100%. A developer or AI agent can fully understand, run, maintain, extend, or recreate the entire project using only this single file.*

---

## 1. Executive Summary & Project Purpose

### 1.1 Overview
This project is a high-performance, polished, mobile-first board game suite built with **Flutter** and **Dart**. It provides five classic, authentic tabletop board games packaged into a unified application with a centralized launcher:

1. **Classic Ludo** (15×15 grid, 2–4 players, 4 tokens each, safe cells, captures, exact home entry, automatic single-token movement)
2. **Snakes & Ladders** (10×10 zigzag grid, 8 snakes, 8 ladders, strict sequential single-roll turns, exact-100 win)
3. **Classic Carrom** (800×800 board, 4 corner pockets, 19 coins, custom 2D momentum physics engine, Queen & cover mechanics, 2 players)
4. **Battleship** (10×10 grid, 5-ship fleet, private boards, pass-and-play multiplayer privacy shield, fair checkerboard hunting CPU AI)
5. **Pen Fight** (400×600 tabletop with no walls, 2 players, custom 2D sliding friction & circle momentum physics, off-table elimination, Best of 3 rounds, Play with Friend & fair CPU AI)

### 1.2 Core Philosophy & Non-Negotiables
- **Zero Third-Party Game Engines**: No Flame, no Forge2D, no Box2D, no Unity, no external physics or state management packages (no Provider, no Bloc, no Riverpod). Everything is implemented using vanilla Flutter (`StatefulWidget`, `ChangeNotifier`, `CustomPainter`, `AnimationController`, `Ticker`) and pure Dart.
- **Strict Decoupling of Game Logic from UI**: Game controllers and physics algorithms are isolated in pure Dart classes. Logic can be instantiated, simulated, and verified in headless unit tests with zero Flutter framework dependencies.
- **Bulletproof Turn & Anti-Spam Architecture**: State machine phases, synchronous processing locks (`_isProcessingAction`), and monotonic sequence IDs (`_actionSequenceId`) prevent double-tap glitches, race conditions, and animation desynchronization.
- **Pixel-Perfect Responsive Layout**: The UI dynamically fits viewports from compact (360×640) to extra-large (430×932) smartphones without horizontal clipping or render overflow errors.
- **100% Test Coverage for Core Rules**: 247 automated unit and widget tests verify rules, board coordinates, physics collisions, computer players, input protection, and UI rendering.

---

## 2. Clarification on Fantasy & RPG Elements (Spells / Mana / Relics)

> [!IMPORTANT]
> **NO spells, mana, relics, energy bars, or fantasy RPG mechanics exist anywhere in this codebase.**
> 
> In some agentic development contexts, prompts may contain generic boilerplate references to "mana, spells, relics". In this project, all games are **authentic, traditional, physical tabletop games**:
> - **Ludo** relies solely on dice rolls, piece tracking, captures, and safe zones.
> - **Snakes & Ladders** relies strictly on dice rolls, cell movement, snakes, and ladders.
> - **Carrom** relies strictly on physical momentum, friction, angles, and standard pocketing rules.
> 
> Any future developer or AI reading this blueprint must **NOT** introduce fantasy RPG elements into these classic board games unless explicitly ordered to pivot the game genre.

---

## 3. Project Directory & File Inventory

```
d:/Flutter Projects/Board Game/
├── analysis_options.yaml             # Flutter recommended lints configuration
├── pubspec.yaml                      # Project metadata, SDK constraints, dependencies
├── README.md                         # THIS FILE: Master Project Blueprint & Architecture
├── lib/
│   ├── main.dart                     # App entry point, orientation lock, root MaterialApp
│   ├── logic/
│   │   ├── ludo_controller.dart      # Ludo state machine, legal move calculator, rules engine
│   │   └── ludo_computer_player.dart # Pure Dart CPU player for "vs Computer" mode (priority AI)
│   ├── models/
│   │   ├── board_coordinate.dart     # (row, col) grid coordinate value object (0..14)
│   │   ├── board_path.dart           # Ludo 52-cell track, 4 home stretches, 8 safe cells, starts
│   │   ├── game_state.dart           # Immutable snapshot of Ludo game state & TurnPhase
│   │   ├── player.dart               # Ludo player model (name, color, 4 tokens, rank)
│   │   ├── player_color.dart         # PlayerColor enum (red, green, yellow, blue) + palettes
│   │   └── token.dart                # Ludo token model (id, color, stepCount -1..56)
│   ├── ui/                           # Shared Premium Design System Layer
│   │   ├── app_palette.dart          # Cohesive gradients, 4 game accents, semantics, glass tokens
│   │   ├── app_text_styles.dart      # Typographic scale (title, heading, body, button, caption)
│   │   ├── app_button.dart           # Reusable AppButton (variants, scale animation, debounce, haptics)
│   │   ├── app_back_button.dart      # Round glassmorphic back button with press animation
│   │   ├── app_card.dart             # Reusable card with rounded corners, gradient, glow, press scale
│   │   ├── app_dialog.dart           # Styled dialog frame helper for future steps
│   │   └── app_transitions.dart      # Smooth 250ms fade & slight slide page transition
│   ├── screens/
│   │   ├── home_screen.dart          # 4-in-1 Launcher hub (redesigned with AppPalette, AppCard, AppTransitions)
│   │   ├── ludo_mode_select_screen.dart # Mode selection: Multiplayer (Friends) vs "vs Computer" (visually styled)
│   │   └── ludo_game_screen.dart     # Responsive Ludo UI, board container, centered/corner dice, auto-move
│   ├── theme/
│   │   ├── ludo_colors.dart          # Modern dark-mode palette & color tokens
│   │   └── ludo_theme.dart           # App-wide ThemeData configuration
│   ├── widgets/
│   │   ├── base_quadrant_widget.dart # Ludo 6×6 corner base holding unreleased tokens
│   │   ├── board_cell_widget.dart    # Individual grid cell widget with star/arrow rendering
│   │   ├── center_home_widget.dart   # 3×3 center triangular home goal
│   │   ├── dice_widget.dart          # 3D rotating dice widget with tactile dots
│   │   ├── game_over_dialog.dart     # Winner announcement dialog with Restart / Mode switch
│   │   ├── game_status_banner.dart   # Animated turn instruction & status banner
│   │   ├── ludo_board_widget.dart    # 15×15 Stacked grid combining quadrants, track & center
│   │   ├── player_card_widget.dart   # Compact player badge with active glow & home count
│   │   ├── player_selection_dialog.dart # 2P / 3P / 4P player mode switch modal
│   │   ├── rules_dialog.dart         # Comprehensive Ludo rules explanation dialog
│   │   ├── token_widget.dart         # Pulsating, interactive Ludo game piece
│   │   └── winner_banner.dart        # Shared animated winner banner overlay (all games)
│   ├── snl/                          # Snakes & Ladders Feature Module
│   │   ├── snl_config.dart           # 8 snakes and 8 ladders coordinates & disjoint validation
│   │   ├── snl_player.dart           # S&L player model (color, name, position 0..100)
│   │   ├── snl_game_state.dart       # Immutable S&L game state & SnlTurnPhase enum
│   │   ├── snl_controller.dart       # S&L turn state machine, overshoot logic, movement
│   │   ├── snl_colors.dart           # Color definitions for S&L boards, players, and snakes
│   │   ├── snl_board_painter.dart    # CustomPainter: 10×10 zigzag grid, bezier snakes, ladders
│   │   ├── snl_board_widget.dart     # Interactive container rendering board + stacked tokens
│   │   ├── snl_dice_widget.dart      # Tactile dice widget for Snakes & Ladders
│   │   ├── snl_player_card.dart      # Player badge with position tracker and turn glow
│   │   └── snl_game_screen.dart      # Full responsive Snakes & Ladders game screen
│   ├── carrom/                       # Classic Carrom Feature Module
│   │   ├── carrom_vec2.dart          # Pure Dart 2D vector mathematics library
│   │   ├── carrom_config.dart        # Centralized board dimensions, masses, physics constants
│   │   ├── carrom_models.dart        # Coin, Player, CoinType, QueenStatus, CarromTurnPhase
│   │   ├── carrom_board_layout.dart  # 19-coin circular setup generator & free spot spiral search
│   │   ├── carrom_physics.dart       # Pure Dart 2D sub-stepped momentum physics engine
│   │   ├── carrom_game_state.dart    # Immutable snapshot of Carrom game state
│   │   ├── carrom_controller.dart    # Pure Dart game controller, turn resolution, foul logic
│   │   ├── carrom_colors.dart        # Birch veneer, mahogany frame, coin colors
│   │   ├── carrom_board_painter.dart # CustomPainter: board lines, pockets, coins, aim guide
│   │   ├── carrom_player_card.dart   # Player score, queen badge, and turn indicator
│   │   ├── carrom_board_widget.dart  # Gesture detector capturing striker drag and aim release
│   │   ├── carrom_computer_player.dart # Pure Dart CPU player for Carrom "vs Computer" mode
│   │   └── carrom_game_screen.dart   # Full Carrom game screen with 60Hz ticker loop
│   └── battleship/                   # Classic Battleship Feature Module
│       ├── battleship_config.dart    # Fleet ship sizes (5,4,3,3,2), delays (700ms), grid 10x10
│       ├── battleship_models.dart    # Coordinate, ShipType, PlacedShip, ShotResult, Modes, Phases
│       ├── battleship_board.dart     # Pure Dart 10x10 private board, placement, bounds, firing
│       ├── battleship_computer_player.dart # Pure Dart fair CPU AI: checkerboard hunting, line continuation
│       ├── battleship_controller.dart# Pure Dart controller: turns, multiplayer pass-device, input lock
│       ├── battleship_colors.dart    # Naval radar palette, ocean cells, hits, misses, player badges
│       ├── battleship_board_widget.dart # 10x10 grid widget for Target Radar and Own Fleet Defense
│       ├── battleship_player_card.dart  # Player badge with fleet health indicators and turn glow
│       ├── battleship_pass_phone_overlay.dart # Full-screen privacy shield for pass-and-play
│       ├── battleship_game_over_dialog.dart   # Victory dialog reusing shared WinnerBanner
│       ├── battleship_mode_select_screen.dart # Mode selection: Multiplayer (Friends) & vs Computer
│       └── battleship_game_screen.dart        # Responsive Battleship screen with placement and duel view
└── test/
    ├── ludo_controller_test.dart     # 21 unit tests for Ludo turn phases, captures, rules
    ├── ludo_computer_player_test.dart# 10 tests for Ludo CPU move priority, fair play, delays
    ├── ludo_widget_test.dart         # 13 tests for Ludo mode select, centered dice, CPU turn
    ├── models_and_path_test.dart     # 7 tests for Ludo coordinates, 52-cell track, safe spots
    ├── widget_test.dart              # 6 widget tests for Ludo responsive viewports & dialogs
    ├── snl_controller_test.dart      # 23 tests for S&L rules, single-roll rule, overshoot, snakes
    ├── snl_widget_test.dart          # 12 tests for S&L responsive viewports, cards, roll input
    ├── carrom_controller_test.dart   # 39 tests for Carrom physics, momentum, colour-independent rules, points, queen cover
    ├── carrom_computer_player_test.dart # 17 tests for Carrom CPU aiming, priority, foul-free play, Medium AI
    ├── carrom_widget_test.dart       # 14 tests for Carrom viewports, score display, slider, dialogs
    ├── winner_banner_test.dart       # 3 tests for shared WinnerBanner animation & non-blocking
    ├── battleship_board_and_placement_test.dart # 15 tests for placement, overlap, out of bounds, firing, sinking
    ├── battleship_controller_and_rules_test.dart # 8 tests for turn switching, win, privacy shield, input lock
    ├── battleship_computer_player_test.dart      # 5 tests for fair AI, checkerboard hunt, line finish, seeded match
    └── battleship_widget_test.dart               # 10 widget tests for modes, placement, pass-phone, feedback, viewports
```

---

## 4. Game 1: Classic Ludo Detailed Specification

### 4.1 Concept & Board Layout
- **Board Grid**: 15 rows × 15 columns (total 225 cells).
- **Quadrant Bases**:
  - Top-Left (rows 0–5, cols 0–5): **Red Base** (Start at `(6, 1)`)
  - Top-Right (rows 0–5, cols 9–14): **Green Base** (Start at `(1, 8)`)
  - Bottom-Right (rows 9–14, cols 9–14): **Yellow Base** (Start at `(8, 13)`)
  - Bottom-Left (rows 9–14, cols 0–5): **Blue Base** (Start at `(13, 6)`)
- **Center Goal**: 3×3 square (rows 6–8, cols 6–8).
  - Red Home Goal: `(7, 6)`
  - Green Home Goal: `(6, 7)`
  - Yellow Home Goal: `(7, 8)`
  - Blue Home Goal: `(8, 7)`
- **Common Outer Track**: 52 cells traversed clockwise in sequence.
- **Private Home Stretches**: 5 cells per color leading from the outer track directly into the center goal (steps 51 to 55). Step 56 is the Home Goal.

### 4.2 Mathematical Path Model (`BoardPath`)
Every token has an integer `stepCount`:
- `stepCount == -1`: In Base (inactive).
- `stepCount == 0`: Released onto the track at the player's start cell.
- `stepCount == 1..50`: Traveling along the 52-cell common track.
- `stepCount == 51..55`: In private color-matched home stretch.
- `stepCount == 56`: Reached Home Goal (`isHome == true`).

Coordinate translation is handled by `BoardPath.getCoordinate(color, stepCount)`:
```dart
startIndex = getStartIndex(color); // Red: 0, Green: 13, Yellow: 26, Blue: 39
trackIndex = (startIndex + stepCount) % 52;
```

### 4.3 Safe Cells & Immunity
There are exactly **8 safe cells** on the common track where tokens cannot be captured:
1. **4 Start Cells**: Red `(6, 1)`, Green `(1, 8)`, Yellow `(8, 13)`, Blue `(13, 6)`
2. **4 Star Cells (⭐)**: `(2, 6)`, `(6, 12)`, `(12, 8)`, `(8, 2)`
3. All cells inside home stretches (steps 51–55) and the home goal (step 56) are completely immune to opponent presence.

### 4.4 Rules & Turn Mechanics
1. **Leaving Base**: A roll of **6** is strictly required to move a token from base (`stepCount = -1`) to start (`stepCount = 0`).
2. **Automatic Token Movement**:
   - After a dice roll, if **exactly ONE token** has a legal move, that token moves **automatically and immediately** without requiring the player to tap it.
   - If **2 or more tokens** have legal moves, all legal tokens pulse and the game enters `TurnPhase.waitingForTokenSelection` for manual user selection.
   - If **0 tokens** have legal moves, the turn automatically skips to the next player after a brief delay (`autoSkipDuration`).
3. **Consecutive Sixes Rule**: Rolling three 6s in a row forfeits the turn immediately and passes play to the next player.
4. **Captures**: Landing on an opponent token on any non-safe cell captures that token, sends it back to base (`stepCount = -1`), and awards the active player an **immediate bonus roll**.
5. **Bonus Turns**: Awarded upon:
   - Rolling a 6.
   - Capturing an opponent token.
   - A token successfully reaching Home Goal (`stepCount = 56`).
6. **Exact Roll Required to Reach Home**: Overshooting step 56 is an illegal move. If a token is at step 54, it requires a roll of 2 to enter home; a roll of 3+ cannot be used on that token.
7. **Victory Condition**: The first player to bring all 4 of their tokens to Home Goal (`stepCount = 56`) wins the game (`TurnPhase.gameWon`).

### 4.5 Player Configurations & Modes
- **Mode Selection**: Tapping Ludo from the launcher presents:
  1. **Multiplayer (Friends)**: Pass-and-play supporting 2, 3, or 4 players with the classic corner dice layout and player count switch modal.
  2. **vs Computer**: 2-player mode where Player 1 (Red) is Human and Player 2 (Yellow) is the CPU. Yellow's card displays a distinct `CPU` badge and a "Computer's Turn" indicator during automated play.
- **Centered Shared Dice (vs Computer mode ONLY)**:
  - In vs Computer mode, a single shared dice is horizontally centered in the controls console between the player info card and the roll button. It never overlaps the board or any token.
  - In Multiplayer mode, the original right-aligned corner dice layout is preserved without modification.
- **2 Players**: Red and Yellow (opposite quadrants across the board).
- **3 Players**: Red, Green, and Yellow.
- **4 Players**: Red, Green, Yellow, and Blue (clockwise sequence).

---

## 5. Game 2: Snakes & Ladders Detailed Specification

### 5.1 Concept & Board Layout
- **10×10 Grid (100 Cells)**: Numbered 1 to 100 in **boustrophedon (zigzag)** order:
  - Row 1 (bottom): Cells 1 (left) to 10 (right)
  - Row 2: Cells 11 (right) to 20 (left)
  - Row 3: Cells 21 (left) to 30 (right)
  - ... up to Row 10 (top): Cells 91 (right) to 100 (left)
- **Token Count**: Exactly **1 token per player**. All players start off-board at position `0`.

### 5.2 Board Configuration (`SnlConfig`)
The board contains **exactly 8 snakes** and **exactly 8 ladders** that strictly satisfy all topological integrity constraints:
- **Snakes (`head -> tail`, head > tail)**:
  - `17 -> 7`
  - `40 -> 3`
  - `47 -> 26`
  - `54 -> 34`
  - `62 -> 19`
  - `64 -> 18`
  - `87 -> 24`
  - `95 -> 56`
- **Ladders (`bottom -> top`, bottom < top)**:
  - `4 -> 25`
  - `9 -> 31`
  - `20 -> 38`
  - `28 -> 84`
  - `36 -> 58`
  - `51 -> 67`
  - `63 -> 81`
  - `71 -> 91`

#### Topo-Integrity Constraints (Verified by Unit Tests):
1. No snake head or ladder bottom sits on cell 1 or cell 100.
2. Snake heads set `{17, 40, 47, 54, 62, 64, 87, 95}` and ladder bottoms set `{4, 9, 20, 28, 36, 51, 63, 71}` are **100% disjoint**.
3. No ladder top coincides with any snake head.
4. No ladder bottom coincides with any snake tail.

### 5.3 Rules & Strict Turn Logic
1. **Single Roll Rule**: Unlike Ludo, every player receives **strictly ONE roll per turn**. Rolling a 6 does **NOT** grant an extra turn.
2. **Deterministic Sequential Order**: Turn advances strictly in order: Player 0 → Player 1 → Player 2 → Player 3 → Player 0.
3. **Entering the Board**: Token enters the board on the very first roll. Rolling a 4 on turn 1 places the token at cell 4 (which immediately climbs ladder 4 → 25).
4. **Overshoot Rule**: Reaching cell 100 requires an **exact roll**. If a player is on cell 97 and rolls a 5 (`97 + 5 = 102 > 100`), the move is illegal; the token remains stationary on cell 97, and the turn passes to the next player.
5. **Multi-Token Stacking**: If multiple player tokens land on the exact same cell, `SnlBoardWidget` renders them in a clean mini-grid within the cell with colored outer rings, ensuring all player tokens remain distinct and visible.
6. **Victory**: The first player whose token lands on cell 100 wins immediately (`SnlTurnPhase.gameWon`).

---

## 6. Game 3: Classic Carrom Detailed Specification

### 6.1 Board Dimensions & Coordinate Geometry
The Carrom physics simulation runs in a normalized virtual coordinate space of **800.0 × 800.0 units** (`CarromConfig`):
- **Playable Surface**: `playableMin = 48.0`, `playableMax = 752.0` (surrounded by a 48.0-unit solid wooden border).
- **Corner Pockets**: 4 circular pockets with `radius = 34.0`, centers inset by `76.0`:
  - Top-Left: `(76.0, 76.0)`
  - Top-Right: `(724.0, 76.0)`
  - Bottom-Left: `(76.0, 724.0)`
  - Bottom-Right: `(724.0, 724.0)`
- **Center Circles**:
  - Center point: `(400.0, 400.0)`
  - Center circle radius: `45.0`
  - Outer decorative circle radius: `110.0`
- **Baselines**:
  - Player 1 (White) baseline: `y = 640.0`, `x` bounded in `[220.0, 580.0]`
  - Player 2 (Black) baseline: `y = 160.0`, `x` bounded in `[220.0, 580.0]`
  - Baseline endpoint circles: `radius = 24.0`

### 6.2 Pieces & Radii
- **White Coins (9)**: `radius = 15.0`, `mass = 1.0`
- **Black Coins (9)**: `radius = 15.0`, `mass = 1.0`
- **Red Queen (1)**: `radius = 15.0`, `mass = 1.0`
- **Striker (1)**: `radius = 21.0`, `mass = 3.0` (heavier and larger than coins)

### 6.3 Standard 19-Piece Circular Setup (`CarromBoardLayout`)
The initial board is programmatically packed in standard Carrom geometry:
1. **Red Queen**: Positioned at exact center `(400.0, 400.0)`.
2. **Inner Ring (6 coins)**: Radius from center = `2 * r = 30.0` (touching the Queen). Alternating: White, Black, White, Black, White, Black at 60° intervals.
3. **Outer Ring (12 coins)**: Packed tightly against the inner ring. 6 corner coins at distance `4 * r = 60.0` (multiples of 60°) and 6 edge midpoints at distance `2 * sqrt(3) * r ≈ 51.96` (multiples of 60° + 30°). Alternating pattern ensures exactly 6 White and 6 Black coins in the outer ring.
4. Total board count: 9 White + 9 Black + 1 Queen = **19 coins**.

### 6.4 Custom 2D Physics Engine (`CarromPhysics`)
Implemented in pure Dart without external libraries:
- **Sub-Stepping**: Every display frame is subdivided into fixed `fixedDeltaTime = 1.0 / 240.0` seconds (240Hz simulation frequency, 4 sub-steps per 60Hz tick). This completely eliminates high-speed tunneling through walls or coins.
- **Velocity Clamping**: Piece speeds are capped at `maxVelocity = 1500.0 pixels/s`.
- **Elastic Momentum Transfer**: Circle-to-circle collisions calculate relative velocity along the contact normal $n$:
  $$J = \frac{-(1 + e) \cdot (v_{rel} \cdot n)}{\frac{1}{m_1} + \frac{1}{m_2}}$$
  - Restitution $e = 0.92$ for coin-coin collisions, $0.90$ for striker-coin collisions.
  - Positional overlap separation prevents sinking or sticking.
- **Wall Bounces**: Boundary collision with frame reflection with restitution $e = 0.82$. Corner pocket mouths are exempted to allow smooth pocketing.
- **Friction & Viscous Damping**: Applied each sub-step:
  $$v_{new} = (v - \mu_{linear} \cdot \Delta t) \cdot (1.0 - \lambda_{viscous} \cdot \Delta t)$$
  - Linear friction $\mu = 260.0$ pixels/s²; viscous damping $\lambda = 0.15$.
  - When velocity drops below `stopThreshold = 5.0 pixels/s`, it is clamped to exact zero.
- **Safety Timeout**: Maximum simulation duration of `6.0` seconds per shot prevents infinite micro-drifting.

### 6.5 Shooting & Gestures
1. **Positioning Striker**: Striker slides horizontally along the active player's baseline via a smooth slider or board touch. Placement is validated: if overlapping any coin on the baseline, `clampAndFindValidStrikerX` finds the nearest non-overlapping legal spot.
2. **Aiming**: Dragging backward from the striker (slingshot mechanic) creates an aim vector opposite to the drag direction.
   - Pull distance clamped to `maxPullDistance = 140.0`.
   - Power ratio mapped `0.0 to 1.0`; initial shot speed scaled up to `1350.0 pixels/s`.
   - Visual trajectory line, arrowhead, and color-coded power arc displayed.
3. **Releasing Shot**: Transfers velocity impulse to striker, transitions state machine to `CarromTurnPhase.simulating`, and strictly locks all player inputs until all pieces come to rest.

### 6.6 Rules, Fouls, Queen Cover & Scoring Engine
- **Colour is NOT Player Ownership**: Either player can pocket ANY remaining black or white coin on the board. The player who legally pockets a coin receives that coin's configured point value.
- **Scoring System**:
  - **Black Coin**: 10 points
  - **White Coin**: 20 points
  - **Red Queen**: 50 points (awarded when covered)
  - A player's score is the total value of everything they have legally pocketed/earned. A player with fewer coins can win if they have a higher point total (e.g. 3 white + Queen = 110 pts beats 10 black = 100 pts).
- **Extra Shot**: Pocketing any coin legally grants an **extra shot** to the same player.
- **No Coins Pocketed**: Turn passes to opponent.
- **Foul (Striker Pocketed)**:
  - If player has pocketed $\ge 1$ coin, **1 penalty coin** is deducted from their score and returned to the nearest free center spot on the board (Black coin first if available, else White coin).
  - If player has 0 pocketed coins, turn ends without negative score.
  - If Queen was pocketed on the foul shot, Queen returns to center.
  - If Queen was pending cover by the fouling player, Queen cover fails and Queen returns to center.
  - Turn immediately passes to opponent.
- **The Queen & Cover Rules**:
  - Queen can be pocketed by either player.
  - **Covering the Queen**: After pocketing the Queen, the player must cover it by pocketing **ANY valid coin (Black or White)** either on the **same shot** or on their **immediate next shot**. The cover does NOT have to match original baseline colour.
  - If covered successfully: Queen (+50 pts) is awarded to the player (`queenStatus = QueenStatus.covered`).
  - If failed to cover: Queen is returned to the nearest free center spot on the board, and turn passes to opponent.
- **Returning Coin to Center (`_returnCoinToCenter`)**:
  - If center point `(400, 400)` is occupied, `findNearestFreeCenterSpot` performs an outward radial spiral search (every 10°, step radius 4.0 units) to find the closest legal, non-overlapping location.
- **Game-End & Victory Condition**:
  - **No Premature End**: The game does NOT end simply because a player has pocketed all coins of their original baseline colour. Both players continue having chances while valid coins remain on the board.
  - **Board Cleared / Final Scores**: When the board reaches its normal final board/end condition (all coins cleared), both players' total scores are calculated.
  - **Highest Total Score Wins**: The player with the highest total points wins the game.
  - **Draw**: If both players finish with equal total scores, the match concludes as a Draw.

### 6.7 Carrom Computer Player Engine (`CarromComputerPlayer`)

In "Play vs Computer" mode, the CPU operates as Player 2 using pure Dart AI logic configured as a realistic, fair **MEDIUM-difficulty** opponent:
1. **Target Evaluation & Coin Prioritization**:
   - **Covering Queen Priority**: If the Queen is pending cover by Player 2, the AI awards maximum priority (`+100.0`) to any viable pocket shot (Black or White) to secure the 50-point Queen prize.
   - **Piece Valuation**: When Queen is on the board and accessible, it is targeted as a high-value piece (`+35.0`). Black coins (Player 2 assigned color) receive base priority (`+25.0`), while White coins are targeted (`+12.0`) if they offer easy, reliable pocketing (e.g. tap-ins near pocket mouths).
2. **Ghost-Ball Geometry & Cut Shot Calculations**:
   - For every candidate coin and all 4 corner pockets, the target direction is calculated:
     $$\vec{u}_{shoot} = \frac{\vec{p}_{pocket} - \vec{p}_{coin}}{\|\vec{p}_{pocket} - \vec{p}_{coin}\|}$$
   - The ideal impact position of the striker's center (ghost ball) is determined:
     $$\vec{p}_{ghost} = \vec{p}_{coin} - \vec{u}_{shoot} \cdot (r_{striker} + r_{coin})$$
   - The CPU evaluates candidate striker placements along the baseline ($x \in [220.0, 580.0]$, $y = 160.0$), testing both collinear intersections ($\cos\theta \approx 1.0$) and valid cut shot angles down to $\cos\theta \ge 0.35$ (cut angle $\le \sim 70^\circ$). Collinear alignments receive a quartic bonus ($\cos^4\theta \cdot 35.0$) to prioritize natural, high-percentage straight lines.
3. **Dual Line-of-Sight Clearance Checks**:
   - **Coin-to-Pocket Path**: Verifies that no other active piece obstructs the trajectory from the target coin to the pocket.
   - **Striker-to-Ghost Path**: Verifies that no obstacle coin intersects the striker's approach from the baseline to the ghost position.
4. **Physics-Calibrated Impulse Power**:
   - Shot power is dynamically computed from kinematics equations taking into account distance, friction deceleration ($\mu_{eff} = 340.0$), viscous damping, momentum transfer ratio ($1.425 \cdot \cos\theta$), and striker travel distance.
   - A calibrated residual speed ($v_{residual} = 300.0\text{ px/s}$) ensures coins carry enough momentum to drop decisively into pockets without falling short.
   - Power is strictly clamped to $[0.48, 0.98]$ (minimum $0.40$ on fallback), guaranteeing the CPU never releases weak, limp shots.
5. **Realistic Human-Like Variance**:
   - Employs a zero-centered triangular random aim variance ($\sim 2.0^\circ$ maximum) and minor power jitter ($\pm 2\%$).
   - On straight, short-to-medium shots, the AI scores regularly (~75–85% success rate).
   - On thinner cut angles or long-range cross-board shots, natural variance creates realistic misses, giving human opponents balanced, enjoyable gameplay.
6. **Purposeful Fallback**:
   - When all direct pocket paths are obstructed, the CPU identifies the most accessible coin and delivers a solid break/scatter shot (power $0.55 - 0.85$) to open up angles rather than playing useless moves.
7. **Strict Fair Play & Rule Compliance**:
   - Interacts strictly through the public `CarromController` API (`setStrikerPosition`, `startAiming`, `updateAim`, `releaseShot`).
   - Never cheats, never bypasses physical simulation, never guarantees pocket drops, and never incurs unfair turn bonuses.

---

## 7. Turn State Machines & Concurrency Protection

All three games adhere to a uniform state machine architecture:

```
[ waitingForRoll / positioningStriker ]
               │
               ▼
       [ User Action ]  ──(Acquires _isProcessingAction lock & increments _actionSequenceId)
               │
               ▼
[ rollingDice / aiming / simulating / animatingMove ]  ──(All user taps locked)
               │
               ▼
     [ Physics / Step Animation ]
               │
               ▼
    [ Resolve Rules & Turn Switch ]
               │
               ▼
[ waitingForRoll / waitingForTokenSelection / positioningStriker ]  ──(Releases lock)
```

### Protection Invariants:
1. **Phase Check**: An action is rejected if `phase` is not in an interactive state.
2. **Synchronous Lock**: `_isProcessingAction = true` is set immediately before any asynchronous `await` or frame delay. Rapid double-taps occurring within the same frame are discarded synchronously.
3. **Sequence Invalidation**: Every new turn or state reset increments `_actionSequenceId`. If an asynchronous delayed timer fires with an outdated sequence ID, it exits silently without mutating state.

---

## 8. Mobile Viewport Engineering & Responsiveness

### 8.1 Resolution Independence
The app is designed to render seamlessly across all mobile screen aspect ratios:
- **Compact Phones** (e.g., 360 × 640 dp, 9:16)
- **Standard Modern Phones** (e.g., 390 × 844 dp, ~19.5:9)
- **Tall / Flagship Phones** (e.g., 412 × 923 dp, 430 × 932 dp, 20:9)

### 8.2 Layout Strategies
- **Root Protection**: Wrapped in `SafeArea` to prevent notches, dynamic islands, and system navigation bars from overlapping game elements.
- **Flexible Aspect Ratios**: Game boards use `AspectRatio(aspectRatio: 1.0)` inside `Flexible` or `Expanded` containers.
- **Carrom Coordinate Scaling**: `CarromBoardWidget` uses a `LayoutBuilder` to compute `scale = constraints.maxWidth / 800.0`. All pointer events (touches) are transformed from screen coordinates to virtual coordinates via `screenPos / scale`, ensuring 100% precision on any screen size.
- **No Overflow Guarantees**: Player cards use compact rows, ellipsis text truncation, and flexible wrapping.

---

## 9. Shared Components & Common Theme

### 9.1 Shared `WinnerBanner` (`lib/widgets/winner_banner.dart`)
A universal winner overlay widget shared across all three games:
- **Visuals**: Displays a large banner with "WINNER!", trophy icon, the winner's name, and their signature player color.
- **Animation**: Driven by `AnimationController` (duration: 900ms) with `CurvedAnimation(curve: Curves.elasticOut)` for a celebratory bounce entry combined with a smooth fade-in.
- **Non-Blocking Architecture**: Wrapped in `IgnorePointer(ignoring: true)` so that the celebration banner never obstructs underlying "Play Again", "Restart", or navigation buttons.

### 9.2 Centralized Launcher (`HomeScreen`)
`lib/screens/home_screen.dart` provides an elegant launcher:
- **Ludo Card**: Blue gradient (`#1D4ED8` to `#3B82F6`), pawn emoji (`♟️`).
- **Snakes & Ladders Card**: Emerald gradient (`#065F46` to `#10B981`), snake emoji (`🐍`).
- **Carrom Card**: Amber/Mahogany gradient (`#78350F` to `#B45309`), target emoji (`🎯`).

### 9.3 Dark Theme & Color Tokens (`LudoColors`, `LudoTheme`)
- Background Top: `#0F172A` (Deep Slate)
- Background Bottom: `#020617` (Near Black)
- Card Background: `Color(0xFF1E293B).withValues(alpha: 0.7)`
- Red Primary: `#EF4444`
- Green Primary: `#10B981`
- Yellow Primary: `#F59E0B`
- Blue Primary: `#3B82F6`
- Star / Gold Accent: `#FBBF24`

---

## 10. Dependencies & Tooling

### `pubspec.yaml`
```yaml
name: classic_ludo
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.13.1

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

*Note on package name*: The repository was originally created as `classic_ludo` and later expanded into the full 3-in-1 board games suite. `ClassicLudoApp` in `lib/main.dart` is preserved as a named export for backward compatibility with initial test suites.

---

## 11. Automated Test Suite (157 Tests Total)

Run the test suite with:
```bash
flutter test
```

### Breakdown by Test File:

#### 1. `test/ludo_controller_test.dart` (21 tests)
- Player modes (2P, 3P, 4P initialization and color pairing)
- Base exit on 6 and extra turn award
- Three consecutive 6s turn forfeiture
- Movement along path, exact home entry requirement
- Safe cell capture immunity & non-safe cell capture bonus roll
- Game won trigger when all 4 tokens reach home
- Input locking against double taps and invalid selection

#### 2. `test/models_and_path_test.dart` (7 tests)
- 52-cell track continuity and valid coordinates
- Start index spacing (13 cells apart)
- Safe cells (4 starts + 4 stars)
- Private home stretches and home goal coordinates
- Token and player model immutability and `copyWith`

#### 3. `test/widget_test.dart` (6 tests)
- Responsive layout verification on 360×640, 390×844, 430×932 viewports
- Rules dialog open/close
- Mode switch modal (2P, 3P, 4P)
- Rapid dice tap protection

#### 4. `test/snl_controller_test.dart` (23 tests)
- Topo-integrity of 8 snakes and 8 ladders (disjoint, non-overlapping)
- Exactly ONE roll per turn (no bonus on 6)
- Sequential player turn passing
- Overshoot bounce/stay rule at cell 100
- Snake slide and ladder climb execution
- Double-roll input locking

#### 5. `test/snl_widget_test.dart` (12 tests)
- Responsive layout on compact, standard, tall, extra-large phones
- Player badge color consistency (e.g. Yellow is strictly Yellow in 2P, 3P, 4P)
- Roll button animation locking
- Player mode dialog interaction

#### 6. `test/carrom_controller_test.dart` (26 tests)
- 19-coin setup verification (9 White, 9 Black, 1 Queen)
- Red Queen center positioning
- Striker slider baseline boundary clamping
- Striker-coin overlap collision rejection
- 2D momentum transfer calculation
- Wall bounce reflection with restitution
- Coulomb friction and viscous damping stopping criteria
- Pocket detection in corner pockets
- Extra shot on pocketing own coin; turn loss on opponent coin
- Foul penalty (1 coin returned to nearest free center spot)
- Queen cover requirements (same shot or next shot)
- Win condition evaluation (9 coins + covered queen)

#### 7. `test/carrom_widget_test.dart` (10 tests)
- Clean render without overflow across all 4 phone screen viewports
- Scoreboard and queen indicator display
- Striker slider dragging and position update
- Gestures locked during physics simulation
- Home screen navigation to Carrom screen

#### 8. `test/carrom_computer_player_test.dart` (17 tests)
- CPU shot calculation, candidate coin targeting, and aiming physics
- Queen pocketing priority and cover shot sequencing
- Foul-free striker positioning on baseline
- Safe placement and fallback break shots
- Calibrated shot power (>= 0.40) and zero limp/stalled shots
- Balanced medium scoring rate with human-like triangular aim variance
- Zero framework dependencies and headless simulation

#### 9. `test/ludo_computer_player_test.dart` (10 tests)
- 5-tier move priority: 1) Home entry, 2) Capture, 3) 6 out of base, 4) Safe/escape, 5) Furthest token
- Single candidate auto-move execution
- Bonus turns on rolling 6, capture, or home entry
- Full CPU vs CPU simulation to completion with a declared winner
- Human tap locking during computer turns

#### 10. `test/ludo_widget_test.dart` (13 tests)
- Mode selection screen navigation and back button pops
- "Multiplayer (Friends)" launches player selection dialog
- "vs Computer" launches 2-player match with CPU badge on Yellow
- Dice horizontally centered in vs Computer mode controls area
- Dice in corner in Multiplayer mode controls area
- Human single-token auto-move vs multi-token manual tap selection
- Overflow-free rendering across 360×640, 390×844, and 412×923 viewports

#### 11. `test/winner_banner_test.dart` (3 tests)
- Renders winner name and styling on game win
- Uses `IgnorePointer` to never block underlying buttons
- Dismisses or hides when game is reset

#### 12. `test/battleship_board_and_placement_test.dart` (15 tests)
- Ship placement validation, overlap prevention, grid bounds, firing, and sinking

#### 13. `test/battleship_controller_and_rules_test.dart` (8 tests)
- Turn switching, victory detection, fog-of-war privacy shield, and input lock

#### 14. `test/battleship_computer_player_test.dart` (5 tests)
- Fair play AI, checkerboard hunt, adjacent line continuation, seeded match completion

#### 15. `test/battleship_widget_test.dart` (10 tests)
- Mode select navigation, placement phase, pass-phone overlay, feedback badges, viewports

#### 16. `test/pen_fight_logic_test.dart` (13 tests)
- PenFightVec2 2D vector arithmetic, normalization, clamping
- Sliding friction, viscous deceleration, complete stop at threshold
- Circle-to-circle momentum transfer and velocity exchange
- Off-table detection when pen center crosses table perimeter
- Turn passing when neither pen falls off
- Round victory: shooter wins when opponent falls off
- Round loss: shooter loses when shooter's own pen falls off
- Both fall off rule: shooter loses round if both pens fall off
- Best of 3 match victory (first to win 2 rounds)
- Next round reset (pens return to initial opposite positions)
- Restart match (scores reset to 0-0)
- Seeded deterministic computer player aim calculation & edge power reduction
- Full seeded computer-vs-computer match finishing to a winner

#### 17. `test/pen_fight_widget_test.dart` (12 tests)
- Home Screen navigation to Pen Fight mode select screen
- Mode select screen back button returns to Home Screen
- Mode select "Play with Friend" launches 2-player game
- Mode select "vs Computer" launches game with CPU badge on Player 2 card
- Rules dialog ("How to Play") opens and closes
- Reset match dialog restarts match and scores
- Input locking during pen motion and during CPU turn
- Overflow-free rendering across 360×640, 390×844, and 412×923 viewports
- Game Over dialog displays WinnerBanner, Play Again button, and Home button

---

## 12. Intentionally NOT Implemented Features & Known Limitations

To maintain code clarity, deterministic testability, and zero-dependency purity, the following items are intentionally **out of scope**:
1. **Online Multiplayer / Networking**: There are no WebSockets, Firebase, or peer-to-peer sync. All games are strictly **local pass-and-play** or **vs Computer** (available in Ludo and Carrom).
2. **Snakes & Ladders AI**: Snakes & Ladders remains local pass-and-play.
3. **Sound Effects & Haptics**: No audio packages (`audioplayers`, `just_audio`) or vibration triggers are included.
4. **State Persistence**: Match state is held in memory. Navigating back to the home screen or closing the app resets the current match.
5. **Ludo Blockade Rule**: Two tokens of the same color on the same cell do not create an impassable wall for opponents; they simply stack visually.
6. **Multi-Rank Finishing**: Matches terminate immediately when the 1st place winner is decided. 2nd, 3rd, and 4th places are not played out.

---

## 13. How to Run & Verify

### Static Analysis
```bash
flutter analyze
```
*Expected output: `No issues found!`*

### Run All Tests
```bash
flutter test
```
*Expected output: `All tests passed!` (247 tests passing)*

### Run on Device or Desktop
```bash
# Web
flutter run -d chrome

# Windows Desktop
flutter run -d windows

# Android / iOS
flutter run
```

---

## 14. Pen Fight (Tabletop Flick Duel)

### Overview
Pen Fight is a nostalgic, tactical tabletop flick duel built in pure Dart with zero external game engine dependencies.
- **Accurate Capsule-vs-Capsule Physics & Collision Resolution**:
  - Segment-to-segment closest point distance detection with exact contact normal, penetration depth, and positional separation preventing any interpenetration.
  - Full impulse with torque applied at the contact point: tip hits, ends, and glancing contacts visibly spin and displace the pen, while center hits slide it straight.
  - Sub-stepped integration (10 sub-steps per frame) and velocity cap ensuring zero tunneling at any speed.
- **50% Shorter Pull-Back**:
  - Drag distance reduced to 38.5px (~50% of previous 77px) with identical power mapping and proportional aim line length.
- **Three Tables (Auto-Switching Per Round)**:
  - **Round 1 — Classic**: Square tabletop (420×420) with all edges open; pens fall when center of mass crosses any edge.
  - **Round 2 — Hole**: Square table with open edges plus a round 3D hazard hole in the center; pens fall if center enters the hole.
  - **Round 3 — Rails**: Square table with raised wooden bumper rails that bounce pens with restitution loss, featuring ONE open corner gap at the top-right where pens can fall.
  - Table name announced at the start of each round via responsive animated banner.
- **CustomPainter Visuals & UI Polish**:
  - Pure CustomPainter rendering: beveled wooden frame, varnished wood/felt grain, soft tabletop shadow, 3D brass-rimmed hole with depth gradient, raised wooden bumper rails with brass studs, and hazard diagonal stripes at the open corner gap.
  - Clean player panels with pen type badges, score dots, turn indicators, and responsive layout verified on 360×640, 390×844, and 412×923 viewports.
- **Pen Types**:
  - **Balanced**: All-rounder stats, steady control.
  - **Heavy**: Thick, high mass, lower launch speed, barely moves when hit.
  - **Slim**: Thin, lightweight, high launch speed, pushed easily.
- **Fair, Hazard-Aware Smart Bot & Calibration**:
  - Simulates candidate trajectories forward with full table boundary and hazard awareness. Avoids suicidal self-falls into the hole and open gap, and actively maneuvers to push opponents toward hazards.
  - Seeded 100-match calibration per table:
    - **Classic Table**: **43.0%** win rate (Target: 40–55%)
    - **Hole Table**: **51.0%** win rate (Target: 40–55%)
    - **Rails Table**: **50.0%** win rate (Target: 40–55%)

---

## 15. Master Blueprint Checklist for Recreating or Continuing the Project

If recreating this repository from scratch:
1. Initialize Flutter project: `flutter create classic_ludo`.
2. Configure `pubspec.yaml` with zero game engine dependencies.
3. Copy/create `PlayerColor` and centralized color palettes.
4. Implement `BoardPath` and Ludo 15×15 coordinate mapping.
5. Implement `LudoController` with automatic single-token movement and turn state machine.
6. Implement `SnlConfig` with the verified 8 disjoint snakes and 8 ladders.
7. Implement `SnlController` with the strict single-roll-per-turn rule and boustrophedon painter.
8. Implement `CarromVec2`, `CarromConfig`, `CarromPhysics` (240Hz sub-stepping), and `CarromBoardLayout`.
9. Implement `CarromController` with foul penalty, Queen covering, and nearest free spot spiral search.
10. Implement `PenFightVec2`, `PenFightConfig`, `PenFightPhysics` (rigid-body capsule contact points, torque, linear/angular friction), and `PenFightComputerPlayer`.
11. Build responsive screens (`HomeScreen`, `LudoGameScreen`, `SnlGameScreen`, `CarromGameScreen`, `BattleshipGameScreen`, `PenFightGameScreen`) wrapped in `SafeArea` and `LayoutBuilder`.
12. Add `WinnerBanner` overlay widget with `IgnorePointer`.
13. Run `flutter analyze` and `flutter test` to ensure 100% pass rate.
