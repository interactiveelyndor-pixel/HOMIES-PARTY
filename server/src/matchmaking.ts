// Quick Match: pairs players waiting for the same game.
//
// shortcut: the queue lives in this process's memory, so it is lost on restart
// and does not span several server instances. Players simply press Quick Match
// again after a restart. Move it to Redis/Postgres before running two servers.

export interface MatchDeps {
  /** True if either user has blocked the other. */
  isBlocked(a: string, b: string): Promise<boolean>;
  /** Creates a started room for these players and returns it. */
  createRoom(gameType: string, userIds: string[]): Promise<unknown>;
  /** Sends an event to one connected socket. */
  send(socketId: string, event: string, payload: unknown): void;
  isConnected(socketId: string): boolean;
  /** Called once a room exists, so both sockets can subscribe to it. */
  matched(room: unknown, socketIds: string[]): void;
}

interface Entry {
  userId: string;
  socketId: string;
  gameType: string;
  timer: ReturnType<typeof setTimeout>;
}

export type JoinResult = { status: 'searching'; timeoutMs: number } | { status: 'matched' };

export class Matchmaker {
  private queues = new Map<string, Entry[]>();
  // One join at a time per game, so two simultaneous joins cannot both claim
  // the same waiting player.
  private locks = new Map<string, Promise<unknown>>();

  constructor(
    private deps: MatchDeps,
    private opts: { timeoutMs: number; playersFor: (gameType: string) => number } = {
      timeoutMs: 60_000,
      playersFor: () => 2,
    }
  ) {}

  queueSize(gameType: string): number {
    return this.queues.get(gameType)?.length ?? 0;
  }

  join(userId: string, socketId: string, gameType: string): Promise<JoinResult> {
    const prev = this.locks.get(gameType) ?? Promise.resolve();
    const run = prev.catch(() => {}).then(() => this.joinLocked(userId, socketId, gameType));
    this.locks.set(gameType, run);
    return run;
  }

  private async joinLocked(userId: string, socketId: string, gameType: string): Promise<JoinResult> {
    this.cancel(userId); // a user waits in one queue at a time
    const queue = this.queues.get(gameType) ?? [];
    this.queues.set(gameType, queue);
    const need = this.opts.playersFor(gameType);

    // Pick waiting players who are still connected and not blocked with anyone chosen.
    const chosen: Entry[] = [];
    for (const e of [...queue]) {
      if (chosen.length >= need - 1) break;
      if (e.userId === userId) continue;
      if (!this.deps.isConnected(e.socketId)) {
        this.remove(e);
        continue;
      }
      let blocked = await this.deps.isBlocked(userId, e.userId);
      for (let i = 0; !blocked && i < chosen.length; i++) {
        blocked = await this.deps.isBlocked(chosen[i].userId, e.userId);
      }
      if (!blocked) chosen.push(e);
    }

    if (chosen.length < need - 1) {
      const entry: Entry = {
        userId,
        socketId,
        gameType,
        timer: setTimeout(() => {
          if (this.remove(entry)) this.deps.send(socketId, 'match:timeout', { gameType });
        }, this.opts.timeoutMs),
      };
      queue.push(entry);
      return { status: 'searching', timeoutMs: this.opts.timeoutMs };
    }

    chosen.forEach((e) => this.remove(e));
    const players = [...chosen.map((e) => e.userId), userId];
    const sockets = [...chosen.map((e) => e.socketId), socketId];
    try {
      const room = await this.deps.createRoom(gameType, players);
      this.deps.matched(room, sockets);
      sockets.forEach((id) => this.deps.send(id, 'match:found', { room }));
    } catch (err) {
      sockets.forEach((id) =>
        this.deps.send(id, 'match:error', { message: 'Could not start the match. Please try again.' })
      );
    }
    return { status: 'matched' };
  }

  /** Leaves the queue. Returns true if the user was waiting. */
  cancel(userId: string): boolean {
    let found = false;
    for (const queue of this.queues.values()) {
      for (const e of [...queue]) {
        if (e.userId === userId) {
          this.remove(e);
          found = true;
        }
      }
    }
    return found;
  }

  /** Drops everything a socket was waiting for (called when it disconnects). */
  disconnect(socketId: string): void {
    for (const queue of this.queues.values()) {
      for (const e of [...queue]) if (e.socketId === socketId) this.remove(e);
    }
  }

  private remove(e: Entry): boolean {
    const queue = this.queues.get(e.gameType);
    const i = queue ? queue.indexOf(e) : -1;
    if (i === -1) return false;
    queue!.splice(i, 1);
    clearTimeout(e.timer);
    return true;
  }
}
