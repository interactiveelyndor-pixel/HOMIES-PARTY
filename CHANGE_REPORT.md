# Change Report: Classic Board Games (Ludo, Snakes & Ladders, Carrom, and Battleship)

## Summary of Changes
1. **UI/UX Redesign STEP 1 — Shared Design Layer & Home Screen (`lib/ui/`, `lib/screens/home_screen.dart`)**:
   - **Shared Design Layer (`lib/ui/`)**:
     - `app_palette.dart`: Cohesive palette featuring dark obsidian/slate background gradient (`#0F172A` to `#070B18`), 4 vibrant game accents (Ludo `#3B82F6`, Snakes & Ladders `#10B981`, Carrom `#F59E0B`, Battleship `#06B6D4`), semantic colors (success, warning, danger), and glass/surface constants.
     - `app_text_styles.dart`: Complete type scale (`title`, `heading`, `subheading`, `body`, `bodyBold`, `button`, `caption`, `badge`) with strong weights, readable sizing, and polished letter spacing using default system fonts.
     - `app_button.dart`: Reusable `AppButton` with primary, secondary, and danger variants, refined gradient fill, rounded shape (16px), soft shadow, press scale animation (<120ms), disabled state, loading spinner, light haptic feedback (`HapticFeedback.lightImpact()`), and 500ms double-tap debounce.
     - `app_back_button.dart`: Round glassmorphic back button (42×42) with press scale animation (<120ms) and light haptics.
     - `app_card.dart`: Reusable card with 20px rounded corners, customizable gradient fill, soft layered glow shadow, and press scale animation (<120ms).
     - `app_dialog.dart`: Standalone styled modal dialog frame helper for future steps (not applied to any existing game dialogs).
     - `app_transitions.dart`: Short, smooth custom page transition (`AppPageRoute` / `appPageRoute`) combining gentle slide (0.05 offset) and fade over 250ms with ease-out cubic curve.
   - **Home Screen Redesign (`lib/screens/home_screen.dart`)**:
     - Complete redesign featuring `_HomeScreenHeader` with collection badge, refined app title, subtitle, and `LayoutBuilder` responsive padding.
     - 4 elegant game cards (`home_ludo_card`, `home_snl_card`, `home_carrom_card`, `home_battleship_card`) built with `AppCard`, custom gradients, glowing icons, category tags, taglines, and tactile press animations.
     - Uses `appPageRoute` for smooth navigation transitions.
     - 100% backward compatible: preserves every existing navigation target, key, and behavior.
   - **Mode-Selection Screens Visual Styling (Visual Polish Only)**:
     - Styled `LudoModeSelectScreen`, `CarromModeSelectScreen`, and `BattleshipModeSelectScreen` using `AppPalette.backgroundGradient`, `AppBackButton`, `AppCard`, `AppTextStyles`, and `appPageRoute`.
     - Preserved every existing callback, parameter, mode constructor, and test key (`ludo_mode_back_button`, `ludo_mode_multiplayer`, `ludo_mode_vs_computer`, `carrom_mode_back_button`, `carrom_mode_2players`, `carrom_mode_vs_computer`, `battleship_mode_back_button`, `battleship_mode_multiplayer`, `battleship_mode_vs_computer`).
   - **Zero Disruptions to Game Work**:
     - No game screen, game widget, controller, model, game rules, physics, scoring, turn logic, or computer player code was touched.
     - No external packages or image assets added.
   - **Tests Added**:
     - `test/app_button_test.dart`: Tests tap execution, disabled prevention, double-tap debounce safety, loading state, and variant styling.
     - `test/home_screen_test.dart`: Tests 4 game cards and zero layout overflow across 360×640 (compact), 390×844 (standard), and 412×923 (tall) viewports, plus larger 1.4x accessibility text scaling.

2. **Classic Battleship Implementation (`lib/battleship/`)**:
   - Built a complete, naval radar-themed Battleship game entirely in an isolated `lib/battleship/` directory.
   - **Zero modifications or disruptions** to existing Ludo, Snakes & Ladders, or Carrom code, rules, UI, assets, or tests.
   - **Pure Dart Game Logic**:
     - Complete decoupling: `battleship_config.dart`, `battleship_models.dart`, `battleship_board.dart`, `battleship_computer_player.dart`, `battleship_controller.dart` contain zero Flutter imports.
     - Fleet sizes (Carrier 5, Battleship 4, Cruiser 3, Submarine 3, Destroyer 2) and delays (700ms CPU shot delay) in `battleship_config.dart`.
     - Strict placement rules: 10×10 grid, horizontal/vertical only, bounds validation, overlap prevention.
     - Placement controls: cell tap placement, orientation rotation (H/V), whole-fleet random placement, and reset.
     - Battle firing: alternate firing, single-shot per cell, HIT/MISS feedback, ship sunk notification with ship name.
     - Duel view: Target Radar (firing grid showing hits/misses) and Own Fleet (defense grid showing friendly ships and incoming damage).
   - **Multiplayer Mode (One Phone)**:
     - Full-screen `BattleshipPassPhoneOverlay` ("Pass the phone to Player X. Tap when ready") shielding all ship information between placements and between turns.
     - Complete fog of war: neither player can inspect opponent ship locations.
   - **vs Computer Mode (Fair Play CPU)**:
     - Player 1 = Human, Player 2 = Computer ("CPU").
     - Guaranteed fair play: CPU never inspects human ship coordinates or board.
     - Checkerboard parity hunting `(row + col) % 2 == 0`, adjacent orthogonal targeting after hit, line axis continuation until ship is sunk.
     - Deterministic seeded random source for reproducible tests.
     - 700ms realistic shot delay in config file.
   - **Input Reliability & Lifecycle**:
     - Complete input locking during CPU thinking, processing, and on already-fired cells.
     - Timers safely cancelled on screen disposal, restart, or game over.
   - **UI & Aesthetics**:
     - Naval radar dark-mode aesthetic (`battleship_colors.dart`).
     - Reuses shared `WinnerBanner` from `lib/widgets/winner_banner.dart` without modifying it.
     - Back button (`Icons.arrow_back_ios_new_rounded`) matching existing games.
     - Responsive layout with `SafeArea` and `LayoutBuilder`: verified on 360×640, 390×844, and 412×923 with zero overflows.
   - **Test Results**: 38 new unit and widget tests added. Total tests: **195 (↑ from 157), all passing**, `flutter analyze` 0 issues.

2. **Winner Banner UI (`lib/widgets/winner_banner.dart`, `test/winner_banner_test.dart`)**: Added a shared animated "WINNER!" overlay widget (fade + elastic scale, ~900 ms, `IgnorePointer` so buttons stay tappable). Integrated into Ludo's `GameOverDialog`, SnL's win dialog, and Carrom's game screen with minimal, isolated insertions — no game logic, rules, physics, or existing tests were changed. Total tests: **101 (↑ from 98), all pass**.
3. **Classic Carrom Implementation (`lib/carrom/`)**:
   - Built a complete, clean, mobile-first 2-player local Carrom game entirely in an isolated `lib/carrom/` directory.
   - **Zero modifications or disruptions** to existing Ludo or Snakes & Ladders game code, models, widgets, rules, or tests.
   - **Board and Coins**:
     - 800×800 square virtual coordinate board with 4 corner pockets, outer mahogany frame, baseline for each player, and center circle.
     - 19 coins in standard dense packing: 9 White coins, 9 Black coins, and 1 Red Queen in the center.
     - Player 1 = White (bottom baseline), Player 2 = Black (top baseline).
   - **Shooting Controls**:
     - Current player slides striker along their baseline. Striker cannot overlap active coins or leave legal bounds.
     - Slingshot pull-back aiming gesture with dotted trajectory line, arrowhead, and power arc indicator.
     - Maximum shot power is clamped to prevent physics tunneling or erratic bounces.
   - **Custom 2D Physics Engine (Pure Dart, No External Physics Packages)**:
     - Elastic circle-to-circle collisions with momentum transfer.
     - Border wall bounces with restitution loss.
     - Linear friction and viscous drag for natural deceleration and clean stopping.
     - Pocket detection marking pieces as pocketed when falling within corner pocket radii.
     - Fixed 240Hz sub-stepping preventing tunneling through walls or pieces.
     - 6.0-second safety timeout ensuring the motion phase ends deterministically.
     - Centralized physics configuration in `CarromConfig`.
   - **Rules & Game Logic**:
     - Pocketing own coin awards an extra shot.
     - Pocketing opponent coin scores for opponent and ends the turn.
     - Striker pocketed = Foul: 1 previously pocketed coin is returned to center and turn ends.
     - Queen rules: Pocketing Queen requires covering it with an own coin on the same shot or the very next shot; otherwise Queen returns to the center.
     - Nearest free spot radial search for returned coins when center is occupied.
     - Win condition: First player to pocket all 9 coins of their color and cover the Queen wins.
   - **Reliability & Input Protection**:
     - All user touch gestures are completely locked while pieces are in motion (`simulating` phase).
     - State machine transitions deterministically after all pieces reach a complete stop.

