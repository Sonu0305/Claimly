// Supabase Edge Function: claim-analytics
// Computes aggregated KPIs and dashboard metrics for the Claimly admin dashboard.
// Strictly verifies caller role = 'admin' from public.profiles table.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';
import { corsHeaders, handleCors } from '../_shared/cors.ts';

Deno.serve(async (req: Request) => {
  // 1. Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'GET' && req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed. Use GET or POST.' }),
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
        JSON.stringify({ error: 'Unauthorized: Invalid or expired token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Authorization Check (Role = 'admin')
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: profile, error: profileErr } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (profileErr || !profile || profile.role !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Forbidden: Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. Query All Claims
    const { data: claims, error: claimsErr } = await supabaseAdmin
      .from('claims')
      .select('id, claim_number, status, type, issue_category, created_at, resolved_at');

    if (claimsErr) {
      console.error('Error fetching claims for analytics:', claimsErr);
      return new Response(
        JSON.stringify({ error: `Database error: ${claimsErr.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const claimList = claims || [];

    // 5. Aggregate Summary KPIs
    const totalClaims = claimList.length;
    const activeClaims = claimList.filter(
      (c) => c.status === 'submitted' || c.status === 'under_review'
    ).length;

    const approvedCount = claimList.filter((c) => c.status === 'approved').length;
    const rejectedCount = claimList.filter((c) => c.status === 'rejected').length;
    const decidedCount = approvedCount + rejectedCount;

    const approvalRate = decidedCount > 0
      ? Number(((approvedCount / decidedCount) * 100).toFixed(1))
      : 0.0;

    // Average resolution time in days for resolved claims
    const resolvedClaims = claimList.filter((c) => c.resolved_at && c.created_at);
    let avgResolutionDays = 0.0;

    if (resolvedClaims.length > 0) {
      const msPerDay = 1000 * 60 * 60 * 24;
      const totalResolutionDays = resolvedClaims.reduce((sum, c) => {
        const createdMs = new Date(c.created_at).getTime();
        const resolvedMs = new Date(c.resolved_at).getTime();
        const diffDays = Math.max(0, (resolvedMs - createdMs) / msPerDay);
        return sum + diffDays;
      }, 0);
      avgResolutionDays = Number((totalResolutionDays / resolvedClaims.length).toFixed(1));
    }

    // 6. Status Breakdown
    const statusBreakdown = {
      draft: 0,
      submitted: 0,
      under_review: 0,
      approved: 0,
      rejected: 0,
      completed: 0,
    };
    for (const c of claimList) {
      if (c.status in statusBreakdown) {
        statusBreakdown[c.status as keyof typeof statusBreakdown]++;
      }
    }

    // 7. Claims by Type Breakdown
    const claimsByType = {
      warranty: 0,
      refund: 0,
      replacement: 0,
    };
    for (const c of claimList) {
      if (c.type in claimsByType) {
        claimsByType[c.type as keyof typeof claimsByType]++;
      }
    }

    // 8. Claims Over Time (Last 30 Days Chronological)
    const now = new Date();
    const dateCounts: Record<string, number> = {};

    for (let i = 29; i >= 0; i--) {
      const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - i));
      const dateStr = d.toISOString().split('T')[0];
      dateCounts[dateStr] = 0;
    }

    for (const c of claimList) {
      if (c.created_at) {
        const createdDate = c.created_at.split('T')[0];
        if (createdDate in dateCounts) {
          dateCounts[createdDate]++;
        }
      }
    }

    const claimsOverTime = Object.entries(dateCounts).map(([date, count]) => ({
      date,
      count,
    }));

    // 9. Top Issue Categories Grouping
    const categoryMap: Record<string, number> = {};
    for (const c of claimList) {
      const cat = c.issue_category && c.issue_category.trim() !== ''
        ? c.issue_category.trim()
        : 'General / Other';
      categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
    }

    const topIssueCategories = Object.entries(categoryMap)
      .map(([category, count]) => ({ category, count }))
      .sort((a, b) => b.count - a.count);

    // 10. Return Assembled Analytics Payload
    const responsePayload = {
      summary: {
        total_claims: totalClaims,
        active_claims: activeClaims,
        approval_rate: approvalRate,
        avg_resolution_days: avgResolutionDays,
      },
      status_breakdown: statusBreakdown,
      claims_by_type: claimsByType,
      claims_over_time: claimsOverTime,
      top_issue_categories: topIssueCategories,
    };

    return new Response(JSON.stringify(responsePayload), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Unexpected error in claim-analytics:', err);
    return new Response(
      JSON.stringify({ error: err?.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
