import type { NextRequest } from 'next/server';
import { auth } from '@/lib/auth/server';

// Prima barriera della redazione: senza sessione si va alla pagina di accesso, nella lingua giusta.
// Pagine e azioni controllano comunque sessione e ruolo prima di leggere o modificare.
const accesso = {
  it: auth.middleware({ loginUrl: '/it/redazione/accesso' }),
  en: auth.middleware({ loginUrl: '/en/redazione/accesso' }),
};

export default function proxy(req: NextRequest) {
  return (req.nextUrl.pathname.startsWith('/en/') ? accesso.en : accesso.it)(req);
}

export const config = {
  matcher: ['/:lang(it|en)/redazione', '/:lang(it|en)/redazione/((?!accesso).*)'],
};
