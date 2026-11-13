// Supabase Edge Function: warranty-expiry-checker
// Scheduled daily cron function to notify users of warranties expiring in 30, 7, and 1 day(s).
// Queries products, deduplicates against existing notifications, and inserts notification records.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';
import { corsHeaders, handleCors } from '../_shared/cors.ts';

function formatUtcDate(d: Date): string {
  return d.toISOString().split('T')[0];
}

function addDaysUtc(baseDate: Date, days: number): string {
  const d = new Date(Date.UTC(baseDate.getUTCFullYear(), baseDate.getUTCMonth(), baseDate.getUTCDate() + days));
  return formatUtcDate(d);
}

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
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    // Admin client to query across all products and write notifications
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    });

    // 2. Determine Base Date (allow custom base_date via query param or body for testing)
    let baseDate = new Date();
    const url = new URL(req.url);
    const queryBaseDate = url.searchParams.get('base_date');

    if (queryBaseDate) {
      baseDate = new Date(queryBaseDate);
    } else if (req.method === 'POST') {
      try {
        const body = await req.json();
        if (body?.base_date) {
          baseDate = new Date(body.base_date);
        }
      } catch {
        // Body was empty or non-JSON; continue with current date
      }
    }

    // 3. Compute Target Milestone Expiry Dates
    const target30 = addDaysUtc(baseDate, 30);
    const target7 = addDaysUtc(baseDate, 7);
    const target1 = addDaysUtc(baseDate, 1);

    const targetDates = [target30, target7, target1];

    // 4. Query Products Expiring on Target Dates
    const { data: products, error: prodErr } = await supabaseAdmin
      .from('products')
      .select('id, user_id, name, brand, model_number, warranty_expiry_date')
      .in('warranty_expiry_date', targetDates);

    if (prodErr) {
      console.error('Error fetching expiring products:', prodErr);
      return new Response(
        JSON.stringify({ error: `Failed to fetch products: ${prodErr.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!products || products.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          timestamp: new Date().toISOString(),
          target_dates: { '30_day': target30, '7_day': target7, '1_day': target1 },
          notifications_created: 0,
          breakdown: { '30_day': 0, '7_day': 0, '1_day': 0 },
          message: 'No products expiring on target milestone dates',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Query Existing Notifications for Deduplication
    const userIds = [...new Set(products.map((p) => p.user_id))];
    const { data: existingNotifs, error: notifErr } = await supabaseAdmin
      .from('notifications')
      .select('id, user_id, metadata')
      .eq('type', 'warranty_expiry')
      .in('user_id', userIds);

    if (notifErr) {
      console.error('Error fetching existing notifications for deduplication:', notifErr);
    }

    const existingSet = new Set<string>();
    if (existingNotifs) {
      for (const n of existingNotifs) {
        const meta = n.metadata as Record<string, any> | null;
        if (meta?.product_id && meta?.milestone) {
          existingSet.add(`${n.user_id}:${meta.product_id}:${meta.milestone}`);
        }
      }
    }

    // 6. Build Notifications to Insert
    const newNotifications: any[] = [];
    const breakdown = {
      '30_day': 0,
      '7_day': 0,
      '1_day': 0,
    };

    for (const product of products) {
      let milestone: '30_day' | '7_day' | '1_day' | null = null;
      let title = '';
      let message = '';

      if (product.warranty_expiry_date === target30) {
        milestone = '30_day';
        title = `Warranty Expiring Soon: ${product.name}`;
        message = `The warranty for your ${product.name} expires in 30 days (on ${product.warranty_expiry_date}). Inspect your product and file any necessary claims before coverage ends.`;
      } else if (product.warranty_expiry_date === target7) {
        milestone = '7_day';
        title = `Urgent: 7 Days Remaining on Warranty for ${product.name}`;
        message = `Only 7 days remaining before the warranty for your ${product.name} expires on ${product.warranty_expiry_date}. Submit any open claims now!`;
      } else if (product.warranty_expiry_date === target1) {
        milestone = '1_day';
        title = `FINAL NOTICE: Warranty Expires Tomorrow for ${product.name}`;
        message = `Final reminder: Your warranty for ${product.name} expires tomorrow (${product.warranty_expiry_date}). This is your last opportunity to file a claim.`;
      }

      if (!milestone) continue;

      const dedupeKey = `${product.user_id}:${product.id}:${milestone}`;
      if (existingSet.has(dedupeKey)) {
        // Notification already sent for this milestone & product
        continue;
      }

      existingSet.add(dedupeKey);
      breakdown[milestone]++;

      newNotifications.push({
        user_id: product.user_id,
        type: 'warranty_expiry',
        title,
        message,
        is_read: false,
        metadata: {
          milestone,
          product_id: product.id,
          product_name: product.name,
          warranty_expiry_date: product.warranty_expiry_date,
        },
      });
    }

    // 7. Insert New Notifications in Batch
    if (newNotifications.length > 0) {
      const { error: insertErr } = await supabaseAdmin
        .from('notifications')
        .insert(newNotifications);

      if (insertErr) {
        console.error('Error inserting notifications:', insertErr);
        return new Response(
          JSON.stringify({ error: `Failed to insert notifications: ${insertErr.message}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 8. Return Confirmation
    return new Response(
      JSON.stringify({
        success: true,
        timestamp: new Date().toISOString(),
        target_dates: {
          '30_day': target30,
          '7_day': target7,
          '1_day': target1,
        },
        notifications_created: newNotifications.length,
        breakdown,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    console.error('Unexpected error in warranty-expiry-checker:', err);
    return new Response(
      JSON.stringify({ error: err?.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
