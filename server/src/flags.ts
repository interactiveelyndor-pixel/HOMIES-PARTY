import { pool } from './db';

/**
 * Feature flags. The environment gives the default; a row in feature_flags
 * overrides it at runtime (set through the admin API), which is the kill switch.
 */
export const FLAG_DEFAULTS = {
  // Pairing strangers (Quick Match). Off until age gating, policy review and
  // moderation staffing are signed off.
  publicDiscovery: process.env.FEATURE_PUBLIC_DISCOVERY === 'true',
} as const;

export type FlagKey = keyof typeof FLAG_DEFAULTS;
export const FLAG_KEYS = Object.keys(FLAG_DEFAULTS) as FlagKey[];

/** Current value of every flag (default merged with overrides). */
export async function getFlags(): Promise<Record<FlagKey, boolean>> {
  const flags = { ...FLAG_DEFAULTS } as Record<FlagKey, boolean>;
  try {
    const rows = await pool.query('SELECT key, enabled FROM feature_flags');
    for (const r of rows.rows) if ((FLAG_KEYS as string[]).includes(r.key)) flags[r.key as FlagKey] = r.enabled;
  } catch {
    // Database trouble: fall back to the safe defaults.
  }
  return flags;
}

export async function setFlag(key: FlagKey, enabled: boolean): Promise<void> {
  await pool.query(
    `INSERT INTO feature_flags (key, enabled) VALUES ($1, $2)
     ON CONFLICT (key) DO UPDATE SET enabled = EXCLUDED.enabled, updated_at = NOW()`,
    [key, enabled]
  );
}

export const minClientVersion = (): string => process.env.MIN_CLIENT_VERSION || '0.0.0';
