// Supabase Edge Function: export-claim-report
// Compiles and generates structured claim report payload for client-side PDF export.
// Security: Verifies caller is the owner of the claim or an administrator.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';
import { corsHeaders, handleCors } from '../_shared/cors.ts';

Deno.serve(async (req: Request) => {
  // 1. Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed. Use POST or GET.' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    // 2. Authentication Check
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Invalid or expired authentication token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Extract claim_id from JSON body or query parameter
    let claimId: string | null = null;
    const url = new URL(req.url);
    const queryClaimId = url.searchParams.get('claim_id');

    if (queryClaimId) {
      claimId = queryClaimId;
    } else if (req.method === 'POST') {
      try {
        const body = await req.json();
        claimId = body?.claim_id ?? null;
      } catch {
        // Body was empty or non-JSON
      }
    }

    if (!claimId) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameter: claim_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Admin client to fetch full denormalized bundle
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    });

    // Check caller's role in public.profiles
    const { data: callerProfile } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();
    const isAdmin = callerProfile?.role === 'admin';

    // 4. Fetch Claim Record
    const { data: claim, error: claimErr } = await supabaseAdmin
      .from('claims')
      .select('*')
      .eq('id', claimId)
      .single();

    if (claimErr || !claim) {
      return new Response(
        JSON.stringify({ error: 'Claim not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Authorization Check: Owner or Admin
    if (claim.user_id !== user.id && !isAdmin) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: You are not authorized to export this claim report' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 6. Fetch Associated Product
    const { data: product } = await supabaseAdmin
      .from('products')
      .select('*')
      .eq('id', claim.product_id)
      .single();

    // 7. Fetch Customer Details
    const { data: customerProfile } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('id', claim.user_id)
      .single();

    let customerEmail = '';
    try {
      const { data: authUser } = await supabaseAdmin.auth.admin.getUserById(claim.user_id);
      customerEmail = authUser?.user?.email ?? '';
    } catch {
      // Non-fatal if auth user lookup fails
    }

    const customer = {
      id: customerProfile?.id ?? claim.user_id,
      full_name: customerProfile?.full_name ?? 'Valued Customer',
      email: customerEmail,
      phone_number: customerProfile?.phone_number ?? '',
      avatar_url: customerProfile?.avatar_url ?? null,
      created_at: customerProfile?.created_at ?? null,
    };

    // 8. Fetch Claim Timeline in chronological order (created_at ASC)
    const { data: timeline } = await supabaseAdmin
      .from('claim_timeline')
      .select('id, from_status, to_status, changed_by, notes, created_at')
      .eq('claim_id', claim.id)
      .order('created_at', { ascending: true });

    // 9. Fetch Claim Attachments
    const { data: attachments } = await supabaseAdmin
      .from('claim_attachments')
      .select('id, file_url, file_name, file_type, file_size, created_at')
      .eq('claim_id', claim.id);

    // 10. Generate Verification Details
    const cleanNumber = claim.claim_number
      ? claim.claim_number.replace(/^CLM-/, '')
      : claim.id.slice(0, 8).toUpperCase();
    const verificationCode = `CLM-VFY-${cleanNumber}`;
    const verificationUrl = `${supabaseUrl}/verify?claim=${encodeURIComponent(claim.claim_number ?? claim.id)}&code=${verificationCode}`;

    // 11. Compile Complete Report Payload
    const reportPayload = {
      report_id: `REP-${claim.claim_number ?? claim.id}`,
      generated_at: new Date().toISOString(),
      claim: {
        id: claim.id,
        claim_number: claim.claim_number,
        title: claim.title,
        description: claim.description,
        type: claim.type,
        status: claim.status,
        priority: claim.priority,
        issue_category: claim.issue_category,
        incident_date: claim.incident_date,
        admin_notes: claim.admin_notes,
        resolution_notes: claim.resolution_notes,
        resolved_at: claim.resolved_at,
        created_at: claim.created_at,
        updated_at: claim.updated_at,
      },
      product: product ?? null,
      customer,
      timeline: timeline ?? [],
      attachments: attachments ?? [],
      verification: {
        verification_code: verificationCode,
        verification_url: verificationUrl,
      },
    };

    return new Response(JSON.stringify(reportPayload), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Unexpected error in export-claim-report:', err);
    return new Response(
      JSON.stringify({ error: err?.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
