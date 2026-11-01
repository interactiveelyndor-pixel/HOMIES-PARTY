// Connect Four rules, mirroring lib/connect4/connect4_logic.dart.
// board[row][col]: 0 empty, 1 = players[0], 2 = players[1]. Row 0 is the top.
import { BaseState, GameModule, GameResult } from './types';

export const ROWS = 6;
export const COLS = 7;
export const TURN_MS = 30_000;

export interface Connect4State extends BaseState {
  board: number[][];
  lastMove: { row: number; col: number } | null;
  winningCells: { row: number; col: number }[];
}

const DIRS: [number, number][] = [[0, 1], [1, 0], [1, 1], [1, -1]];

/** The run of 4+ equal discs through (r, c), or an empty list. */
export function lineThrough(board: number[][], r: number, c: number): { row: number; col: number }[] {
  const who = board[r][c];
  for (const [dr, dc] of DIRS) {
    const cells = [{ row: r, col: c }];
    for (const s of [1, -1]) {
      let rr = r + dr * s;
      let cc = c + dc * s;
      while (rr >= 0 && rr < ROWS && cc >= 0 && cc < COLS && board[rr][cc] === who) {
        cells.push({ row: rr, col: cc });
        rr += dr * s;
        cc += dc * s;
      }
    }
    if (cells.length >= 4) return cells;
  }
  return [];
}

function clone(s: Connect4State): Connect4State {
  return { ...s, players: s.players.map((p) => ({ ...p })), board: s.board.map((r) => [...r]) };
}

/** If a player left, the other wins; otherwise make sure it is an active player's turn. */
function settleLeavers(state: Connect4State, active: Set<string>): void {
  const remaining = state.players.filter((p) => active.has(p.userId));
  if (remaining.length < 2) {
    state.winnerId = remaining[0]?.userId ?? null;
    state.draw = remaining.length === 0;
    return;
  }
  for (let i = 0; i < state.players.length && !active.has(state.players[state.turn].userId); i++) {
    state.turn = (state.turn + 1) % state.players.length;
  }
}

export const connect4: GameModule<Connect4State> = {
  id: 'connect4',
  minPlayers: 2,
  maxPlayers: 2,

  init(userIds, now, version = 0) {
    if (userIds.length !== 2) throw new Error('Connect Four needs exactly 2 players.');
    return {
      players: userIds.map((userId) => ({ userId })),
      turn: 0,
      board: Array.from({ length: ROWS }, () => Array(COLS).fill(0)),
      lastMove: null,
      winningCells: [],
      winnerId: null,
      draw: false,
      version,
      turnDeadline: now + TURN_MS,
    };
  },

  move(prev, userId, input, ctx): GameResult<Connect4State> {
    if (prev.winnerId || prev.draw) return { error: 'The game is already over.' };
    const col = (input as { column?: unknown } | null)?.column;
    if (typeof col !== 'number' || !Number.isInteger(col) || col < 0 || col >= COLS) {
      return { error: 'Choose a column from 0 to 6.' };
    }

    const state = clone(prev);
    settleLeavers(state, ctx.active);
    if (state.winnerId || state.draw) {
      state.version++;
      return { state };
    }
    if (state.players[state.turn].userId !== userId) return { error: 'It is not your turn.' };

    let row = ROWS - 1;
    while (row >= 0 && state.board[row][col] !== 0) row--;
    if (row < 0) return { error: 'That column is full.' };

    state.board[row][col] = state.turn + 1;
    state.lastMove = { row, col };
    const line = lineThrough(state.board, row, col);
    if (line.length) {
      state.winnerId = userId;
      state.winningCells = line;
    } else if (state.board[0].every((c) => c !== 0)) {
      state.draw = true;
    } else {
      state.turn = (state.turn + 1) % state.players.length;
    }
    state.turnDeadline = ctx.now + TURN_MS;
    state.version++;
    return { state };
  },

  skip(prev, active, now): GameResult<Connect4State> {
    if (prev.winnerId || prev.draw) return { error: 'The game is already over.' };
    if (now < prev.turnDeadline) return { error: 'The turn has not expired yet.' };
    const state = clone(prev);
    settleLeavers(state, active);
    if (!state.winnerId && !state.draw) {
      state.turn = (state.turn + 1) % state.players.length;
    }
    state.turnDeadline = now + TURN_MS;
    state.version++;
    return { state };
  },
};
