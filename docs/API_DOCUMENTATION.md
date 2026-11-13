# Claimly — Backend & API Documentation

This document provides a comprehensive technical reference for the **Claimly** backend architecture, covering the PostgreSQL relational schema, custom enums, SQL functions, triggers, performance indexes, Row Level Security (RLS) policies, storage buckets, and Supabase Edge Functions.

---

## Table of Contents
1. [Architectural Overview](#1-architectural-overview)
2. [Custom PostgreSQL Enums](#2-custom-postgresql-enums)
3. [Relational Database Schema](#3-relational-database-schema)
   - [3.1 public.profiles](#31-publicprofiles)
   - [3.2 public.products](#32-publicproducts)
   - [3.3 public.claims](#33-publicclaims)
   - [3.4 public.claim_attachments](#34-publicclaim_attachments)
   - [3.5 public.claim_timeline](#35-publicclaim_timeline)
   - [3.6 public.notifications](#36-publicnotifications)
4. [Database Performance Indexes](#4-database-performance-indexes)
5. [SQL Functions & Triggers Reference](#5-sql-functions--triggers-reference)
   - [5.1 SQL Stored Functions](#51-sql-stored-functions)
   - [5.2 Lifecycle Trigger Bindings](#52-lifecycle-trigger-bindings)
6. [Row Level Security (RLS) Policies (37 Policies)](#6-row-level-security-rls-policies-37-policies)
   - [6.1 Relational Table Policies (21 Policies)](#61-relational-table-policies-21-policies)
   - [6.2 Storage Bucket Policies (16 Policies)](#62-storage-bucket-policies-16-policies)
7. [Storage Buckets Specification](#7-storage-buckets-specification)
8. [Supabase Edge Functions API Reference](#8-supabase-edge-functions-api-reference)
   - [8.1 Global CORS & Authentication Protocols](#81-global-cors--authentication-protocols)
   - [8.2 claim-processor](#82-claim-processor)
   - [8.3 warranty-expiry-checker](#83-warranty-expiry-checker)
   - [8.4 claim-analytics](#84-claim-analytics)
   - [8.5 export-claim-report](#85-export-claim-report)

---

## 1. Architectural Overview

Claimly leverages **Supabase** (PostgreSQL 17.11) as its unified backend data platform, utilizing:
- **PostgREST**: Generates instant, type-safe RESTful APIs directly from the relational schema with automatic Swagger/OpenAPI introspection.
- **GoTrue Auth**: Manages JSON Web Token (JWT) issuing, identity hashing (bcrypt), password reset tokens, and federated Google OAuth logins.
- **Supabase Realtime**: Change Data Capture (CDC) engine broadcasting PostgreSQL database mutations (`INSERT`, `UPDATE`, `DELETE`) over secure WebSocket channels.
- **Supabase Storage**: S3-compatible binary blob storage with RLS path security.
- **Supabase Edge Functions**: Deno/TypeScript serverless functions for computationally intensive business logic (triage scoring, daily cron evaluation, report compilation).

---

## 2. Custom PostgreSQL Enums

The database schema defines 4 strongly-typed custom enums in the `public` schema:

```sql
CREATE TYPE public.user_role AS ENUM ('customer', 'admin');
CREATE TYPE public.claim_type AS ENUM ('warranty', 'refund', 'replacement');
CREATE TYPE public.claim_status AS ENUM ('draft', 'submitted', 'under_review', 'approved', 'rejected', 'completed');
CREATE TYPE public.notification_type AS ENUM ('warranty_expiry', 'claim_update', 'system');
```

### Descriptions:
- **`user_role`**: Defines authorization tier. `'customer'` denotes standard end-users; `'admin'` denotes store operators with global claim review and analytics privileges.
- **`claim_type`**: Legal remedy requested by user:
  - `'warranty'`: Manufacturer or service-center repair.
  - `'refund'`: Financial reimbursement or store credit.
  - `'replacement'`: Exchange for an identical or equivalent unit.
- **`claim_status`**: Lifecycle phase:
  - `'draft'`: Incomplete claim saved by user.
  - `'submitted'`: Submitted to store queue and prioritized.
  - `'under_review'`: Under active administrative investigation.
  - `'approved'`: Authorized for resolution.
  - `'rejected'`: Denied with explanation.
  - `'completed'`: Fulfillment finalized.
- **`notification_type`**: Classification of in-app alert:
  - `'warranty_expiry'`: Scheduled countdown alert (30/7/1 days).
  - `'claim_update'`: Administrative adjudication update.
  - `'system'`: Global operational alert.

---

## 3. Relational Database Schema

### 3.1 `public.profiles`
Extends `auth.users` with user roles and contact information.

| Column | Data Type | Nullable | Default | Foreign Key & Description |
|---|---|---|---|---|
| `id` | `uuid` | **NO** | *None* | `PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`. Identifies user. |
| `role` | `public.user_role` | **NO** | `'customer'::user_role` | User authorization role. Protected by trigger against unauthorized escalation. |
| `full_name` | `text` | YES | `NULL` | Customer or administrator display name. |
| `avatar_url` | `text` | YES | `NULL` | Public path to profile photo in `avatars` bucket. |
| `phone_number` | `text` | YES | `NULL` | Primary contact telephone number. |
| `created_at` | `timestamptz` | **NO** | `now()` | Record creation timestamp. |
| `updated_at` | `timestamptz` | **NO** | `now()` | Timestamp of last modification (auto-set by trigger). |

---

### 3.2 `public.products`
Stores consumer products registered by customers for warranty tracking.

| Column | Data Type | Nullable | Default | Foreign Key & Description |
|---|---|---|---|---|
| `id` | `uuid` | **NO** | `gen_random_uuid()` | `PRIMARY KEY`. Unique product identifier. |
| `user_id` | `uuid` | **NO** | *None* | `REFERENCES public.profiles(id) ON DELETE CASCADE`. Product owner. |
| `name` | `text` | **NO** | *None* | Product brand and model display name. |
| `category` | `text` | **NO** | *None* | Category (e.g., Electronics, Appliances, Automotive). |
| `brand` | `text` | YES | `NULL` | Manufacturer or brand name. |
| `model_number` | `text` | YES | `NULL` | Hardware model identifier. |
| `serial_number` | `text` | YES | `NULL` | Unique manufacturer serial number. |
| `purchase_date` | `date` | **NO** | *None* | Date of retail purchase. |
| `warranty_period_months` | `integer` | **NO** | *None* | Warranty duration in calendar months. `CHECK (warranty_period_months >= 0)`. |
| `warranty_expiry_date` | `date` | **NO** | *None* | Computed expiration date (`purchase_date + interval`). Auto-set by trigger. |
| `receipt_url` | `text` | YES | `NULL` | Path to proof of purchase in private `receipts` bucket. |
| `image_url` | `text` | YES | `NULL` | Path to product photo in public `product-images` bucket. |
| `notes` | `text` | YES | `NULL` | User notes or warranty condition details. |
| `created_at` | `timestamptz` | **NO** | `now()` | Record creation timestamp. |
| `updated_at` | `timestamptz` | **NO** | `now()` | Timestamp of last modification (auto-set by trigger). |

---

### 3.3 `public.claims`
Core claim entity tracking warranty claims, refunds, and replacements.

| Column | Data Type | Nullable | Default | Foreign Key & Description |
|---|---|---|---|---|
| `id` | `uuid` | **NO** | `gen_random_uuid()` | `PRIMARY KEY`. Unique claim identifier. |
| `claim_number` | `text` | **NO** | *None* | `UNIQUE`. Immutable identifier in format `CLM-YYYYMMDD-XXXXXX`. |
| `user_id` | `uuid` | **NO** | *None* | `REFERENCES public.profiles(id) ON DELETE CASCADE`. Filing customer. |
| `product_id` | `uuid` | **NO** | *None* | `REFERENCES public.products(id) ON DELETE CASCADE`. Defective product. |
| `type` | `public.claim_type` | **NO** | `'warranty'::claim_type` | Resolution type (`warranty`, `refund`, `replacement`). |
| `status` | `public.claim_status` | **NO** | `'draft'::claim_status` | Lifecycle status. |
| `title` | `text` | **NO** | *None* | Brief defect summary. |
| `description` | `text` | **NO** | *None* | Comprehensive symptom and incident description. |
| `issue_category` | `text` | YES | `NULL` | Defect category (Hardware Defect, Battery & Power, etc.). |
| `incident_date` | `date` | YES | `NULL` | Date failure occurred. |
| `priority` | `integer` | **NO** | `0` | Automated triage score (0-100). Customer tampering blocked. |
| `admin_notes` | `text` | YES | `NULL` | Private staff notes. Customer mutation blocked. |
| `resolution_notes`| `text` | YES | `NULL` | Customer-facing adjudication explanation. Customer mutation blocked. |
| `resolved_at` | `timestamptz` | YES | `NULL` | Auto-set when claim enters approved/rejected/completed. |
| `created_at` | `timestamptz` | **NO** | `now()` | Record creation timestamp. |
| `updated_at` | `timestamptz` | **NO** | `now()` | Timestamp of last modification (auto-set by trigger). |

---

### 3.4 `public.claim_attachments`
Stores metadata and paths for evidentiary documents and media.

| Column | Data Type | Nullable | Default | Foreign Key & Description |
|---|---|---|---|---|
| `id` | `uuid` | **NO** | `gen_random_uuid()` | `PRIMARY KEY`. Unique attachment identifier. |
| `claim_id` | `uuid` | **NO** | *None* | `REFERENCES public.claims(id) ON DELETE CASCADE`. Parent claim. |
| `file_url` | `text` | **NO** | *None* | Storage path in `claim-attachments` bucket. |
| `file_name` | `text` | **NO** | *None* | Original uploaded file name. |
| `file_type` | `text` | YES | `NULL` | MIME format (e.g., `image/jpeg`, `application/pdf`). |
| `file_size` | `integer` | YES | `NULL` | Binary file size in bytes. |
| `created_at` | `timestamptz` | **NO** | `now()` | Upload timestamp. |

---

### 3.5 `public.claim_timeline`
Append-only audit ledger recording claim state transitions.

| Column | Data Type | Nullable | Default | Foreign Key & Description |
|---|---|---|---|---|
| `id` | `uuid` | **NO** | `gen_random_uuid()` | `PRIMARY KEY`. Unique audit entry identifier. |
| `claim_id` | `uuid` | **NO** | *None* | `REFERENCES public.claims(id) ON DELETE CASCADE`. Parent claim. |
| `from_status` | `public.claim_status` | YES | `NULL` | Previous status (NULL on initial filing). |
| `to_status` | `public.claim_status` | **NO** | *None* | New updated status. |
| `changed_by` | `uuid` | YES | `NULL` | `REFERENCES public.profiles(id) ON DELETE SET NULL`. Actor UUID. |
| `notes` | `text` | YES | `NULL` | Operational narrative or adjudication reason. |
| `created_at` | `timestamptz` | **NO** | `now()` | Transition timestamp. |

---

### 3.6 `public.notifications`
In-app and push notification feed for expiration reminders and claim status updates.

| Column | Data Type | Nullable | Default | Foreign Key & Description |
|---|---|---|---|---|
| `id` | `uuid` | **NO** | `gen_random_uuid()` | `PRIMARY KEY`. Unique notification identifier. |
| `user_id` | `uuid` | **NO** | *None* | `REFERENCES public.profiles(id) ON DELETE CASCADE`. Recipient. |
| `claim_id` | `uuid` | YES | `NULL` | `REFERENCES public.claims(id) ON DELETE CASCADE`. Optional claim reference. |
| `type` | `public.notification_type` | **NO** | *None* | Notification category. |
| `title` | `text` | **NO** | *None* | Short headline. |
| `message` | `text` | **NO** | *None* | Full message body. |
| `is_read` | `boolean` | **NO** | `false` | Read status flag. |
| `metadata` | `jsonb` | **NO** | `'{}'::jsonb`| Contextual JSON payload (e.g., milestones, transition IDs). |
| `created_at` | `timestamptz` | **NO** | `now()` | Notification timestamp. |

---

## 4. Database Performance Indexes

The schema includes 13 dedicated B-tree performance indexes:

1. `idx_profiles_role`: `ON public.profiles(role)` — Optimizes role lookups and admin verification.
2. `idx_products_user_id`: `ON public.products(user_id)` — Filters products by owner in `<10ms`.
3. `idx_products_warranty_expiry`: `ON public.products(warranty_expiry_date)` — Powers the daily cron query.
4. `idx_claims_user_id`: `ON public.claims(user_id)` — Filters customer claim lists.
5. `idx_claims_product_id`: `ON public.claims(product_id)` — Rapid lookup of claims per product.
6. `idx_claims_status`: `ON public.claims(status)` — Accelerates admin queue filtering by status.
7. `idx_claims_created_at`: `ON public.claims(created_at DESC)` — Orders chronological claim feeds.
8. `idx_claim_attachments_claim_id`: `ON public.claim_attachments(claim_id)` — Joins attachments to parent claim.
9. `idx_claim_timeline_claim_id_created`: `ON public.claim_timeline(claim_id, created_at ASC)` — Renders chronological status audit trail.
10. `idx_notifications_user_id`: `ON public.notifications(user_id)` — Filters alerts for authenticated user.
11. `idx_notifications_user_unread`: `ON public.notifications(user_id, is_read) WHERE is_read = false` — Partial index optimizing unread badge count computation.
12. `idx_notifications_claim_id`: `ON public.notifications(claim_id)` — Cascadable claim link index.
13. `idx_notifications_created_at`: `ON public.notifications(created_at DESC)` — Orders alert feeds.

---

## 5. SQL Functions & Triggers Reference

### 5.1 SQL Stored Functions

| # | Function Name | Return Type | Volatility & Security | Operational Logic |
|---|---|---|---|---|
| 1 | `calculate_warranty_expiry(p_purchase_date date, p_months integer)` | `date` | `IMMUTABLE LANGUAGE sql` | Computes `(p_purchase_date + (p_months * INTERVAL '1 month'))::date`. |
| 2 | `handle_updated_at()` | `trigger` | `VOLATILE LANGUAGE plpgsql` | Sets `NEW.updated_at = now()`. |
| 3 | `is_admin(check_user_id uuid DEFAULT auth.uid())` | `boolean` | `STABLE SECURITY DEFINER SET search_path = public` | Returns `true` if target profile has `role = 'admin'`. Prevents RLS recursion. |
| 4 | `handle_product_warranty_expiry()` | `trigger` | `VOLATILE LANGUAGE plpgsql` | Sets `NEW.warranty_expiry_date = calculate_warranty_expiry(NEW.purchase_date, NEW.warranty_period_months)`. |
| 5 | `handle_generate_claim_number()` | `trigger` | `VOLATILE SECURITY DEFINER SET search_path = public` | Auto-generates `CLM-YYYYMMDD-XXXXXX` on insert; preserves existing number on update. |
| 6 | `handle_claim_resolved_at()` | `trigger` | `VOLATILE LANGUAGE plpgsql` | Sets `NEW.resolved_at = now()` when status enters `approved`/`rejected`/`completed`. |
| 7 | `handle_claim_status_change()` | `trigger` | `VOLATILE SECURITY DEFINER SET search_path = public` | Inserts an immutable transition record into `public.claim_timeline`. |
| 8 | `handle_notify_claim_update()` | `trigger` | `VOLATILE SECURITY DEFINER SET search_path = public` | Creates a row in `public.notifications` notifying user of claim status change. |
| 9 | `handle_protect_user_role()` | `trigger` | `VOLATILE SECURITY DEFINER SET search_path = public` | Blocks non-admin callers from modifying `role` in `public.profiles`. |
| 10 | `handle_new_user()` | `trigger` | `VOLATILE SECURITY DEFINER SET search_path = public` | Auto-provisions a `public.profiles` row upon new registration in `auth.users`. |
| 11 | `handle_protect_claim_admin_fields()`| `trigger` | `VOLATILE SECURITY DEFINER SET search_path = public` | Blocks customer callers from setting non-zero priority, admin notes, or non-draft/submitted status. |

### 5.2 Lifecycle Trigger Bindings

1. `set_profiles_updated_at`: `BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION handle_updated_at()`
2. `set_products_updated_at`: `BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION handle_updated_at()`
3. `set_claims_updated_at`: `BEFORE UPDATE ON public.claims FOR EACH ROW EXECUTE FUNCTION handle_updated_at()`
4. `set_product_warranty_expiry`: `BEFORE INSERT OR UPDATE OF purchase_date, warranty_period_months, warranty_expiry_date ON public.products FOR EACH ROW EXECUTE FUNCTION handle_product_warranty_expiry()`
5. `generate_claim_number`: `BEFORE INSERT OR UPDATE ON public.claims FOR EACH ROW EXECUTE FUNCTION handle_generate_claim_number()`
6. `set_claim_resolved_at`: `BEFORE UPDATE OF status ON public.claims FOR EACH ROW EXECUTE FUNCTION handle_claim_resolved_at()`
7. `log_claim_creation`: `AFTER INSERT ON public.claims FOR EACH ROW EXECUTE FUNCTION handle_claim_status_change()`
8. `log_claim_status_change`: `AFTER UPDATE OF status ON public.claims FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION handle_claim_status_change()`
9. `notify_claim_update`: `AFTER UPDATE OF status ON public.claims FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION handle_notify_claim_update()`
10. `protect_user_role`: `BEFORE INSERT OR UPDATE OF role ON public.profiles FOR EACH ROW EXECUTE FUNCTION handle_protect_user_role()`
11. `on_auth_user_created`: `AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user()`
12. `protect_claim_admin_fields`: `BEFORE INSERT OR UPDATE ON public.claims FOR EACH ROW EXECUTE FUNCTION handle_protect_claim_admin_fields()`

---

## 6. Row Level Security (RLS) Policies (37 Policies)

### 6.1 Relational Table Policies (21 Policies)

#### `public.profiles` (3 Policies)
- **`profiles_select_own_or_admin`** (`FOR SELECT`):
  `USING (auth.uid() = id OR public.is_admin(auth.uid()))`
- **`profiles_insert_own_or_admin`** (`FOR INSERT`):
  `WITH CHECK ((auth.uid() = id AND role = 'customer'::public.user_role) OR public.is_admin(auth.uid()))`
- **`profiles_update_own_or_admin`** (`FOR UPDATE`):
  `USING (auth.uid() = id OR public.is_admin(auth.uid())) WITH CHECK (auth.uid() = id OR public.is_admin(auth.uid()))`

#### `public.products` (4 Policies)
- **`products_select_own_or_admin`** (`FOR SELECT`):
  `USING (auth.uid() = user_id OR public.is_admin(auth.uid()))`
- **`products_insert_own`** (`FOR INSERT`):
  `WITH CHECK (auth.uid() = user_id)`
- **`products_update_own_or_admin`** (`FOR UPDATE`):
  `USING (auth.uid() = user_id OR public.is_admin(auth.uid())) WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()))`
- **`products_delete_own_or_admin`** (`FOR DELETE`):
  `USING (auth.uid() = user_id OR public.is_admin(auth.uid()))`

#### `public.claims` (4 Policies)
- **`claims_select_own_or_admin`** (`FOR SELECT`):
  `USING (auth.uid() = user_id OR public.is_admin(auth.uid()))`
- **`claims_insert_own`** (`FOR INSERT`):
  `WITH CHECK ((auth.uid() = user_id AND status IN ('draft'::public.claim_status, 'submitted'::public.claim_status) AND admin_notes IS NULL AND resolution_notes IS NULL AND resolved_at IS NULL AND priority = 0 AND (EXISTS (SELECT 1 FROM public.products p WHERE p.id = claims.product_id AND p.user_id = auth.uid()))) OR public.is_admin(auth.uid()))`
- **`claims_update_draft_or_admin`** (`FOR UPDATE`):
  `USING ((auth.uid() = user_id AND status = 'draft'::public.claim_status) OR public.is_admin(auth.uid())) WITH CHECK ((auth.uid() = user_id AND status IN ('draft'::public.claim_status, 'submitted'::public.claim_status) AND admin_notes IS NULL AND resolution_notes IS NULL AND resolved_at IS NULL AND priority = 0) OR public.is_admin(auth.uid()))`
- **`claims_delete_draft_or_admin`** (`FOR DELETE`):
  `USING ((auth.uid() = user_id AND status = 'draft'::public.claim_status) OR public.is_admin(auth.uid()))`

#### `public.claim_attachments` (4 Policies)
- **`attachments_select_owner_or_admin`** (`FOR SELECT`):
  `USING (EXISTS (SELECT 1 FROM public.claims c WHERE c.id = claim_attachments.claim_id AND (c.user_id = auth.uid() OR public.is_admin(auth.uid()))))`
- **`attachments_insert_owner_or_admin`** (`FOR INSERT`):
  `WITH CHECK (EXISTS (SELECT 1 FROM public.claims c WHERE c.id = claim_attachments.claim_id AND (c.user_id = auth.uid() OR public.is_admin(auth.uid()))))`
- **`attachments_update_draft_or_admin`** (`FOR UPDATE`):
  `USING (EXISTS (SELECT 1 FROM public.claims c WHERE c.id = claim_attachments.claim_id AND ((c.user_id = auth.uid() AND c.status = 'draft'::public.claim_status) OR public.is_admin(auth.uid()))))`
- **`attachments_delete_draft_or_admin`** (`FOR DELETE`):
  `USING (EXISTS (SELECT 1 FROM public.claims c WHERE c.id = claim_attachments.claim_id AND ((c.user_id = auth.uid() AND c.status = 'draft'::public.claim_status) OR public.is_admin(auth.uid()))))`

#### `public.claim_timeline` (2 Policies)
- **`timeline_select_owner_or_admin`** (`FOR SELECT`):
  `USING (EXISTS (SELECT 1 FROM public.claims c WHERE c.id = claim_timeline.claim_id AND (c.user_id = auth.uid() OR public.is_admin(auth.uid()))))`
- **`timeline_insert_admin_only`** (`FOR INSERT`):
  `WITH CHECK (public.is_admin(auth.uid()))`

#### `public.notifications` (4 Policies)
- **`notifications_select_own_or_admin`** (`FOR SELECT`):
  `USING (auth.uid() = user_id OR public.is_admin(auth.uid()))`
- **`notifications_insert_admin`** (`FOR INSERT`):
  `WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()))`
- **`notifications_update_own_or_admin`** (`FOR UPDATE`):
  `USING (auth.uid() = user_id OR public.is_admin(auth.uid())) WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()))`
- **`notifications_delete_own_or_admin`** (`FOR DELETE`):
  `USING (auth.uid() = user_id OR public.is_admin(auth.uid()))`

---

### 6.2 Storage Bucket Policies (16 Policies)

All storage policies operate on the table `storage.objects`:

#### `receipts` Bucket (Private)
- **`receipts_select_policy`**: `FOR SELECT USING (bucket_id = 'receipts' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`receipts_insert_policy`**: `FOR INSERT WITH CHECK (bucket_id = 'receipts' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`receipts_update_policy`**: `FOR UPDATE USING (bucket_id = 'receipts' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`receipts_delete_policy`**: `FOR DELETE USING (bucket_id = 'receipts' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`

#### `product-images` Bucket (Public Read)
- **`product_images_select_policy`**: `FOR SELECT USING (bucket_id = 'product-images')`
- **`product_images_insert_policy`**: `FOR INSERT WITH CHECK (bucket_id = 'product-images' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`product_images_update_policy`**: `FOR UPDATE USING (bucket_id = 'product-images' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`product_images_delete_policy`**: `FOR DELETE USING (bucket_id = 'product-images' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`

#### `claim-attachments` Bucket (Private)
- **`claim_attachments_select_policy`**: `FOR SELECT USING (bucket_id = 'claim-attachments' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`claim_attachments_insert_policy`**: `FOR INSERT WITH CHECK (bucket_id = 'claim-attachments' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`claim_attachments_update_policy`**: `FOR UPDATE USING (bucket_id = 'claim-attachments' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`claim_attachments_delete_policy`**: `FOR DELETE USING (bucket_id = 'claim-attachments' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`

#### `avatars` Bucket (Public Read)
- **`avatars_select_policy`**: `FOR SELECT USING (bucket_id = 'avatars')`
- **`avatars_insert_policy`**: `FOR INSERT WITH CHECK (bucket_id = 'avatars' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`avatars_update_policy`**: `FOR UPDATE USING (bucket_id = 'avatars' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`
- **`avatars_delete_policy`**: `FOR DELETE USING (bucket_id = 'avatars' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid())))`

---

## 7. Storage Buckets Specification

| Bucket Name | Visibility | Max Size | Allowed MIME Types | Folder Isolation Rule |
|---|---|---|---|---|
| `receipts` | **Private** | 10 MB (`10485760` bytes) | `image/jpeg`, `image/png`, `image/webp`, `application/pdf` | Path must begin with `${auth.uid()}/`. Read requires signed URL or admin JWT. |
| `product-images` | **Public** | 10 MB (`10485760` bytes) | `image/jpeg`, `image/png`, `image/webp` | Read is public; writes isolated to `${auth.uid()}/` folder. |
| `claim-attachments` | **Private** | 20 MB (`20971520` bytes) | `image/jpeg`, `image/png`, `image/webp`, `application/pdf`, `video/mp4` | Read/write isolated to `${auth.uid()}/` folder. Read requires signed URL or admin JWT. |
| `avatars` | **Public** | 5 MB (`5242880` bytes) | `image/jpeg`, `image/png`, `image/webp` | Read is public; writes isolated to `${auth.uid()}/` folder. |

---

## 8. Supabase Edge Functions API Reference

### 8.1 Global CORS & Authentication Protocols
All functions implement standard CORS headers (`supabase/functions/_shared/cors.ts`):
- `Access-Control-Allow-Origin`: `*`
- `Access-Control-Allow-Headers`: `authorization, x-client-info, apikey, content-type`
- `Access-Control-Allow-Methods`: `POST, GET, OPTIONS, PUT, DELETE, PATCH`
- Standard HTTP `OPTIONS` requests receive immediate HTTP `200 OK` preflight responses.

---

### 8.2 `claim-processor`
Evaluates warranty validity (including the 7-day grace period), computes automated triage priority scores (0-100), and submits or validates claims.

- **Endpoint**: `POST /functions/v1/claim-processor`
- **Authentication**: Required (`Authorization: Bearer <JWT>`).
- **Request Body JSON**:
```json
{
  "action": "validate", // "validate" (returns score without inserting) or "submit" (inserts claim)
  "product_id": "e5b8830f-155e-4c7b-94eb-a55e2e88a31f",
  "type": "warranty", // "warranty" | "refund" | "replacement"
  "title": "Camera sensor flickering",
  "description": "Continuous purple lines across sensor output, hazard of overheating",
  "issue_category": "Hardware Defect",
  "incident_date": "2026-11-10",
  "attachments": [
    {
      "file_url": "claim-attachments/user-uuid/flicker.png",
      "file_name": "flicker.png",
      "file_type": "image/png",
      "file_size": 240182
    }
  ]
}
```

#### Priority Scoring Algorithm:
- **Base Score**: `20`
- **Warranty Urgency**:
  - `daysRemaining <= 7`: `+30`
  - `daysRemaining <= 30`: `+15`
  - Else: `0`
- **Claim Type Bonus**:
  - `refund`: `+25`
  - `replacement`: `+20`
  - `warranty`: `+15`
- **NLP Severity Bonus**:
  - High-Risk Keywords (`fire`, `smoke`, `hazard`, `shock`, `burn`, `explosion`): `+25`
  - Moderate Keywords (`broken`, `failed`, `dead`, `cracked`, `malfunction`): `+15`
- **Completeness**:
  - `attachments.length >= 1`: `+10`
- **Clamping**: `priorityScore = Math.max(0, Math.min(100, rawTotalScore))`

#### 7-Day Grace Period Logic:
- `daysPastExpiry = incidentDate - warrantyExpiryDate`
- If `daysPastExpiry <= 0`: `warranty_status = 'valid'`, `warranty_valid = true`
- Else if `daysPastExpiry <= 7`: `warranty_status = 'in_grace_period'`, `warranty_valid = true`
- Else: `warranty_status = 'expired'`, `warranty_valid = false`

#### Success Response (`action: "validate"`):
```json
{
  "success": true,
  "action": "validate",
  "priority_score": 85,
  "warranty_valid": true,
  "warranty_status": "valid",
  "days_remaining": 4,
  "score_breakdown": {
    "base_score": 20,
    "warranty_urgency": 30,
    "claim_type": 15,
    "nlp_severity": 10,
    "completeness": 10,
    "raw_total": 85,
    "clamped_priority": 85
  },
  "message": "Claim validated and priority scored successfully"
}
```

#### Success Response (`action: "submit"`):
```json
{
  "success": true,
  "claim_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "claim_number": "CLM-20261112-9A4B1C",
  "priority_score": 85,
  "warranty_valid": true,
  "warranty_status": "valid",
  "message": "Claim submitted and prioritized successfully"
}
```

---

### 8.3 `warranty-expiry-checker`
Daily cron inspection identifying products expiring at 30, 7, and 1-day milestones and issuing deduplicated alerts.

- **Endpoint**: `POST /functions/v1/warranty-expiry-checker` (or `GET`)
- **Authentication**: Service role key or bearer token.
- **Parameters**: `base_date` (optional, `YYYY-MM-DD`, defaults to current UTC date).
- **Milestones**:
  - `30_day`: `baseDate + 30 days`
  - `7_day`: `baseDate + 7 days`
  - `1_day`: `baseDate + 1 day`
- **Deduplication**: Key `${user_id}:${product_id}:${milestone}` checked against existing notification metadata to prevent duplicate insertions.
- **Success Response**:
```json
{
  "success": true,
  "timestamp": "2026-11-12T00:00:00.000Z",
  "target_dates": {
    "30_day": "2026-12-12",
    "7_day": "2026-11-19",
    "1_day": "2026-11-13"
  },
  "notifications_created": 3,
  "breakdown": {
    "30_day": 1,
    "7_day": 1,
    "1_day": 1
  }
}
```

---

### 8.4 `claim-analytics`
Aggregates business intelligence metrics for the store administrator dashboard.

- **Endpoint**: `GET /functions/v1/claim-analytics`
- **Authentication**: Mandatory. Caller must hold `role = 'admin'` in `public.profiles`. Customers receive HTTP 403 Forbidden.
- **Success Response**:
```json
{
  "summary": {
    "total_claims": 42,
    "active_claims": 14,
    "approval_rate": 87.5,
    "avg_resolution_days": 3.8
  },
  "status_breakdown": {
    "draft": 2,
    "submitted": 8,
    "under_review": 6,
    "approved": 21,
    "rejected": 3,
    "completed": 2
  },
  "claims_by_type": {
    "warranty": 28,
    "refund": 9,
    "replacement": 5
  },
  "claims_over_time": [
    { "date": "2026-10-14", "count": 1 },
    { "date": "2026-11-12", "count": 3 }
  ],
  "top_issue_categories": [
    { "category": "Hardware Defect", "count": 18 },
    { "category": "Battery Failure", "count": 12 },
    { "category": "Screen Malfunction", "count": 7 }
  ]
}
```

---

### 8.5 `export-claim-report`
Denormalizes claim, product, customer profile, audit timeline, and attachments into a structured JSON payload for client-side PDF document compilation.

- **Endpoint**: `POST /functions/v1/export-claim-report` (or `GET ?claim_id=...`)
- **Authentication**: Mandatory. Caller must own the claim (`user_id = auth.uid()`) or hold `role = 'admin'`. Non-owners receive HTTP 403 Forbidden.
- **Request Parameters**: `claim_id` (UUID).
- **Verification Logic**:
  - `verificationCode = 'CLM-VFY-' + claimNumber.replace(/^CLM-/, '')`
  - `verificationUrl = '${SUPABASE_URL}/verify?claim=${claimNumber}&code=${verificationCode}'`
- **Success Response**:
```json
{
  "report_id": "REP-CLM-20261112-9A4B1C",
  "generated_at": "2026-11-12T20:15:00.000Z",
  "claim": {
    "id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "claim_number": "CLM-20261112-9A4B1C",
    "title": "Camera sensor flickering",
    "description": "Continuous purple lines across sensor output",
    "type": "warranty",
    "status": "approved",
    "priority": 75,
    "issue_category": "Hardware Defect",
    "incident_date": "2026-11-10",
    "admin_notes": "Verified defect against hardware recall bulletin",
    "resolution_notes": "Replacement approved under warranty terms",
    "resolved_at": "2026-11-12T14:30:00.000Z",
    "created_at": "2026-11-10T09:12:00.000Z",
    "updated_at": "2026-11-12T14:30:00.000Z"
  },
  "product": {
    "id": "e5b8830f-155e-4c7b-94eb-a55e2e88a31f",
    "user_id": "4a123456-789a-bcde-f012-3456789abcde",
    "name": "Sony Alpha 7 IV",
    "category": "Electronics",
    "brand": "Sony",
    "model_number": "ILCE-7M4",
    "serial_number": "SN-88291039",
    "purchase_date": "2026-01-15",
    "warranty_period_months": 24,
    "warranty_expiry_date": "2028-01-15",
    "receipt_url": "receipts/4a123456-789a-bcde-f012-3456789abcde/sony_receipt.pdf",
    "image_url": "product-images/4a123456-789a-bcde-f012-3456789abcde/camera.jpg"
  },
  "customer": {
    "id": "4a123456-789a-bcde-f012-3456789abcde",
    "full_name": "Jane Doe",
    "email": "jane.doe@example.com",
    "phone_number": "+1-555-0199",
    "avatar_url": "avatars/4a123456-789a-bcde-f012-3456789abcde/avatar.png"
  },
  "timeline": [
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "from_status": null,
      "to_status": "submitted",
      "notes": "Claim created with status submitted",
      "created_at": "2026-11-10T09:12:00.000Z"
    },
    {
      "id": "22222222-3333-4444-5555-666666666666",
      "from_status": "submitted",
      "to_status": "approved",
      "notes": "Claim approved by support desk",
      "created_at": "2026-11-12T14:30:00.000Z"
    }
  ],
  "attachments": [
    {
      "id": "33333333-4444-5555-6666-777777777777",
      "file_url": "claim-attachments/4a123456-789a-bcde-f012-3456789abcde/flicker_sample.png",
      "file_name": "flicker_sample.png",
      "file_type": "image/png",
      "file_size": 240182
    }
  ],
  "verification": {
    "verification_code": "CLM-VFY-20261112-9A4B1C",
    "verification_url": "https://kvxfkfgzsapvvswjcmzj.supabase.co/verify?claim=CLM-20261112-9A4B1C&code=CLM-VFY-20261112-9A4B1C"
  }
}
```