2. **Home Screen Update (`lib/screens/home_screen.dart`)**:
   - Added a third "Carrom" game option card alongside Ludo and Snakes & Ladders.
   - Wrapped cards in `SingleChildScrollView` with responsive spacing to ensure zero overflow on compact screens.

3. **Responsive Mobile Layout**:
   - Implemented portrait layout with `SafeArea` and `LayoutBuilder`.
   - Dynamic board scaling: `boardSize = math.min(usableWidth, maxBoardFromHeight).clamp(220.0, usableWidth)`.
   - Tested and verified on **360×640**, **390×844**, **412×923**, and **430×932** viewports with **zero RenderFlex overflows**.

---

## Files Created & Updated

| File | Status | Purpose |
|------|--------|---------|
| [lib/carrom/carrom_vec2.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_vec2.dart) | New | Pure Dart 2D vector mathematics with zero external imports |
| [lib/carrom/carrom_config.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_config.dart) | New | Centralized physics parameters, radii, restitution, velocities, board dimensions |
| [lib/carrom/carrom_models.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_models.dart) | New | Pure Dart models: `CarromCoin`, `CarromPlayer`, `CarromTurnPhase`, `QueenStatus` |
| [lib/carrom/carrom_board_layout.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_board_layout.dart) | New | Standard 19-coin circular setup, baseline constraints, nearest free center search |
| [lib/carrom/carrom_physics.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_physics.dart) | New | Pure Dart 2D momentum physics, sub-stepping, wall bounces, friction, pockets |
| [lib/carrom/carrom_game_state.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_game_state.dart) | New | Immutable Carrom snapshot state and copyWith methods |
| [lib/carrom/carrom_controller.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_controller.dart) | New | Pure Dart controller: turns, fouls, queen cover, simulation ticks, input lock |
| [lib/carrom/carrom_colors.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_colors.dart) | New | Standalone board palette: mahogany frame, birch veneer, ivory/ebony coins, ruby queen |
| [lib/carrom/carrom_board_painter.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_board_painter.dart) | New | CustomPainter rendering board markings, pockets, realistic shaded coins, aim line |
| [lib/carrom/carrom_player_card.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_player_card.dart) | New | Compact player status card with score, queen indicator, active turn glow |
| [lib/carrom/carrom_board_widget.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_board_widget.dart) | New | Touch gesture recognition and virtual coordinate conversion for striker & aiming |
| [lib/carrom/carrom_game_screen.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_game_screen.dart) | New | Responsive portrait screen with ticker, striker slider, rules dialog, reset dialog |
| [lib/screens/home_screen.dart](file:///d:/Flutter%20Projects/Board%20Game/lib/screens/home_screen.dart) | Updated | Added third Carrom card and scrollable cards container |
| [test/carrom_controller_test.dart](file:///d:/Flutter%20Projects/Board%20Game/test/carrom_controller_test.dart) | New | 26 unit tests verifying layout, physics, momentum, walls, friction, fouls, queen, rules |
| [test/carrom_widget_test.dart](file:///d:/Flutter%20Projects/Board%20Game/test/carrom_widget_test.dart) | New | 10 widget tests for 360×640, 390×844, 412×923, 430×932, slider, dialogs, home launch |
| [README.md](file:///d:/Flutter%20Projects/Board%20Game/README.md) | Updated | Updated documentation with Carrom features, architecture, 98 tests, limitations |
| [CHANGE_REPORT.md](file:///d:/Flutter%20Projects/Board%20Game/CHANGE_REPORT.md) | Updated | Full report with file manifest, rules, and complete 98-test inventory |

---

## Quality & Test Status
- **`flutter analyze`**: **0 issues found** (clean).
- **`flutter test`**: **98 tests passed out of 98 (100% pass rate)**.
  - **27 Classic Ludo tests** (100% untouched and passing).
  - **35 Snakes & Ladders tests** (100% untouched and passing).
  - **36 Classic Carrom tests** (100% passing).

| # | File | Group | Test Name |
|---|------|-------|-----------|
| 1 | ludo_controller_test.dart | Player Modes | Initializes 2-player game with Red & Yellow (opposites) |
| 2 | ludo_controller_test.dart | Player Modes | Initializes 3-player game with Red, Green & Yellow |
| 3 | ludo_controller_test.dart | Player Modes | Initializes 4-player game with all 4 colors in clockwise order |
| 4 | ludo_controller_test.dart | Dice & Base Movement | Roll of 1..5 with all tokens in base results in turn skip |
| 5 | ludo_controller_test.dart | Dice & Base Movement | Roll of 6 brings a token out to start cell (step 0) and grants extra turn |
| 6 | ludo_controller_test.dart | Dice & Base Movement | Three consecutive sixes forfeits the turn |
| 7 | ludo_controller_test.dart | Movement, Captures & Safe Cells | Token moves forward exact number of steps and passes turn |
| 8 | ludo_controller_test.dart | Movement, Captures & Safe Cells | Capturing opponent token on non-safe cell sends it to base and awards bonus turn |
| 9 | ludo_controller_test.dart | Movement, Captures & Safe Cells | Safe cell prevents capture |
| 10 | ludo_controller_test.dart | Home Entry & Winning | Exact roll required to reach HOME (step 56) |
| 11 | ludo_controller_test.dart | Home Entry & Winning | Reaching home with all 4 tokens triggers victory and game won |
| 12 | ludo_controller_test.dart | Input Protection & Reliability | Cannot roll dice when not in waitingForRoll phase |
| 13 | ludo_controller_test.dart | Input Protection & Reliability | Cannot select opponent tokens or invalid tokens |
| 14 | ludo_controller_test.dart | Input Protection & Reliability | Rapid double taps on movable token only execute once |
| 15 | models_and_path_test.dart | BoardPath & Coordinate Tests | Common track has exactly 52 valid coordinates |
| 16 | models_and_path_test.dart | BoardPath & Coordinate Tests | Start indices are correctly spaced by 13 cells |
| 17 | models_and_path_test.dart | BoardPath & Coordinate Tests | Start coordinates match standard Ludo positions |
| 18 | models_and_path_test.dart | BoardPath & Coordinate Tests | Safe cells include all 4 starts and 4 stars |
| 19 | models_and_path_test.dart | BoardPath & Coordinate Tests | Home stretch and Home goal coordinates |
| 20 | models_and_path_test.dart | Token & Player Models | Token initial state and states transitions |
| 21 | models_and_path_test.dart | Token & Player Models | Player initializes with 4 tokens in base |
| 22 | snl_controller_test.dart | SnlConfig - Board Configuration | Has exactly 8 snakes and 8 ladders |
| 23 | snl_controller_test.dart | SnlConfig - Board Configuration | No snake or ladder endpoint is cell 1 or 100 |
| 24 | snl_controller_test.dart | SnlConfig - Board Configuration | Snake heads > snake tails (snake goes down) |
| 25 | snl_controller_test.dart | SnlConfig - Board Configuration | Ladder bottoms < ladder tops (ladder goes up) |
| 26 | snl_controller_test.dart | SnlConfig - Board Configuration | No ladder top coincides with a snake head |
| 27 | snl_controller_test.dart | SnlConfig - Board Configuration | No overlap between snake heads and ladder bottoms |
| 28 | snl_controller_test.dart | SnlController - Player Modes & Identity Consistency | Initializes 2-player game with Red and Yellow |
| 29 | snl_controller_test.dart | SnlController - Player Modes & Identity Consistency | Initializes 3-player game with Red, Green, Yellow |
| 30 | snl_controller_test.dart | SnlController - Player Modes & Identity Consistency | Initializes 4-player game with all 4 colors |
| 31 | snl_controller_test.dart | SnlController - Player Modes & Identity Consistency | All players start at position 0 (off-board) |
| 32 | snl_controller_test.dart | SnlController - Player Modes & Identity Consistency | Player name and color match consistently for 2P, 3P, and 4P |
| 33 | snl_controller_test.dart | SnlController - Exactly One Roll Per Turn & Sequential Switching | Roll advances player position by rolled amount and passes turn |
| 34 | snl_controller_test.dart | SnlController - Exactly One Roll Per Turn & Sequential Switching | Rolling 6 moves token and passes turn to next player (no extra turn) |
| 35 | snl_controller_test.dart | SnlController - Exactly One Roll Per Turn & Sequential Switching | Every rolled value 1 to 6 gives exactly one roll and passes turn |
| 36 | snl_controller_test.dart | SnlController - Exactly One Roll Per Turn & Sequential Switching | Deterministic sequential turn order across full rounds in 4-player game |
| 37 | snl_controller_test.dart | SnlController - Exactly One Roll Per Turn & Sequential Switching | Overshooting 100 leaves token in place and passes turn |
| 38 | snl_controller_test.dart | SnlController - Exactly One Roll Per Turn & Sequential Switching | Exact roll to reach 100 wins the game |
| 39 | snl_controller_test.dart | SnlController - Snakes & Ladders Movement | Landing on a snake head sends token to snake tail and passes turn |
| 40 | snl_controller_test.dart | SnlController - Snakes & Ladders Movement | Landing on a ladder bottom climbs to ladder top and passes turn |
| 41 | snl_controller_test.dart | SnlController - Snakes & Ladders Movement | Landing on a snake on roll of 6 advances turn to next player |
| 42 | snl_controller_test.dart | SnlController - Snakes & Ladders Movement | Landing on a ladder on roll of 6 advances turn to next player |
| 43 | snl_controller_test.dart | SnlController - Input Protection & Reliability | Cannot roll when not in waitingForRoll phase |
| 44 | snl_controller_test.dart | SnlController - Input Protection & Reliability | Rapid double roll is ignored while first roll is processing |
| 45 | snl_widget_test.dart | SnlWidget Tests - Responsive Layout | Renders correctly on standard phone (390×844) |
| 46 | snl_widget_test.dart | SnlWidget Tests - Responsive Layout | Renders correctly on compact phone (360×640) |
| 47 | snl_widget_test.dart | SnlWidget Tests - Responsive Layout | Renders correctly on modern large phone (412×923) |
| 48 | snl_widget_test.dart | SnlWidget Tests - Responsive Layout | Renders correctly on extra-large phone (430×932) |
| 49 | snl_widget_test.dart | SnlWidget Tests - Player Cards & Color Consistency | Shows correct number of player cards for 2P game |
| 50 | snl_widget_test.dart | SnlWidget Tests - Player Cards & Color Consistency | Player card for Yellow uses yellow color and not green in 2P game |
| 51 | snl_widget_test.dart | SnlWidget Tests - Player Cards & Color Consistency | Shows correct number of player cards for 3P game |
| 52 | snl_widget_test.dart | SnlWidget Tests - Player Cards & Color Consistency | Shows correct number of player cards for 4P game |
| 53 | snl_widget_test.dart | SnlWidget Tests - Interactions | Roll button is enabled on start and triggers state change |
| 54 | snl_widget_test.dart | SnlWidget Tests - Interactions | Rapid taps on roll button do not crash or duplicate roll |
| 55 | snl_widget_test.dart | SnlWidget Tests - Interactions | Player mode dialog can switch between 2P, 3P, 4P |
| 56 | snl_widget_test.dart | SnlWidget Tests - Interactions | Input during animation is blocked (roll button disabled) |
| 57 | widget_test.dart | Widget Tests - Responsive Layout & UI Elements | Renders properly on standard phone (390×844) |
| 58 | widget_test.dart | Widget Tests - Responsive Layout & UI Elements | Renders properly on compact phone (360×640) |
| 59 | widget_test.dart | Widget Tests - Responsive Layout & UI Elements | Renders properly on large phone (430×932) |
| 60 | widget_test.dart | Widget Tests - User Interactions & Dialogs | Can open and close Rules dialog |
| 61 | widget_test.dart | Widget Tests - User Interactions & Dialogs | Can change player count via mode dialog |
| 62 | widget_test.dart | Widget Tests - User Interactions & Dialogs | Dice roll button triggers roll and locks against rapid taps |
| 63 | carrom_controller_test.dart | Board Configuration & Layout Setup | Initializes exactly 19 coins (9 White, 9 Black, 1 Red Queen) |
| 64 | carrom_controller_test.dart | Board Configuration & Layout Setup | Red Queen is positioned at the exact center (400, 400) |
| 65 | carrom_controller_test.dart | Board Configuration & Layout Setup | Baseline Y values are correctly assigned for Player 1 and Player 2 |
| 66 | carrom_controller_test.dart | Board Configuration & Layout Setup | Nearest free spot returns center if unoccupied |
| 67 | carrom_controller_test.dart | Board Configuration & Layout Setup | Nearest free spot returns adjacent non-overlapping spot if center is occupied |
| 68 | carrom_controller_test.dart | Physics Engine | Momentum transfer: Striker hitting stationary coin accelerates the coin |
| 69 | carrom_controller_test.dart | Physics Engine | Wall bounce reflects velocity with restitution loss |
| 70 | carrom_controller_test.dart | Physics Engine | Friction decelerates moving coins to rest |
| 71 | carrom_controller_test.dart | Physics Engine | Velocity cap prevents tunneling |
| 72 | carrom_controller_test.dart | Physics Engine | Pocket detection marks coin as pocketed when entering corner pocket |
| 73 | carrom_controller_test.dart | Striker Positioning & Aiming Controls | Striker slides along current player baseline within legal bounds |
| 74 | carrom_controller_test.dart | Striker Positioning & Aiming Controls | Striker cannot be placed overlapping an active coin |
| 75 | carrom_controller_test.dart | Striker Positioning & Aiming Controls | Aim drag sets aim vector and power ratio |
| 76 | carrom_controller_test.dart | Striker Positioning & Aiming Controls | Release shot transfers velocity and enters simulating phase |
| 77 | carrom_controller_test.dart | Striker Positioning & Aiming Controls | Tiny drag cancels aim without shooting |
| 78 | carrom_controller_test.dart | Rules & Turn Resolution | Pocketing own coin awards extra turn to same player |
| 79 | carrom_controller_test.dart | Rules & Turn Resolution | No coin pocketed passes turn deterministically to opponent |
| 80 | carrom_controller_test.dart | Rules & Turn Resolution | Pocketing opponent coin scores for opponent and ends turn |
| 81 | carrom_controller_test.dart | Rules & Turn Resolution | Striker pocketed is a foul: penalty coin returned to center, turn ends |
| 82 | carrom_controller_test.dart | Rules & Turn Resolution | Foul with 0 pocketed coins ends turn without negative score |
| 83 | carrom_controller_test.dart | Rules & Turn Resolution | Queen pocketed alone enters pendingCover status and awards extra shot |
| 84 | carrom_controller_test.dart | Rules & Turn Resolution | Failing to cover Queen on next shot returns Queen to center |
| 85 | carrom_controller_test.dart | Rules & Turn Resolution | Pocketing own coin covers pending Queen successfully |
| 86 | carrom_controller_test.dart | Rules & Turn Resolution | Winning condition: Pocketing all 9 coins and covering Queen wins |
| 87 | carrom_controller_test.dart | Input Protection & Reliability | Input is blocked during simulation phase |
| 88 | carrom_controller_test.dart | Input Protection & Reliability | Motion phase completes after maximum simulation time (6.0s) |
| 89 | carrom_widget_test.dart | Responsive Layout & Viewports | Renders cleanly on standard phone (390×844) with no overflow |
| 90 | carrom_widget_test.dart | Responsive Layout & Viewports | Renders cleanly on compact phone (360×640) with no overflow |
| 91 | carrom_widget_test.dart | Responsive Layout & Viewports | Renders cleanly on modern tall phone (412×923) with no overflow |
| 92 | carrom_widget_test.dart | Responsive Layout & Viewports | Renders cleanly on extra-large phone (430×932) with no overflow |
| 93 | carrom_widget_test.dart | UI Elements, Controls & Dialogs | Shows Player 1 (White) and Player 2 (Black) cards with initial score |
| 94 | carrom_widget_test.dart | UI Elements, Controls & Dialogs | Can open and close Carrom rules dialog cleanly |
| 95 | carrom_widget_test.dart | UI Elements, Controls & Dialogs | Can open and interact with reset dialog |
| 96 | carrom_widget_test.dart | UI Elements, Controls & Dialogs | Striker slider updates striker position |
| 97 | carrom_widget_test.dart | UI Elements, Controls & Dialogs | Input is locked when controller is in simulating phase |
| 98 | carrom_widget_test.dart | Home Screen Navigation | Home screen displays Carrom option card and navigates to CarromGameScreen |

---

## Known Limitations
- **Not tested on a real device**: Testing executed exclusively on the Flutter test environment and Windows desktop runner. Physical Android and iOS device behaviour has not been verified.
- **No sound or haptic feedback**: Audio effects, background audio, and vibration are not implemented.
- **No save / resume**: Matches are held in memory only and reset upon app termination or back navigation.
- **AI in Ludo only**: The CPU player is available for 2-player Ludo ("vs Computer" mode). Snakes & Ladders and Carrom remain pass-and-play only.
- **No online multiplayer**: Strictly local single-device play.
- **No finish-rank tracking**: In Ludo and Snakes & Ladders, only the first-place winner is recognized; remaining positions are not computed.
- **No blockade rule in Ludo**: Stacking pieces does not form an impassable barricade for opponents.
- **Host SDK verification**: `flutter analyze` was verified on the host machine's Flutter/Dart SDK.

---

## Change Entry: Ludo "vs Computer" Mode

### Summary
Added an optional "vs Computer" mode to **Ludo only**. Snakes & Ladders and Carrom are completely untouched. Existing Ludo rules, mechanics, board, tokens, dice, animations, and multiplayer pass-and-play remain identical.

### Key Additions & Design
- **Mode Selection (`lib/screens/ludo_mode_select_screen.dart`)**:
  - Pushed after tapping Ludo on the home screen.
  - Presents two choices: "Multiplayer (Friends)" (the existing game and player dialog, unchanged) and "vs Computer".
  - Back arrow navigates back cleanly to Home Screen.
- **Dedicated vs Computer Layout & Shared Centered Dice**:
  - In vs Computer mode ONLY: The dice is horizontally centered in the bottom controls console, shared between Player 1 (Red human) and Player 2 (Yellow computer).
  - Multiplayer mode keeps its original corner dice position and layout completely intact.
  - Safe, responsive, and overflow-free across 360×640, 390×844, and 412×923 viewports.
- **Computer Player Logic (`lib/logic/ludo_computer_player.dart`)**:
  - Pure Dart AI acting strictly through `LudoController` methods (`rollDice`, `selectToken`).
  - Fair dice randomness: no cheating, no predicting rolls.
  - 600ms delay between actions.
  - Heuristic token selection: 1) move into HOME, 2) capture opponent, 3) bring token out with 6, 4) move to safe cell / out of danger, 5) advance furthest token.
  - Single legal token auto-moves for both human and CPU; 2+ tokens wait for manual tap choice for human.
  - Cancelable timers on screen dispose, game restart, or game over to guarantee no stale timers.
