import { BaseState, GameModule } from './types';
import { connect4 } from './connect4';
import { ludo } from './ludo';
import { wordrush } from './wordrush';
import { bluff } from './bluff';
import { applyRoll, initSnlState, skipExpiredTurn, SnlState } from '../snl';

// Snakes & Ladders keeps its original module (src/snl.ts); this adapts it.
const snl: GameModule<SnlState> = {
  id: 'snl',
  minPlayers: 2,
  maxPlayers: 4,
  init: (userIds, now, version) => initSnlState(userIds, now, version),
  // The roll is the server's: any client input is ignored.
  move: (state, userId, _input, ctx) =>
    applyRoll(state, userId, ctx.randomInt(1, 7), ctx.active, ctx.now),
  skip: skipExpiredTurn,
} as GameModule<SnlState>;

/** Every game the server can run. The key is the room's game_type. */
export const GAMES: Record<string, GameModule<any>> = { snl, connect4, ludo, wordrush, bluff };

export const GAME_IDS = Object.keys(GAMES);

export function getGame(id: string): GameModule<BaseState> | undefined {
  return Object.prototype.hasOwnProperty.call(GAMES, id) ? GAMES[id] : undefined;
}
