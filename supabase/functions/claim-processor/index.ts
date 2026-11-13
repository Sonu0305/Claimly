// Supabase Edge Function: claim-processor
// Validates claim submissions, verifies warranty expiry with 7-day grace period,
// and computes automated priority scores (0-100).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';
import { corsHeaders, handleCors } from '../_shared/cors.ts';

interface AttachmentInput {
  file_url: string;
  file_name: string;
  file_type?: string;
  file_size?: number;
}

interface ClaimProcessorPayload {
  action: 'validate' | 'submit';
  claim_id?: string;
  product_id: string;
  type?: 'warranty' | 'refund' | 'replacement';
  title: string;
  description: string;
  issue_category?: string;
  incident_date?: string; // YYYY-MM-DD
  attachments?: AttachmentInput[];
}

function parseDateOnly(dateStr: string): Date {
  const clean = dateStr.split('T')[0];
  const parts = clean.split('-');
  return new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])));
}

function calculateDaysDifference(targetDate: Date, baseDate: Date): number {
  const msPerDay = 1000 * 60 * 60 * 24;
  return Math.floor((targetDate.getTime() - baseDate.getTime()) / msPerDay);
}

Deno.serve(async (req: Request) => {
  // 1. Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed. Use POST.' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  try {
    // 2. Setup Supabase Clients
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Authenticate user via token
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Invalid authentication token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Admin client with service_role key to bypass RLS for system scoring / status updates
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    });

    // Check user role from profiles
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();
    const isAdmin = profile?.role === 'admin';

    // 3. Parse and Validate Request Payload
    let body: Partial<ClaimProcessorPayload>;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON payload in request body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const {
      action = 'submit',
      claim_id,
      product_id,
      type = 'warranty',
      title,
      description,
      issue_category,
      incident_date,
      attachments = [],
    } = body;

    if (!['validate', 'submit'].includes(action)) {
      return new Response(
        JSON.stringify({ error: "Invalid action. Must be 'validate' or 'submit'." }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!product_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: product_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!title || typeof title !== 'string' || title.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: title' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!description || typeof description !== 'string' || description.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: description' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. Fetch and Verify Product Ownership
    const { data: product, error: productErr } = await supabaseAdmin
      .from('products')
      .select('*')
      .eq('id', product_id)
      .single();

    if (productErr || !product) {
      return new Response(
        JSON.stringify({ error: 'Product not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (product.user_id !== user.id && !isAdmin) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: You do not own this product' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Warranty Validity & 7-Day Grace Period Verification
    const todayStr = new Date().toISOString().split('T')[0];
    const todayDate = parseDateOnly(todayStr);
    const incidentDate = incident_date ? parseDateOnly(incident_date) : todayDate;
    const warrantyExpiryDate = parseDateOnly(product.warranty_expiry_date);

    // Days difference between incident date and warranty expiry date
    const daysPastExpiry = calculateDaysDifference(incidentDate, warrantyExpiryDate);
    // Days remaining from today until warranty expiry date
    const daysRemaining = calculateDaysDifference(warrantyExpiryDate, todayDate);

    let warrantyStatus: 'valid' | 'in_grace_period' | 'expired';
    let warrantyValid: boolean;

    if (daysPastExpiry <= 0) {
      warrantyStatus = 'valid';
      warrantyValid = true;
    } else if (daysPastExpiry <= 7) {
      warrantyStatus = 'in_grace_period';
      warrantyValid = true;
    } else {
      warrantyStatus = 'expired';
      warrantyValid = false;
    }

    // 6. Multi-Factor Priority Score Calculation (0 - 100)
    // - Base score: 20
    const baseScore = 20;

    // - Warranty urgency: <= 7 days remaining: +30; <= 30 days remaining: +15
    let warrantyUrgencyScore = 0;
    if (daysRemaining <= 7) {
      warrantyUrgencyScore = 30;
    } else if (daysRemaining <= 30) {
      warrantyUrgencyScore = 15;
    }

    // - Claim type: refund: +25; replacement: +20; warranty: +15
    let claimTypeScore = 15;
    if (type === 'refund') {
      claimTypeScore = 25;
    } else if (type === 'replacement') {
      claimTypeScore = 20;
    } else if (type === 'warranty') {
      claimTypeScore = 15;
    }

    // - Severity NLP keywords in title/description
    const textCorpus = `${title} ${description}`.toLowerCase();
    const highRiskKeywords = ['fire', 'smoke', 'hazard', 'shock', 'burn', 'explosion'];
    const moderateKeywords = ['broken', 'failed', 'dead', 'cracked', 'malfunction'];

    const hasHighRisk = highRiskKeywords.some((kw) => textCorpus.includes(kw));
    const hasModerate = moderateKeywords.some((kw) => textCorpus.includes(kw));

    let severityScore = 0;
    if (hasHighRisk) severityScore += 25;
    if (hasModerate) severityScore += 15;

    // - Completeness: attachments length >= 1: +10
    const completenessScore = Array.isArray(attachments) && attachments.length >= 1 ? 10 : 0;

    // - Total score clamped to [0, 100]
    const rawTotalScore = baseScore + warrantyUrgencyScore + claimTypeScore + severityScore + completenessScore;
    const priorityScore = Math.max(0, Math.min(100, rawTotalScore));

    // 7. Handle 'validate' action (does not modify database)
    if (action === 'validate') {
      return new Response(
        JSON.stringify({
          success: true,
          action: 'validate',
          priority_score: priorityScore,
          warranty_valid: warrantyValid,
          warranty_status: warrantyStatus,
          days_remaining: daysRemaining,
          score_breakdown: {
            base_score: baseScore,
            warranty_urgency: warrantyUrgencyScore,
            claim_type: claimTypeScore,
            nlp_severity: severityScore,
            completeness: completenessScore,
            raw_total: rawTotalScore,
            clamped_priority: priorityScore,
          },
          message: 'Claim validated and priority scored successfully',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 8. Handle 'submit' action (persists claim and attachments)
    let claimRecord: any;

    if (claim_id) {
      // Update existing draft claim
      const { data: existingClaim, error: fetchErr } = await supabaseAdmin
        .from('claims')
        .select('*')
        .eq('id', claim_id)
        .single();

      if (fetchErr || !existingClaim) {
        return new Response(
          JSON.stringify({ error: 'Claim not found for updating' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (existingClaim.user_id !== user.id && !isAdmin) {
        return new Response(
          JSON.stringify({ error: 'Forbidden: You do not own this claim' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const { data: updatedClaim, error: updateErr } = await supabaseAdmin
        .from('claims')
        .update({
          status: 'submitted',
          priority: priorityScore,
          title: title.trim(),
          description: description.trim(),
          type,
          issue_category: issue_category ?? existingClaim.issue_category,
          incident_date: incident_date ?? existingClaim.incident_date,
          updated_at: new Date().toISOString(),
        })
        .eq('id', claim_id)
        .select()
        .single();

      if (updateErr || !updatedClaim) {
        return new Response(
          JSON.stringify({ error: `Failed to update claim: ${updateErr?.message || 'Unknown error'}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      claimRecord = updatedClaim;
    } else {
      // Create new claim with status 'submitted'
      const { data: createdClaim, error: insertErr } = await supabaseAdmin
        .from('claims')
        .insert({
          user_id: user.id,
          product_id: product.id,
          type,
          status: 'submitted',
          title: title.trim(),
          description: description.trim(),
          issue_category: issue_category ?? null,
          incident_date: incident_date ?? todayStr,
          priority: priorityScore,
        })
        .select()
        .single();

      if (insertErr || !createdClaim) {
        return new Response(
          JSON.stringify({ error: `Failed to create claim: ${insertErr?.message || 'Unknown error'}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      claimRecord = createdClaim;
    }

    // 9. Insert Attachments if provided
    if (Array.isArray(attachments) && attachments.length > 0) {
      const attachmentRows = attachments
        .filter((att) => att.file_url && att.file_name)
        .map((att) => ({
          claim_id: claimRecord.id,
          file_url: att.file_url,
          file_name: att.file_name,
          file_type: att.file_type ?? 'application/octet-stream',
          file_size: typeof att.file_size === 'number' ? att.file_size : null,
        }));

      if (attachmentRows.length > 0) {
        const { error: attachErr } = await supabaseAdmin
          .from('claim_attachments')
          .insert(attachmentRows);

        if (attachErr) {
          console.error('Error inserting attachments:', attachErr);
        }
      }
    }

    // 10. Return Successful Submission Response
    return new Response(
      JSON.stringify({
        success: true,
        claim_id: claimRecord.id,
        claim_number: claimRecord.claim_number,
        priority_score: priorityScore,
        warranty_valid: warrantyValid,
        warranty_status: warrantyStatus,
        message: 'Claim submitted and prioritized successfully',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    console.error('Unexpected error in claim-processor:', err);
    return new Response(
      JSON.stringify({ error: err?.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