- **UI Indicators**:
  - Computer card is marked with "CPU" badge.
  - A small "Computer's Turn" indicator message appears next to the CPU card and in the status console while the computer plays.
  - All human taps on the board tokens and dice are blocked during the computer's turn.

### Files Changed

| File | Status | Reason |
|------|--------|--------|
| [`lib/screens/ludo_mode_select_screen.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/screens/ludo_mode_select_screen.dart) | **New** | Mode selection screen offering "Multiplayer (Friends)" and "vs Computer" |
| [`lib/logic/ludo_computer_player.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/logic/ludo_computer_player.dart) | **Updated** | Computer player pure Dart logic with cancelable timer and priority heuristic |
| [`lib/screens/ludo_game_screen.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/screens/ludo_game_screen.dart) | **Updated** | Top bar back button, "Computer's Turn" indicator, centered dice for vs Computer mode |
| [`lib/screens/home_screen.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/screens/home_screen.dart) | **Updated** | Tapping Ludo opens `LudoModeSelectScreen` |
| [`test/ludo_widget_test.dart`](file:///d:/Flutter%20Projects/Board%20Game/test/ludo_widget_test.dart) | **New** | 13 widget tests (mode select navigation, centered dice, CPU turn blocking, auto-move, 3 screen sizes) |
| [`test/ludo_computer_player_test.dart`](file:///d:/Flutter%20Projects/Board%20Game/test/ludo_computer_player_test.dart) | **Maintained** | Unit tests for turn automation, bonus turns, cancellation, and full game to completion |
| [`README.md`](file:///d:/Flutter%20Projects/Board%20Game/README.md) | **Updated** | Documentation updated with Ludo vs Computer mode and centered dice |
| [`CHANGE_REPORT.md`](file:///d:/Flutter%20Projects/Board%20Game/CHANGE_REPORT.md) | **Updated** | This document |

### Quality & Verification
- **`flutter analyze`**: **0 issues found** (clean).
- **`flutter test`**: **146 tests passed out of 146 (100% pass rate)**.
  - Classic Ludo logic & widget tests: passing.
  - Ludo vs Computer tests: passing.
  - Snakes & Ladders tests: untouched and passing.
  - Classic Carrom tests: untouched and passing.

---

## Change Entry: Carrom Rules Update (Coin Ownership, Points Scoring, Queen Cover & Winner Calculation)

### Summary
Updated ONLY Carrom game rules to implement colour-independent coin ownership, point-based scoring, universal queen cover, and empty-board final score winner determination.
**Zero modifications to Ludo or Snakes & Ladders**. Carrom physics, geometry, momentum, friction, collisions, striker positioning, aiming, animations, and responsive UI were 100% preserved.

### Carrom Rules Implemented
1. **Colour is NOT Player Ownership**:
   - Removed the restriction that players can only pocket their assigned colour.
   - Either player can pocket ANY remaining black or white coin.
   - The player who legally pockets a coin receives that coin's configured point value.
2. **Points-Based Scoring**:
   - Black coin = **10 points**
   - White coin = **20 points**
   - Queen = **50 points** (awarded when covered)
   - Winner is determined strictly by **total points**, not by number of coins pocketed or original colour.
   - A player with fewer coins can win with a higher total score (e.g., 3 white coins + Queen = 110 pts beats 10 black coins = 100 pts).
3. **Queen & Universal Cover**:
   - Queen may be pocketed by either player.
   - Cover may be **ANY valid coin (Black or White)**.
   - Existing cover requirement, failed cover return to center, and foul return logic remain fully intact.
4. **No Premature End on Colour Clearance**:
   - Clearing all 9 coins of an original baseline colour does NOT end the game while valid coins remain on the board.
   - Both players continue having chances until the board reaches its normal final board/end condition (all coins pocketed / empty board).
5. **Final Winner Calculation**:
   - When the board is empty, both players' total scores are calculated.
   - Highest total score wins; lower score loses.
   - Equal total score resolves as a Draw (preserving existing tie handling).
6. **Turns, Fouls & Computer Mode Compatibility**:
   - Pocketing any valid coin grants an extra shot. No coin pocketed passes the turn to the opponent.
   - Foul (striker pocketed) returns 1 previously pocketed coin to center as a penalty (Black coin first if available, else White coin) and turn passes to opponent.
   - `CarromComputerPlayer` targets any active non-striker coin on the board using the exact same rules and controls, receiving no unfair advantage.

### Files Changed

| File | Status | What Changed |
|------|--------|--------------|
| [`lib/carrom/carrom_config.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_config.dart) | **Updated** | Added centralized point constants: `blackCoinPoints = 10`, `whiteCoinPoints = 20`, `queenPoints = 50`. |
| [`lib/carrom/carrom_models.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_models.dart) | **Updated** | Added `whiteCoinsPocketed` and `blackCoinsPocketed` to `CarromPlayer`, added `score` getter computing total points, and preserved `pocketedCount` compatibility. |
| [`lib/carrom/carrom_controller.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_controller.dart) | **Updated** | Updated `_resolveShotOutcome()` to award pocketed coins/points to the shooter regardless of colour, allow any coin to cover queen, continue play while coins remain on board, calculate final winner by highest score on empty board, and maintain board invariants. |
| [`lib/carrom/carrom_computer_player.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_computer_player.dart) | **Updated** | Allowed CPU to target any remaining valid coin on the board (black, white, or queen) under the same colour-independent rules. |
| [`lib/carrom/carrom_player_card.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_player_card.dart) | **Updated** | Updated score display to show `Score: ${player.score} pts (${player.pocketedCount} coins)`. |
| [`lib/carrom/carrom_game_screen.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/carrom/carrom_game_screen.dart) | **Updated** | Updated Carrom Rules dialog bullets to explain points scoring, universal queen cover, and empty-board win condition. |
| [`test/carrom_controller_test.dart`](file:///d:/Flutter%20Projects/Board%20Game/test/carrom_controller_test.dart) | **Updated** | Added and updated focused tests: pocketing black/white regardless of assigned colour, point crediting, queen cover with black/white, continuing play when original colour finished, and win with fewer coins. Total: 39 tests. |
| [`test/carrom_computer_player_test.dart`](file:///d:/Flutter%20Projects/Board%20Game/test/carrom_computer_player_test.dart) | **Updated** | Updated seeded full-game test state for score-based resolution. Total: 12 tests. |
| [`test/carrom_widget_test.dart`](file:///d:/Flutter%20Projects/Board%20Game/test/carrom_widget_test.dart) | **Updated** | Updated card score expectation to `Score: 0 pts`. Total: 14 tests. |
| [`README.md`](file:///d:/Flutter%20Projects/Board%20Game/README.md) | **Updated** | Updated blueprint with complete documentation of the new rules, scoring, and test counts. |
| [`CHANGE_REPORT.md`](file:///d:/Flutter%20Projects/Board%20Game/CHANGE_REPORT.md) | **Updated** | This document. |

### Quality & Verification
- **`flutter analyze`**: **0 issues found** (clean).
- **`flutter test`**: **152 tests passed out of 152 (100% pass rate)**.
  - Ludo tests: 100% untouched and passing.
  - Snakes & Ladders tests: 100% untouched and passing.
  - Carrom tests: 65 tests (39 controller + 12 computer player + 14 widget tests) 100% passing.

---

## Change Entry: Pen Fight Game Implementation (5th Game in Suite)

### Summary
Added **Pen Fight** as the 5th game in the suite, completely isolated in `lib/pen_fight/`.
**Highest Priority Protection Upheld**:
- **Zero changes** to Ludo, Snakes & Ladders, Carrom, or Battleship (code, rules, physics, AI, navigation, UI, assets, or existing tests).
- All existing game tests pass completely and unchanged.
- No new external packages added to `pubspec.yaml`.
- The only pre-existing files modified were `lib/screens/home_screen.dart` (added 5th Pen Fight card and wrapped title in `Flexible` to eliminate horizontal RenderFlex overflow on small viewports), `README.md`, `CHANGE_REPORT.md`, and `test/home_screen_test.dart` (updated card expectation to 5 cards since it directly depends on Home Screen structure).

### Pen Fight Feature Specifications
1. **Home Screen**:
   - Added 5th "Pen Fight" card (`key: home_pen_fight_card`) with pen emoji (`🖊️`), category badge `TABLETOP`, tagline `2 players · Best of 3 rounds\nAim, flick & knock opponent off`, vivid violet accent color (`#8B5CF6`), and gradient `[#581C87, #7C3AED]`.
   - Layout scrolls smoothly in `SingleChildScrollView` with zero overflow across 360×640, 390×844, and 412×923 viewports.
2. **Mode Selection (`PenFightModeSelectScreen`)**:
   - Accessible from Home Screen card tap with back button (`pen_fight_mode_back_button`).
   - "Play with Friend" (`pen_fight_mode_2players`): 2 players, 1 device (pass-and-play).
   - "vs Computer" (`pen_fight_mode_vs_computer`): Player 1 (human) vs Player 2 (`CPU`).
3. **Tabletop & Physics Engine (`PenFightPhysics`, `PenFightConfig`)**:
   - Tabletop in virtual coordinates `400.0 × 600.0` with clear border and no walls.
   - Deterministic sub-stepped integration using fixed timestep (`1/60` s / 4 sub-steps).
   - Surface friction deceleration (`340.0 px/s²`) and viscous damping (`0.35`).
   - Elastic circle-to-circle momentum transfer collisions (`bounce = 0.82`).
   - Maximum speed capping (`1100.0 px/s`) preventing tunneling.
   - Off-table detection: pen is off table when its center passes any table edge (`x < 0 || x > 400 || y < 0 || y > 600`), triggering a short falling scale/fade animation.
   - All tuning numbers isolated in a single config file: `lib/pen_fight/pen_fight_config.dart`.
4. **Game Rules & Round Progression (`PenFightController`)**:
   - Drag backward from pen to aim and set flick power (capped at `powerCap = 1000.0`). Release to launch flick.
   - Turn passes only after all motion stops or max motion timeout (`3.5s`) is reached.
   - Round outcome rules:
     - Opponent pen falls off -> shooter wins the round.
     - Shooter's own pen falls off -> shooter loses the round.
     - Both pens fall off -> shooter loses the round.
   - Best of 3 rounds: first player to win 2 rounds wins the match.
   - Pens reset to initial positions between rounds.
5. **Computer Player AI (`PenFightComputerPlayer`)**:
   - Pure Dart AI using the exact same shot method as human players with zero hidden information.
   - Aims toward opponent pen, adds small random noise from seeded `Random` (`botError = 0.08` rad), calculates power from distance.
   - Edge proximity safety: reduces power when its own pen is near table edge to prevent flying off.
   - Realistic timing: waits 800ms (`botDelay`), shows aim trajectory for 400ms (`botAimDisplayMs`), then releases flick.
6. **Reliability & Input Protection**:
   - All inputs locked during motion, during CPU turns, between rounds, and after match end.
   - Only active shooter can drag; double-taps and duplicate drags ignored.
   - Timers and tickers cleanly disposed on screen exit, match restart, or game over.
7. **UI Components & Aesthetics**:
   - Reuses shared `WinnerBanner` from `lib/widgets/winner_banner.dart` without modifying it.
   - Reuses `AppButton`, `AppBackButton`, `AppCard`, and `AppDialog`.
   - Responsive layout verified on 360×640, 390×844, and 412×923 viewports.

### Files Created & Modified

| File | Status | Description |
|------|--------|-------------|
| [`lib/pen_fight/pen_fight_vec2.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_vec2.dart) | **New** | Pure Dart 2D vector mathematics with zero Flutter dependencies |
| [`lib/pen_fight/pen_fight_config.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_config.dart) | **New** | Centralized configuration holding all physics, dimensions, AI, and match tuning numbers |
| [`lib/pen_fight/pen_fight_models.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_models.dart) | **New** | Pure Dart models: `Pen`, `PenFightPlayerId`, `PenFightPhase`, `PenFightAim` |
| [`lib/pen_fight/pen_fight_physics.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_physics.dart) | **New** | Deterministic 2D physics engine: friction, bounce, momentum transfer, off-table detection |
| [`lib/pen_fight/pen_fight_computer_player.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_computer_player.dart) | **New** | Pure Dart fair CPU AI with seedable random, edge safety, and distance-scaled power |
| [`lib/pen_fight/pen_fight_controller.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_controller.dart) | **New** | Pure Dart state manager & rules engine: Best of 3, turn resolution, timeout, reset |
| [`lib/pen_fight/pen_fight_theme.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_theme.dart) | **New** | Isolated theme and palette: Vivid Violet accent, tabletop surfaces, P1/P2 pen colors |
| [`lib/pen_fight/pen_fight_painter.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_painter.dart) | **New** | CustomPainter rendering tabletop, clear border, pen graphics, falling effects, aim line & power arc |
| [`lib/pen_fight/pen_fight_board_widget.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_board_widget.dart) | **New** | Interactive tabletop widget with gesture recognition and coordinate mapping |
| [`lib/pen_fight/pen_fight_player_card.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_player_card.dart) | **New** | Responsive player status card with score, CPU badge, and active turn glow |
| [`lib/pen_fight/pen_fight_game_over_dialog.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_game_over_dialog.dart) | **New** | Victory dialog reusing shared `WinnerBanner`, Play Again button, and Home button |
| [`lib/pen_fight/pen_fight_mode_select_screen.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_mode_select_screen.dart) | **New** | Mode selection screen: "Play with Friend" and "vs Computer" |
| [`lib/pen_fight/pen_fight_game_screen.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/pen_fight/pen_fight_game_screen.dart) | **New** | Full game screen with responsive layout, ticker simulation loop, rules dialog, reset |
| [`lib/screens/home_screen.dart`](file:///d:/Flutter%20Projects/Board%20Game/lib/screens/home_screen.dart) | **Updated** | Added 5th Pen Fight card, updated suite count to 5, wrapped title in Flexible to prevent overflow |
| [`test/home_screen_test.dart`](file:///d:/Flutter%20Projects/Board%20Game/test/home_screen_test.dart) | **Updated** | Updated test to expect all 5 game cards across responsive viewports |
| [`test/pen_fight_logic_test.dart`](file:///d:/Flutter%20Projects/Board%20Game/test/pen_fight_logic_test.dart) | **New** | 13 unit tests for vector math, physics, collisions, off-table, rules, both-fall case, AI, full match |
| [`test/pen_fight_widget_test.dart`](file:///d:/Flutter%20Projects/Board%20Game/test/pen_fight_widget_test.dart) | **New** | 12 widget tests for navigation, mode launch, CPU badge, rules dialog, reset, input lock, viewports |
| [`README.md`](file:///d:/Flutter%20Projects/Board%20Game/README.md) | **Updated** | Updated documentation with Pen Fight feature description, test inventory, and suite specs |
| [`CHANGE_REPORT.md`](file:///d:/Flutter%20Projects/Board%20Game/CHANGE_REPORT.md) | **Updated** | This document |

### Quality & Verification (Initial Pen Fight)
- **`flutter analyze`**: **0 issues in project code** (only the 2 pre-existing baseline warnings in untouched `lib/ui/app_card.dart` and `test/app_button_test.dart` remain).
- **`flutter test`**: **229 tests passed out of 229 (100% pass rate)**.

---

## Pen Fight Upgrade: Realistic Physics, Pen Types, Fair Smart Bot & Balance Calibration

### 1. Realistic Rigid-Body Physics
- Replaced simplified circle collisions with capsule rigid bodies possessing mass, position, angle, velocity, angular velocity, and moment of inertia ($I = m \cdot (L^2 + W^2)/12$).
- Implemented segment-to-segment closest point distance detection with exact contact point derivation.
- Off-center hits generate torque ($\tau = r \times J$) causing natural rotation and spin; center hits produce negligible torque and slide straight. Hits near the end produce larger spin.
- Table edge balance: pen falls strictly when its center of mass passes the edge. Overhanging pens balance and pivot realistically due to asymmetric support friction torque.
- Sub-stepped impulse-based collision response with restitution ($e = 0.72$), tangential Coulomb friction ($\mu = 0.25$), and velocity/angular speed caps preventing tunneling.
- Turn passes only after both linear velocity and angular spin reach complete rest.

### 2. Fair Balance & Tuning
- Medium pull-back: max drag distance reduced to 77.0px (55% of original 140px).
- Gentle power curve exponent (1.25) provides fine control at low-to-medium drag, smoothly ramping to launch speed.
- Raised surface friction ($460.0$) and angular friction ($12.0$ rad/s$^2$) ensure realistic multi-turn matches where single-shot knockouts require accurate, strong hits.
- All numbers centralized in `pen_fight_config.dart`.

### 3. Pen Types (Stats Only)
- **Balanced**: Mass 1.0, length 72, width 14, power cap 600.
- **Heavy**: Mass 1.36, length 74, width 17, power cap 540 (thick, high mass, lower launch speed, barely moves when hit).
- **Slim**: Mass 0.76, length 70, width 11, power cap 680 (thin, low mass, high launch speed, pushed easily).
- Visual customization in `PenFightPainter`: distinct barrel thicknesses, clips, metallic bands, and nib shapes.
- Pre-match selection screen `PenFightPenSelectScreen`: turn-by-turn selection in Friend mode; seeded random CPU selection in vs Computer mode.

### 4. Fair, Smart Bot & Calibration
- Simulates candidate shots forward with physics engine using only publicly visible state.
- Generates 18 candidates: center shots, offset endpoint hits, edge-pushing angles, and safe repositioning shots when near table edges.
- Human-like fallibility: 15% mistake chance to select weaker/lower-tier shot, aim noise (~13.7°), and 18% power error.
- **Calibrated Win Rate**: Tested across 200 seeded matches of Bot vs Reference Player: **102 / 200 (51.0% win rate)**, meeting the 40–55% target.
- **Heavy vs Slim Balance**: Tested across 100 seeded matches: **40 / 100 (40.0% win rate)**, verifying neither side is favored beyond 60%.

### 5. Files Created & Modified
- Created: `lib/pen_fight/pen_fight_pen_select_screen.dart`
- Created: `test/pen_fight_calibration_test.dart`
- Modified: `lib/pen_fight/pen_fight_config.dart`
- Modified: `lib/pen_fight/pen_fight_models.dart`
- Modified: `lib/pen_fight/pen_fight_physics.dart`
- Modified: `lib/pen_fight/pen_fight_computer_player.dart`
- Modified: `lib/pen_fight/pen_fight_controller.dart`
- Modified: `lib/pen_fight/pen_fight_painter.dart`
- Modified: `lib/pen_fight/pen_fight_mode_select_screen.dart`
- Modified: `lib/pen_fight/pen_fight_game_screen.dart`
- Modified: `lib/pen_fight/pen_fight_player_card.dart`
- Modified: `test/pen_fight_logic_test.dart`
- Modified: `test/pen_fight_widget_test.dart`
- Modified: `README.md`
- Modified: `CHANGE_REPORT.md`

### 6. Zero Changes to Other Games
- **Ludo**: 100% untouched.
- **Snakes & Ladders**: 100% untouched.
- **Carrom**: 100% untouched.
- **Battleship**: 100% untouched.
- **Shared `lib/ui/`**: 100% untouched.
- **Test suite**: **239 tests passed out of 239 (100%)**. Zero regressions.

---

## Pen Fight Upgrade: Robust Capsule Collisions, 50% Shorter Drag, 3 Auto-Switching Tables & Hazard-Aware AI

### 1. Robust Capsule-vs-Capsule Collision Engine (Top Priority Bug Fix)
- **Resolved Pass-Through Bug**:
  - Replaced center-proximity hit detection with true segment-to-segment closest point geometry between the two pen capsules.
  - Derived exact contact normal ($\vec{n}$) and symmetric contact point $\vec{p}_c = (\vec{p}_1 + \vec{p}_2) / 2$.
  - Fixed painter coordinate misalignment: `PenFightPainter._drawPen` rotated canvas by `pen.angle - math.pi / 2`, aligning visual pen nib with the physics forward vector $( \cos\theta, \sin\theta )$.
  - Applied full impulse with angular torque ($\tau = \vec{r} \times \vec{J}$) at the contact point: tip hits and glancing blows visibly spin and deflect the pen, while center hits slide it straight.
  - Positional correction separates overlapping pens proportionally by penetration depth along the contact normal.
- **Tunneling Prevention**:
  - Sub-stepped physics integration (10 sub-steps per 60Hz tick) ensures neither pen moves more than half its thickness per sub-step.
  - Linear velocity capped at 850 px/s and angular velocity capped at 32 rad/s.

### 2. Shorter Pull-Back Drag Distance
- Reduced `maxDragDistance` by ~50% from 77.0px to **38.5px** in `PenFightConfig`.
- Maintained identical launch power curve and full power cap values.
- Shortened drawn aim/pull lines in `PenFightPainter` (scaled proportionally $28\text{px} + \text{fraction} \times 72\text{px}$) with responsive power meter arc.

### 3. Three Tables with Automatic Round Switching
- **Table 1: Classic (Round 1)**: Square tabletop (420×420) with all edges open; pen falls when center of mass passes any edge.
- **Table 2: Hole (Round 2)**: Square tabletop with open edges plus a central circular hazard hole ($R = 38.0$ px); pen falls if its center of mass enters the hole.
- **Table 3: Rails (Round 3)**: Square tabletop with raised solid wooden rails on outer borders (restitution $0.65$ with tangential damping), leaving ONE open corner gap ($80.0\text{ px}$) at top-right ($x \ge 340, y \le 80$) where pens can fall.
- `PenFightTableType` enum with `forRound(int round)`, auto-advancing across Best-of-3 rounds.
- Responsive round announcement banner (`_showTableIntro`) displaying table name and rules at the start of each round.

### 4. CustomPainter Table Design & UI Polish
- **Pure CustomPainter**:
  - Beveled outer wooden frame with multi-toned bevel gradients and brass corner studs.
  - Varnished wood/felt playing surface with subtle woodgrain texture lines and soft tabletop shadow.
  - 3D Hole with brass bevel ring, radial shadow depth gradient, and lip shadow.
  - Raised wooden bumper rails with golden corner brackets and diagonal hazard warning stripes at the open corner gap.
- **Polished Responsive UI**:
  - Player cards showing pen type badge, round score dots, and glowing active turn indicator.
  - Zero overflow verified across compact (360×640), standard (390×844), and tall (412×923) viewports.

### 5. Hazard-Aware Smart Bot & Seeded Calibration
- **Table & Hazard Intelligence**:
  - Generates candidate shots avoiding self-fall into the hole on Hole Table and gap on Rails Table.
  - Adds lateral flanking candidates around the center hole when hole is in line of sight.
  - Adds tactical ghost-contact candidates targeting the center hole and the open corner gap to eliminate opponents.
- **Seeded Calibration Win Rates (100 Matches Per Table)**:
  - **Classic Table**: **43 / 100 (43.0%)** (Target: 40–55%)
  - **Hole Table**: **51 / 100 (51.0%)** (Target: 40–55%)
  - **Rails Table**: **50 / 100 (50.0%)** (Target: 40–55%)

### 6. Files Modified & Created
- `lib/pen_fight/pen_fight_config.dart` (Square table, hole/rail configs, 38.5px drag, bot error tuning)
- `lib/pen_fight/pen_fight_models.dart` (`PenFightTableType` enum, round mapping)
- `lib/pen_fight/pen_fight_physics.dart` (Capsule-vs-capsule collision, impulse+torque, rails bounce, hole fall)
- `lib/pen_fight/pen_fight_painter.dart` (Table graphics, hole/rails rendering, 38.5px aim line, canvas rotation fix)
- `lib/pen_fight/pen_fight_controller.dart` (`currentTableType`, table-aware CPU shot)
- `lib/pen_fight/pen_fight_board_widget.dart` (Passes `tableType` to painter)
- `lib/pen_fight/pen_fight_game_screen.dart` (Table intro banner, subtitle display)
- `lib/pen_fight/pen_fight_computer_player.dart` (Hazard avoidance, hole flanking, gap targeting)
- `test/pen_fight_logic_test.dart` (Added 11 unit tests for new collision, multiple tables, hazards)
- `test/pen_fight_widget_test.dart` (Added responsive viewport tests for 3 tables & UI)
- `test/pen_fight_calibration_test.dart` (100 seeded matches per table)
- `README.md` (Updated specifications and test suite status)
- `CHANGE_REPORT.md` (This document)

### 7. Zero Changes to Other Games
- **Ludo**: 100% untouched.
- **Snakes & Ladders**: 100% untouched.
- **Carrom**: 100% untouched.
- **Battleship**: 100% untouched.
- **Shared `lib/ui/`**: 100% untouched.
- **Total Suite Tests**: **250 tests passed out of 250 (100% pass rate)**.



---

## Change Entry: Playful redesign, Connect Four, Would You Rather

### Look and feel ("game night sticker book")
- Built from the existing art: violet night palette, ink outlines, hard offset shadows, tilted sticker cards. Your Lilita One font is now the display face and Knewave is the wordmark; both were in `assets/fonts` but never registered.
- Tokens changed in place (`lib/ui/app_palette.dart`, `app_text_styles.dart`, `app_card.dart`, `app_button.dart`, `lib/theme/ludo_theme.dart`), so every screen that uses the shared UI layer picks the new look up. Game boards and game rules are untouched.
- New `lib/catalog/game_tile.dart` (`GameTile`, `GameGrid`) is used by Home and the Games tab. Home gets the banner hero, a "Play with friends" button and the grid.
- Card art: small WebP copies in `assets/images/small/` (about 160 KB total instead of about 24 MB). The full-size originals are untouched. Games without art get an emoji on a sunburst.
- Accessibility: back button now has a "Back" label, tiles and buttons have labels, button labels wrap instead of overflowing at large text, label colour follows the fill's brightness.

### New games (registered in `lib/catalog/game_catalog.dart`)
- Connect Four (board): `lib/connect4/`. Local 2-player or vs computer (wins, blocks, avoids handing over a win, likes the centre). Pure-Dart rules and AI.
- Would You Rather (party): `lib/would_you_rather/`. 2-8 players on one phone, secret votes behind a "pass the phone" step, majority scores a point, 40 wholesome prompts.
- Neither is online yet. Online Snakes & Ladders remains the only server-synced game.

### Tests
- 304 tests pass (up from 270): rules, AI, widget flows, 360x640 and 412x923 at 1.4x text.
- Eight existing tests now scroll a game card into view before tapping it, because the tiles sit below the new hero. No assertions were weakened.

---

## Change Entry: functionality pass (online games, Quick Match, reactions, events)
- Server game framework with Snakes & Ladders and Connect Four online; Quick Match queue; fixed-set reactions; pseudonymous product events with admin counts. Details in `server/BUILD_LOG.md` steps 11-14.
- App: `OnlineGameSession` (shared sync/turn-timer/rematch/reactions), online Connect Four screen, Quick Match screen and picker, game choice when creating a room, `online_game_router.dart`.
- Housekeeping: `dart format` was run over `lib/screens` and `lib/network`, which re-styled some files that had no functional change (new formatter style).
- Tests: 334 Flutter tests; server suites `test:snl`, `test:ratelimit`, `test:games`, `test:matchmaking`, and `test:integration` (real server + Postgres).

---

## Change Entry: online Ludo
- Server-authoritative Ludo (`server/src/games/ludo.ts`), checked against the offline Dart controller by replaying 36 recorded games turn by turn. Online screen `lib/screens/online_ludo_screen.dart` reuses the existing board/dice/token widgets. Offline Ludo code is untouched.
- Fixed: the room title in the online Snakes & Ladders header overflowed on a 360px phone at large text.
- Tests: 350 Flutter tests (1 skipped generator), server suites `test:ludo` (parity + rules + random play) and `test:integration` (94 checks).

---

## Change Entry: launch safety (Batch A)
- Server: remote config and feature flags (`/v1/config`, admin kill switch `/admin/flags/:key`); consent and age range (`/v1/me/consent`, `/v1/me/eligibility`, under-13 limited to private rooms); data export (`/v1/me/export`); duplicate-action protection (`expectedRevision`); a background sweeper that skips expired turns, forfeits players disconnected for 90 s and closes stale lobbies; host kick; fixed quick phrases. Migration `006_launch_controls.sql` (reversible). Details in `server/BUILD_LOG.md` step 16.
- App: consent sheet, Quick Match tile follows the server flag, kick button, "removed / room expired" handling, quick-phrase chips, 48dp reaction targets, reduced-motion respected for the Connect Four drop and page transitions, community rules and "Copy my data" under Account.
- Quick Match ships OFF by default (`FEATURE_PUBLIC_DISCOVERY`). No free-text chat anywhere.
- Tests: 359 Flutter tests; `test:integration` now 125 checks including sweeper, consent, kill switch, stale actions and kick.

---

## Change Entry: Match XP and Party Mode
- Match XP (win 30 / draw 15 / played 10, 300 per day cap) with level on the Account screen.
- Party Mode: create a room with the "Party (random games)" option and 3, 5 or 7 rounds. The server picks a random game each round that fits the group, keeps score (win 3, played 1, draw 2) and announces the winner. App: `PartyScreen` (score bar above the normal game screens), "Next round" replaces "Rematch" in party rooms.
- Tests: 362 Flutter tests; server `test:party`, `test:integration`.

---

## Change Entry: Word Rush and Bluff & Vote
- Two new online games for private rooms (and Party Mode): Word Rush (race to unscramble) and Bluff & Vote (fake answers and votes). Server-held secrets are never sent to clients before the reveal.
- App: `OnlineWordRushScreen`, `OnlineBluffScreen`, shared round header; Quick Match no longer lists games where players write text; the lobby only offers valid player counts.
- Not added to the Games tab catalogue yet (they are online-only).
- Tests: server `test:wordbluff`, `test:integration` (secret-leak checks over real sockets); Flutter widget and 360px/1.4x layout tests.

---

## Change Entry: navigation and Game Details (Batch D, slice 1)
- Tabs are now Home, Games, Party, Friends, Profile (was Home, Games, Play, Social). Profile is the existing account screen (name, level, rules, data copy, delete).
- Tapping a game opens a Game Details screen (players, typical length, how to play, ways to play) with Play, and Play online for games that have it; the lobby opens on that game.
- Each game's rules and length are in `game_catalog.dart`; lengths are estimates.
- Fixed: lobby connection row overflowed on narrow screens.
- Not done yet: splash, onboarding pages and profile creation (need local storage to remember the first launch; no storage package is installed), Google sign-in, lobby player-card redesign, "More from Elyndor".
- Tests: 379 Flutter tests; eight existing navigation tests now go through Game Details.

---

## Change Entry: UI polish pass (Party, Friends, Profile, lobby)
- Party tab: tilted "Start a party" card, room code entered as six ticket tiles (`RoomCodeField`), quieter "more ways to play" rows. Typing a code now joins that room after sign-in and consent.
- Lobby: titled "Play online"; game picker is a set of sticker tiles with an emoji (online games plus Party) instead of default chips; rounds and player counts use the same style; the join box is the same ticket-tile field. Waiting room: big shareable code with Copy code and what is being played, one seat per player with colour avatars and a Ready chip, empty seats shown, clearer Start/Ready labels.
- Friends renamed from Social, themed tabs, friendlier empty and error states (`StateMessage`, `EmptyHint`). Profile has an avatar, level and a proper XP bar.
- Tests: 388 Flutter tests.
- Not touched: the in-game screens, the consent sheet's button, Home.

---

## Change Entry: UI polish, second pass (in-game screens, consent, Home)
- Shared in-game header: score pills (coloured dot per player, yours edged yellow), timer pill that turns pink in the last 5 seconds, sticker phrase chips, a result card (trophy, applause or handshake).
- Word Rush: tilted cream letter tiles, sticker input and yellow Go. Bluff & Vote: sticker answer box and options; reveal highlights the true answer, says "No votes" instead of an empty line, shows points as pills.
- Snakes & Ladders online uses the same status pill as Connect Four.
- Consent sheet: rules in a checked list, age as three sticker tiles, yellow button.
- Home: tiles for online-capable games carry an "Online" badge; the caption listing them is gone.
- Lobby errors show plain messages.
- Tests: 389 Flutter tests.
- Verified visually in the browser: consent sheet, Home, Snakes & Ladders, Word Rush (mid-round and draw), Bluff & Vote write and vote. The Bluff reveal after its last restyle was covered by widget tests only.

---

## Change Entry: onboarding and profile creation (Batch D, slice 2)
- First launch: splash, three short pages (Skip available), then "Who are you?" with eight preset avatars and a nickname (2-20 characters, same limits as the server). "Skip for now" keeps the automatic guest name. Returning players go straight to the app.
- The choice is saved on the device (`shared_preferences`, the only new dependency) and sent to the server the next time it is reachable (Profile screen or online lobby); a failed send is retried later. Profile now has an avatar picker and shows your avatar; waiting-room seats show each player's avatar. Deleting the account also clears the saved profile, so onboarding starts again.
- Not built: Google sign-in (needs Firebase and Google credentials), "More from Elyndor" (waiting for Play Store links).
- Tests: 398 Flutter tests, including the flow at 360x640 with 1.4x text, which caught and fixed an overflow.
