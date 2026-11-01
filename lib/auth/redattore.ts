import { redirect } from 'next/navigation';
import { auth } from './server';

export interface Redattore { id: string; email: string; nome: string }

// Chi può modificare: un utente con il ruolo «redattore» (o «admin») assegnato in Neon Auth
export async function redattoreCorrente(): Promise<{ redattore: Redattore | null; motivo: 'anonimo' | 'senza-ruolo' | null }> {
  const { data: session } = await auth.getSession();
  const u = session?.user as { id: string; email: string; name?: string; role?: string | null } | undefined;
  if (!u) return { redattore: null, motivo: 'anonimo' };
  const ruoli = String(u.role ?? '').split(',').map((r) => r.trim());
  if (!ruoli.includes('redattore') && !ruoli.includes('admin')) return { redattore: null, motivo: 'senza-ruolo' };
  return { redattore: { id: u.id, email: u.email, nome: u.name || u.email }, motivo: null };
}

// Per pagine e azioni: senza sessione all'accesso, senza ruolo alla pagina che lo spiega
export async function richiediRedattore(lang: string): Promise<Redattore> {
  const { redattore, motivo } = await redattoreCorrente();
  if (motivo === 'anonimo') redirect(`/${lang}/redazione/accesso`);
  if (!redattore) redirect(`/${lang}/redazione/accesso?esito=senza-ruolo`);
  return redattore;
}
