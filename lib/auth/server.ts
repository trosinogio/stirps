import { createNeonAuth } from '@neondatabase/auth/next/server';

// Neon Auth (Better Auth gestito): utenti e sessioni nello schema neon_auth dello stesso database.
// Le registrazioni pubbliche sono chiuse: i redattori li crea l'amministratore (neon neon-auth user create)
// e ricevono il ruolo «redattore» (neon neon-auth user set-role <id> --roles redattore).
export const auth = createNeonAuth({
  baseUrl: process.env.NEON_AUTH_BASE_URL!,
  cookies: { secret: process.env.NEON_AUTH_COOKIE_SECRET! },
});
