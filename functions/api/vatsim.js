// Read-only proxy for the public VATSIM network snapshot. No credentials required.
export async function onRequestGet() {
  try {
    const upstream = await fetch('https://data.vatsim.net/v3/vatsim-data.json', {
      headers: { 'Accept': 'application/json' }, cf: { cacheTtl: 15, cacheEverything: true }
    });
    if (!upstream.ok) return Response.json({ error: 'VATSIM feed unavailable' }, { status: 502 });
    const data = await upstream.json();
    return Response.json({ fetched_at: data.general?.update_timestamp || null, pilots: data.pilots || [] }, {
      headers: { 'Cache-Control': 'public, max-age=15, s-maxage=15' }
    });
  } catch {
    return Response.json({ error: 'Could not reach VATSIM feed' }, { status: 502 });
  }
}
