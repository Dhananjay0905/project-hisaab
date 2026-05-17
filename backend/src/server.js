/**
 * Server entry point.
 * Boots the Express app and connects to the database.
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const app = require('./app');

const PORT = parseInt(process.env.PORT || '3000', 10);
const prisma = new PrismaClient();

// ─── Scheduled account deletion cleanup ───────────────────────────────────────

async function runDeletionCleanup() {
  try {
    const result = await prisma.user.deleteMany({
      where: { scheduledDeleteAt: { lte: new Date() } },
    });
    if (result.count > 0) {
      console.log(`🗑️  Deleted ${result.count} account(s) past grace period.`);
    }
  } catch (err) {
    console.error('[CLEANUP] Account deletion job failed:', err.message);
  }
}

async function bootstrap() {
  try {
    // Test database connection
    await prisma.$connect();
    console.log('✅ Database connected');

    // Run deletion cleanup immediately on boot, then every 24 hours
    await runDeletionCleanup();
    setInterval(runDeletionCleanup, 24 * 60 * 60 * 1000);

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Hisaab API running on http://0.0.0.0:${PORT}`);
      console.log(`   ENV: ${process.env.NODE_ENV || 'development'}`);
    });
  } catch (err) {
    console.error('❌ Failed to start server:', err.message);
    await prisma.$disconnect();
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await prisma.$disconnect();
  process.exit(0);
});

bootstrap();
