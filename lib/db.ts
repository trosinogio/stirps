import { Pool as PgPool } from 'pg';
import { Pool as NeonPool } from '@neondatabase/serverless';
import { attachDatabasePool } from '@vercel/functions';
import { parseEnv } from '@neon/env';
import config from '@/neon';

// node-postgres con la stringa pooled di Neon, come raccomandano le skill di Neon per Vercel (Fluid compute):
// un pool per istanza, che attachDatabasePool chiude bene quando la funzione viene sospesa.
// NEON_WEBSOCKET=1 usa lo stesso protocollo via WebSocket (porta 443), con il Pool del driver serverless di Neon:
// serve solo sulle reti che chiudono la porta 5432; su Vercel non va impostata.
// La variabile si legge alla prima query, così una build senza database non si rompe.
const g = globalThis as unknown as { _pool?: PgPool };

function creaPool(): PgPool {
  const { postgres } = parseEnv(config, ['DATABASE_URL']);
  const Classe = process.env.NEON_WEBSOCKET === '1' ? NeonPool : PgPool;
  const p = new Classe({ connectionString: postgres.databaseUrl, max: Number(process.env.PG_POOL_MAX ?? 5) }) as unknown as PgPool;
  attachDatabasePool(p);
  return p;
}

export function pool(): PgPool {
  return (g._pool ??= creaPool());
}

export async function query<T>(sql: string, params: unknown[] = []): Promise<T[]> {
  const r = await pool().query(sql, params);
  return r.rows as T[];
}

// Una modifica della redazione: una transazione firmata. Lo storico registra l'autore da app.utente.
export async function transazione<T>(utente: string, fn: (q: <R>(sql: string, params?: unknown[]) => Promise<R[]>) => Promise<T>): Promise<T> {
  const client = await pool().connect();
  try {
    await client.query('begin');
    await client.query(`select set_config('app.utente', $1, true)`, [utente]);
    const q = async <R,>(sql: string, params: unknown[] = []) => (await client.query(sql, params)).rows as R[];
    const r = await fn(q);
    await client.query('commit');
    return r;
  } catch (e) {
    await client.query('rollback').catch(() => {});
    throw e;
  } finally {
    client.release();
  }
}
