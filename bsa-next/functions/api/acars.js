// Cloudflare Pages Function: POST /api/acars
// Configure ACARS_INGEST_TOKEN, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY as Pages secrets.
// Keep the service-role key server-side only.
export async function onRequestPost({ request, env }) {
  if (!env.ACARS_INGEST_TOKEN || !env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return Response.json({ error: 'ACARS endpoint is not configured' }, { status: 503 });
  }
  if (request.headers.get('authorization') !== `Bearer ${env.ACARS_INGEST_TOKEN}`) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }
  let body;
  try { body = await request.json(); } catch { return Response.json({ error: 'Invalid JSON' }, { status: 400 }); }
  const callsign = String(body.callsign || '').trim().toUpperCase();
  const latitude = Number(body.latitude), longitude = Number(body.longitude);
  if (!callsign || !Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    return Response.json({ error: 'callsign and valid coordinates are required' }, { status: 400 });
  }
  const row = {
    source: 'acars', callsign, latitude, longitude,
    altitude_ft: Number.isFinite(Number(body.altitude_ft)) ? Number(body.altitude_ft) : null,
    ground_speed_kt: Number.isFinite(Number(body.ground_speed_kt)) ? Number(body.ground_speed_kt) : null,
    heading: Number.isFinite(Number(body.heading)) ? Number(body.heading) : null,
    observed_at: new Date().toISOString()
  };
  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/live_positions?on_conflict=source,callsign`, {
    method: 'POST',
    headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json', Prefer: 'resolution=merge-duplicates,return=minimal' },
    body: JSON.stringify(row)
  });
  if (!response.ok) return Response.json({ error: 'Position storage failed' }, { status: 502 });
  return Response.json({ ok: true, callsign, observed_at: row.observed_at });
}
