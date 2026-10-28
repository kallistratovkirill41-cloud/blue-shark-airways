BLUE SHARK AIRWAYS — BACKEND STARTER
===================================

What is included
- Existing static website and Cargo page retained.
- /portal/ initial portal UI.
- Supabase SQL migration: profiles with pending/approved/rejected/suspended status,
  fleet, flights, live positions, resources, Row Level Security (RLS).
- Cloudflare Pages Function POST /api/acars for authenticated ACARS position ingestion.
- Cloudflare Pages Function GET /api/vatsim to proxy the public VATSIM data feed.

IMPORTANT: this is the backend integration starter, not a fully configured live service.
Create a Supabase project and configure its URL/keys before enabling login. The included
portal page is still a UI prototype until its forms are wired to Supabase Auth/queries.

SETUP
1. Create a Supabase project.
2. Open SQL Editor and run supabase/migrations/001_initial_schema.sql.
3. Register the intended administrator through Supabase Auth, then run the final commented
   UPDATE statement in the migration with that account's email. Keep the admin account secure.
4. Add frontend variables from supabase/config.example.js to the portal app. Use only the
   publishable/anon key in browser code. Never put the service_role key in the website.
5. Deploy this folder to Cloudflare Pages with Git integration so the /functions directory
   is deployed as Pages Functions. A plain drag-and-drop static upload will not run Functions.
6. In Cloudflare Pages → Settings → Variables and Secrets, add:
   ACARS_INGEST_TOKEN (random long secret), SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
   Mark secrets as secret. The service-role key must only be used by server-side Functions.
7. Test GET /api/vatsim and POST /api/acars with a valid bearer token.

MEMBER APPROVAL FLOW
- Supabase Auth creates the auth user.
- Database trigger creates a profile with status=pending and is_admin=false.
- Pending users should see only the pending approval screen.
- Admin review UI still needs to be wired to update profiles.status.
- Do not trust status or is_admin sent from a browser form.

MAP DATA
- /api/vatsim returns the live public VATSIM pilot snapshot. Filter pilots by callsign prefix
  or a maintained Blue Shark pilot list before presenting them as airline members. VATSIM
  positions are not automatically associated with an airline's internal fleet.
- /api/acars accepts a single position payload. Your ACARS client must send the matching
  bearer token securely; never embed the token in publicly downloadable client JavaScript.
- A production implementation should use one token per pilot/device, rotate credentials,
  validate callsign ownership, rate-limit requests, and expire stale positions.

NEXT IMPLEMENTATION TASKS
- Wire signup/login/logout and pending/approved screens to Supabase Auth.
- Add admin-only approval queue and rejection/suspension actions.
- Replace fleet demo data with Supabase queries and admin CRUD.
- Add MapLibre/Leaflet map and merge fresh ACARS positions with VATSIM pilots.
- Add Storage policies and resource upload screens for ACARS and liveries.
- Add audit logging, rate limits, privacy notice and backups before public launch.

SITE INTEGRATION
- The original home page now links to /portal/.
- Existing /cargo/ and images remain in place.
- Portal's login form is deliberately disabled until Supabase Auth is configured; it does not
  store passwords in localStorage. The fleet and map visuals are still sample/demo data until
  connected to the database and live feeds.
