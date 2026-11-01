// In-memory sliding-window limiter.
// shortcut: per-process memory, so limits reset on restart and are not shared
// between server instances; move to Redis/Postgres before running more than one.
export function createRateLimiter() {
  const hits = new Map<string, number[]>();
  return {
    /** Returns true if the action is allowed (and records it). */
    allow(key: string, max: number, windowMs: number, now = Date.now()): boolean {
      const recent = (hits.get(key) ?? []).filter((t) => now - t < windowMs);
      if (recent.length >= max) {
        hits.set(key, recent);
        return false;
      }
      recent.push(now);
      hits.set(key, recent);
      return true;
    },
  };
}

export const limiter = createRateLimiter();

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const isUuid = (v: unknown): v is string => typeof v === 'string' && UUID_RE.test(v);
