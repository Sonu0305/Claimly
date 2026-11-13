# Claimly — End-User & Administrator Manual

Welcome to the **Claimly** User Manual. Claimly is an automated warranty and refund claim assistant engineered to streamline consumer product warranties, eliminate expired coverage losses, and accelerate claim resolution through transparent triage algorithms.

This manual provides detailed screen-by-screen walkthroughs for both **Customers** and **Store Administrators**, along with a comprehensive troubleshooting and FAQ section.

---

## Table of Contents
1. [Customer User Guide](#1-customer-user-guide)
   - [1.1 Account Onboarding & Authentication](#11-account-onboarding--authentication)
   - [1.2 Customer Dashboard & Expiry Alerts](#12-customer-dashboard--expiry-alerts)
   - [1.3 Product Vault & Receipt Management](#13-product-vault--receipt-management)
   - [1.4 The 5-Step Claim Filing Wizard](#14-the-5-step-claim-filing-wizard)
   - [1.5 Claim Tracking, Realtime Timeline & Status Lifecycle](#15-claim-tracking-realtime-timeline--status-lifecycle)
   - [1.6 Exporting Official PDF Claim Dossiers](#16-exporting-official-pdf-claim-dossiers)
   - [1.7 Notification Feed & Realtime Alerts](#17-notification-feed--realtime-alerts)
   - [1.8 Profile Management & Dark Mode Toggle](#18-profile-management--dark-mode-toggle)
2. [Administrator Operations Guide](#2-administrator-operations-guide)
   - [2.1 Administrator Access & Role-Based Navigation](#21-administrator-access--role-based-navigation)
   - [2.2 Admin Analytics Dashboard & KPI Visualizations](#22-admin-analytics-dashboard--kpi-visualizations)
   - [2.3 Claims Review Queue & Adjudication Workflow](#23-claims-review-queue--adjudication-workflow)
   - [2.4 User Directory & Customer Inspection](#24-user-directory--customer-inspection)
3. [Frequently Asked Questions & Troubleshooting (10 Scenarios)](#3-frequently-asked-questions--troubleshooting)

---

## 1. Customer User Guide

### 1.1 Account Onboarding & Authentication
The authentication suite ensures secure access while persisting user sessions across application restarts.

- **Splash Screen**: On application launch, Claimly displays the shield brand logo while evaluating existing authentication sessions via Supabase GoTrue. Authenticated users are automatically routed to `/customer/home` (or `/admin/dashboard` if an admin), while unauthenticated users are directed to `/login`.
- **User Registration (`/register`)**:
  - Enter your **Full Name**, **Email Address**, **Password** (minimum 6 characters), and **Confirm Password**.
  - Inline validation checks verify proper email format and password matching.
  - Upon submission, an account is created in `auth.users`, and an automated database trigger (`handle_new_user`) provisions your public customer profile.
- **Login (`/login`)**:
  - Sign in using your registered email and password. A password visibility toggle (eye icon) enables character inspection.
  - Alternatively, select **Sign in with Google** for single-click OAuth federated authentication.
- **Forgot Password (`/forgot-password`)**:
  - Enter your email address to receive a secure password reset link dispatched via Supabase Auth.

---

### 1.2 Customer Dashboard & Expiry Alerts
The home dashboard (`/customer/home`) serves as your warranty mission control center:

- **Personalized Header**: Greets you by name and summarizes your current protection status.
- **2x2 KPI Metric Grid**:
  - **Active Warranties**: Total number of registered products currently within their warranty term.
  - **Expiring Soon**: Products with warranties lapsing within 30 days.
  - **Pending Claims**: Filings currently under review by the claims adjudication team.
  - **Resolved Claims**: Historical claims successfully approved and settled.
  - *Interaction*: Tapping any KPI card navigates directly to the filtered products or claims view.
- **Expiry Carousel (`ExpiryAlertCard`)**:
  - Highlights products requiring urgent attention before coverage terminates.
  - Categorized into three dynamic urgency tiers:
    - **Critical (≤1 Day Left)**: Red border, high-urgency banner ("Critical: Warranty Expires Tomorrow!"), and direct "File Claim" shortcut.
    - **Urgent (≤7 Days Left)**: Orange border, "Urgent: Warranty Expiring This Week", and direct "File Claim" button.
    - **Warning (≤30 Days Left)**: Amber alert border reminding you to inspect the product.
- **Quick Actions**: Prominent buttons to immediately register a new product or launch the claim filing wizard.
- **Recent Claims Feed**: Chronological list of your active claims with live status badges.

---

### 1.3 Product Vault & Receipt Management
Maintain a permanent digital vault for all your consumer electronics, home appliances, and equipment.

- **Product Registration Form (`/customer/products/new`)**:
  - **Product Name**: Required (e.g., "Sony Alpha 7 IV", "MacBook Pro 16\"").
  - **Category**: Select from *Electronics*, *Appliances*, *Furniture*, *Automotive*, or *Other*.
  - **Brand & Model/Serial Number**: Optional identifiers essential for warranty processing.
  - **Purchase Date**: Selected via native calendar DatePicker.
  - **Warranty Period (Months)**: Enter duration from 1 to 120 months.
  - **Live Warranty Expiry Preview**: The interface dynamically calculates and renders your exact expiration date and countdown status in real time before saving.
  - **Receipt Upload**: Upload PDF, PNG, or JPG purchase receipts. The file is encrypted and saved into the private `receipts` storage bucket under your secure user folder with a 7-day signed URL.
  - **Product Photo**: Optional photo stored in the `product-images` bucket.
- **Product Catalog (`/customer/products`)**:
  - Realtime search bar filtering across name, brand, model, and serial number.
  - Filter chips allowing one-tap switching between *All*, *Active*, *Expiring Soon*, and *Expired*.
- **Product Detail View (`/customer/products/:id`)**:
  - Full product specifications, circular countdown timer showing remaining days, secure receipt download link, and a direct button to launch a pre-populated claim wizard.

---

### 1.4 The 5-Step Claim Filing Wizard
When a product fails, Claimly's 5-step stepper wizard (`/customer/claims/new`) guides you through an intuitive filing process:

```
[ Step 1: Product ] -> [ Step 2: Claim Type ] -> [ Step 3: Issue Details ] -> [ Step 4: Proof Attachments ] -> [ Step 5: Triage & Submit ]
```

#### Step 1: Select Registered Product (`StepProductSelection`)
- Choose the defective item from your registered product catalog.
- If launched from a product detail page, the item is pre-selected automatically.
- Displays current warranty status. The "Next Step" button remains disabled until a product is selected.

#### Step 2: Choose Claim Resolution Type (`StepClaimType`)
Select the appropriate legal resolution for your situation:
1. **Warranty Repair (`warranty`)**: Request manufacturer or authorized repair for internal component failure or defect.
2. **Product Replacement (`replacement`)**: Request an exchange for an identical or equivalent model due to irreparable failure.
3. **Full or Partial Refund (`refund`)**: Claim financial compensation for defective, recalled, or non-functional items.

#### Step 3: Issue Description & Incident Date (`StepIssueDetails`)
- **Issue Title**: Short summary of the defect (minimum 5 characters).
- **Issue Category**: Select from *Hardware Defect*, *Software Glitch*, *Physical Damage*, *Missing Parts*, *Battery & Power*, or *Other*.
- **Incident Date**: The calendar date when the failure occurred. Validation prevents selecting future dates or dates preceding the product's purchase date.
- **Detailed Description**: Comprehensive explanation of the defect symptoms, error codes, and operational impact.
- **Safety NLP Callout**: Explains that mentioning hazardous conditions (such as *fire*, *smoke*, *hazard*, *burn*, *shock*, *explosion*) automatically triggers urgent priority escalation.

#### Step 4: Upload Supporting Evidence (`StepAttachments`)
- Attach photos, diagnostic reports, repair invoices, or short video clips demonstrating the defect.
- Accepted formats: JPG, PNG, WEBP, PDF, and MP4 up to 20MB per file.
- **Priority Boost Banner**: Informs you that attaching evidence awards an automatic +10 Priority Score bonus during automated triage.

#### Step 5: Automated Triage Review & Submission (`StepReviewSubmit`)
- Evaluates the claim against the backend `claim-processor` Edge Function.
- **Automated Triage Score Card**:
  - Displays the computed **Priority Score (0-100)**:
    - *High Priority (≥70)*: Flagged for expedited administrative review.
    - *Medium Priority (40-69)*: Standard processing queue.
    - *Standard Priority (<40)*: Routine review.
  - Displays **Warranty Validity**: Valid, In Grace Period (within 7 days post-expiry), or Expired.
- Review all summary cards before confirming.
- **Submit Official Claim**: Features double-tap idempotency protection and instantly routes to the live claim tracker.

---

### 1.5 Claim Tracking, Realtime Timeline & Status Lifecycle
Every claim progresses through a transparent, audited lifecycle:

```
[ Draft ] -> [ Submitted ] -> [ Under Review ] -> [ Approved / Rejected ] -> [ Completed ]
```

- **Claim Detail Screen (`/customer/claims/:id`)**:
  - Displays your unique Claim Number (e.g., `CLM-20261112-9A4B1C`), claim type, priority score badge, and filing date.
  - **Resolution Banner**: When approved, displays a green card containing the administrator's official resolution notes and return authorization numbers.
- **Realtime Status Timeline (`ClaimTimelineWidget`)**:
  - Live vertical audit trail synchronized via Supabase Realtime WebSocket channels.
  - Every status change made by an administrator immediately updates your screen without needing a manual refresh.
  - Displays timestamp, previous status, updated status, and staff notes for complete transparency.

---

### 1.6 Exporting Official PDF Claim Dossiers
Claimly includes a client-side document compiler (`ClaimPdfService`) powered by the `pdf` and `printing` libraries:

- **How to Export**:
  - Open any claim detail screen and tap the **PDF Icon** in the top navigation bar or the **"Export Official Claim PDF"** button.
- **Document Structure (ISO A4 Standard)**:
  1. **Branded Header**: Deep Indigo banner with official Claimly branding, Report ID (`RPT-CLM-...`), and generation timestamp.
  2. **Claim & Priority Card**: Official status badge, priority score, and resolution type.
  3. **Two-Column Metadata**: Customer contact details paired side-by-side with product specifications (serial number, purchase date, warranty expiration).
  4. **Defect Narrative**: Complete description of symptoms, incident date, and administrative resolution findings.
  5. **Timeline Audit Trail**: Tabular ledger listing every lifecycle transition with dates and authorization details.
  6. **Evidence Index**: Table of attached files with filenames, formats, and sizes.
  7. **Anti-Fraud Security Footer**:
     - Embedded 60x60pt 2D **QR Code** linking to the claim verification URL.
     - **Verification Code**: Monospace `CLM-VFY-YYYYMMDD-XXXXXX`.
     - **Cryptographic Hash**: `SHA256-${claimNumber}` courier verification stamp.
- **Printing & Sharing**:
  - Directly print to your physical printer or share via email, AirDrop, or messaging apps.

---

### 1.7 Notification Feed & Realtime Alerts
The Notification Center (`/customer/notifications`) alerts you to critical events:

- **Warranty Expiry Alerts**: Triggered automatically by the daily cron engine at **30 days**, **7 days**, and **1 day** prior to product expiration.
- **Claim Updates**: Triggered instantaneously whenever an administrator updates the status or notes of your claim.
- **Filter Chips**: Filter by *All*, *Unread*, *Warranty Expirations*, or *Claim Updates*.
- **Quick Actions**: Mark all notifications as read or swipe to dismiss individual cards.

---

### 1.8 Profile Management & Dark Mode Toggle
Customize your experience in the Profile tab (`/customer/profile`):

- **User Statistics**: Quick metrics displaying your total registered products, active warranties, and submitted claims.
- **Edit Profile**: Update your Full Name and Phone Number.
- **Theme Mode Toggle**:
  - Switch seamlessly between **Light Mode** (Deep Indigo & crisp Slate background) and **Dark Mode** (OLED-friendly Slate 900 background).
  - Your theme preference is cached in local device storage via `SharedPreferences` and restored on every app restart.
- **Administrator Shortcut**: If your account has administrative privileges, a purple "Admin Mode" banner provides one-tap entry to the Admin Console.
- **Sign Out**: Clears cached authentication tokens and returns safely to the login screen.

---

## 2. Administrator Operations Guide

### 2.1 Administrator Access & Role-Based Navigation
- **Security Guardrails**: Access to administrative routes (`/admin/*`) is strictly guarded by GoRouter redirect logic and PostgreSQL Row Level Security. Standard customers attempting to access `/admin/dashboard` are automatically bounced back to `/customer/home`.
- **Admin Shell Navigation**:
  - **Analytics**: High-level KPI metrics, trends, and failure categories.
  - **Claims Review**: Filterable queue for inspecting and adjudicating claims.
  - **Users**: Directory of registered customers and administrators.
  - **Customer View**: Top-right app bar button allowing administrators to switch into the customer perspective.

---

### 2.2 Admin Analytics Dashboard & KPI Visualizations
Located at `/admin/dashboard`, powered by the `claim-analytics` Edge Function and rendered with interactive `fl_chart` widgets:

- **4 KPI Metric Cards**:
  1. **Total Claims**: Lifetime volume of claims processed.
  2. **Active Claims**: Claims currently awaiting review (`submitted` or `under_review`).
  3. **Approval Rate**: Percentage of processed claims resolved as approved.
  4. **Avg Resolution Time**: Average elapsed time in days from submission to final resolution.
- **Status Breakdown (Donut Pie Chart)**:
  - Visual distribution of claims across *Submitted* (Blue), *Under Review* (Purple), *Approved* (Green), *Rejected* (Red), and *Completed* (Teal).
- **Claims by Resolution Type (Bar Chart)**:
  - Side-by-side volume comparison of *Warranty Repairs*, *Product Replacements*, and *Cash Refunds*.
- **30-Day Submission Trend (Curved Line Chart)**:
  - Daily filing volume over the past month with gradient shading, highlighting submission surges.
- **Top Issue Categories**:
  - Ranked bar list showing the most prevalent defect types (e.g., Hardware Defect, Battery & Power, Software Glitch).

---

### 2.3 Claims Review Queue & Adjudication Workflow
Review and adjudicate claims via `/admin/claims`:

- **Search & Filter Controls**:
  - Search by claim number, customer name, or defect title.
  - Filter chips: *All*, *Under Review*, *Approved*, *Rejected*, *Completed*.
  - Priority chips: Highlight urgent filings with high triage scores (≥70).
- **Adjudicating a Claim (`/admin/claims/:id`)**:
  1. **Examine Evidence**: Inspect product details, purchase date, warranty expiration date, failure description, and uploaded receipts/photos.
  2. **Status Dropdown**:
     - *Under Review*: Acknowledges claim receipt and initiates staff investigation.
     - *Approved*: Approves repair, replacement, or refund.
     - *Rejected*: Denies claim (e.g., out of warranty, unauthorized modification).
     - *Completed*: Marks claim as fulfilled and closed.
  3. **Priority Slider**: Override the automated priority score (0-100) if manual review reveals higher urgency.
  4. **Internal Admin Notes**: Record private staff notes for audit compliance.
  5. **Resolution Explanation**: Customer-facing explanation (e.g., "Work order #WO-99281 issued. Replacement unit dispatched via FedEx #771928410").
  6. **Submit Decision**: Updates the database, generates a timeline entry, and dispatches a realtime notification to the customer.

---

### 2.4 User Directory & Customer Inspection
Located at `/admin/users`:

- Inspect the directory of all registered users.
- Search by customer name, email, or phone number.
- Filter by role (*Customer* or *Admin*).
- Profile cards show registered date, assigned role, total products owned, and total claims submitted.

---

## 3. Frequently Asked Questions & Troubleshooting

### Q1: Why can't I sign in after registering a new account?
- **Root Cause**: Supabase Auth may require email address confirmation depending on project settings. Alternatively, credentials may contain a typo.
- **Resolution**: Check your email inbox and spam folder for the Claimly verification email. If forgotten, tap "Forgot Password?" on the login screen to receive a secure password reset link.

### Q2: Why does uploading my receipt or proof attachment fail?
- **Root Cause**: The file exceeds the 20MB file size limit or is in an unsupported file format.
- **Resolution**: Ensure your file is under 20MB. Supported formats include JPG, PNG, WEBP, PDF, and MP4. For large documents, compress the PDF or resize photos before uploading.

### Q3: Can I file a claim if my warranty expired a few days ago?
- **Root Cause**: Standard warranties expire strictly on the calculated expiration date.
- **Resolution**: Claimly provides an automated **7-day grace period**. If your failure incident occurred within 7 calendar days after warranty expiration, the system accepts the filing as `in_grace_period` with valid coverage. Incidents occurring beyond 7 days post-expiry are marked as expired.

### Q4: How is the claim Priority Score (0-100) calculated?
- **Root Cause**: Customers want insight into automated triage queue prioritization.
- **Resolution**: The `claim-processor` engine evaluates five transparent criteria:
  1. *Base Score*: +20 points.
  2. *Warranty Urgency*: +30 points if expiring within 7 days; +15 points if within 30 days.
  3. *Resolution Type*: +25 points for refund; +20 for replacement; +15 for repair.
  4. *Safety & Severity NLP*: +25 points for safety hazards (*fire*, *smoke*, *hazard*, *shock*, *burn*); +15 for severe failures (*broken*, *dead*, *failed*).
  5. *Completeness*: +10 points if supporting proof attachments are provided.
  - Scores are mathematically clamped between 0 and 100. Scores ≥70 receive expedited High Priority review.

### Q5: Why can't I access the Administrator Portal?
- **Root Cause**: Your account is assigned the standard `customer` role.
- **Resolution**: Administrative routes are protected by role-based guards. To obtain admin privileges, an existing system administrator must update your profile role to `'admin'` in the `public.profiles` database table.

### Q6: How do I export and share an official PDF of my claim?
- **Root Cause**: Third-party repair providers or retailers require a formal paper document.
- **Resolution**: Navigate to your claim detail screen (`/customer/claims/:id`), tap the PDF icon in the top app bar or scroll down to tap "Export Official Claim PDF". The system generates an ISO A4 PDF complete with metadata, timeline audit log, and anti-fraud QR verification code.

### Q7: When will I receive warranty expiration reminders?
- **Root Cause**: Forgetting deadlines results in lapsed warranty coverage.
- **Resolution**: The automated `warranty-expiry-checker` cron job evaluates your products daily. Proactive alerts are posted to your notification center at **30 days**, **7 days**, and **1 day** prior to expiration.

### Q8: What should I do if my claim is placed "Under Review"?
- **Root Cause**: The claims support team is verifying product warranty eligibility or assessing defect evidence.
- **Resolution**: Check the claim detail timeline for any staff notes. If additional photos or diagnostic documentation are requested, contact support or upload supplementary evidence.

### Q9: Does Claimly work without an active internet connection?
- **Root Cause**: Spotty cellular reception in retail stores or transit.
- **Resolution**: Claimly caches your local UI preferences and dark mode settings offline. However, searching products, submitting new claims, uploading receipts, and receiving realtime timeline updates require an active internet connection to communicate with Supabase.

### Q10: How do I switch between Light and Dark mode?
- **Root Cause**: Customizing visual comfort for bright sunlight or low-light environments.
- **Resolution**: Open the Profile tab (`/customer/profile`), navigate to "Preferences & Theme", and toggle the "Theme Mode" switch. The theme applies instantly and is saved to local device storage.
