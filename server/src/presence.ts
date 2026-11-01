// Who is connected right now.
//
// shortcut: in memory, so it resets when the server restarts (everyone then
// looks connected until their next disconnect) and does not span several
// server instances. Move it to Redis before running more than one.
const sockets = new Map<string, Set<string>>(); // userId -> socket ids
const disconnectedAt = new Map<string, number>(); // userId -> when their last socket closed

export function markConnected(userId: string, socketId: string): void {
  let set = sockets.get(userId);
  if (!set) sockets.set(userId, (set = new Set()));
  set.add(socketId);
  disconnectedAt.delete(userId);
}

export function markDisconnected(userId: string, socketId: string, now = Date.now()): void {
  const set = sockets.get(userId);
  if (!set) return;
  set.delete(socketId);
  if (set.size === 0) {
    sockets.delete(userId);
    disconnectedAt.set(userId, now);
  }
}

export const socketIdsOf = (userId: string): string[] => [...(sockets.get(userId) ?? [])];
export const isOnline = (userId: string): boolean => sockets.has(userId);

/** Users whose last socket closed more than `ms` ago and who have not come back. */
export function disconnectedLongerThan(ms: number, now = Date.now()): string[] {
  return [...disconnectedAt].filter(([, t]) => now - t > ms).map(([id]) => id);
}

export function forget(userId: string): void {
  disconnectedAt.delete(userId);
}

/** For tests. */
export function resetPresence(): void {
  sockets.clear();
  disconnectedAt.clear();
}
