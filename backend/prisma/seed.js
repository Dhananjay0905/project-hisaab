/**
 * Prisma seed — runs with `npm run db:seed`.
 * Optional: use this for development data. Production seeds are handled
 * by the auth service (default categories created on register).
 */

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');
  // No global seed needed — default categories are created per-user on register.
  console.log('✅ Seed complete (no-op for production).');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
