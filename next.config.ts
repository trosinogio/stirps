import type { NextConfig } from 'next';

const config: NextConfig = {
  // il driver Postgres resta fuori dal bundle del server
  serverExternalPackages: ['pg'],
  poweredByHeader: false,
  async redirects() {
    return [{ source: '/', destination: '/it', permanent: false }];
  },
};

export default config;
