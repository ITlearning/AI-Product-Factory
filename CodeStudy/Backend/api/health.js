/**
 * Minimal health check endpoint.
 * Uses Vercel Route Handler pattern (named GET export).
 */
export async function GET() {
  return Response.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    runtime: 'vercel',
  });
}
