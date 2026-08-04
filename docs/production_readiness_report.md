# BookMyPlatter Production Readiness Report

## Scope

This audit covers the customer Flutter app, website, admin panel, Supabase schema, edge functions, storage/realtime setup, routing, Riverpod repositories, authentication surfaces, deployment configuration and enterprise ERP/CRM modules.

## Current Production Gates

The repository is configured to validate production readiness through the GitHub Actions quality workflow:

- `flutter pub get`, `flutter analyze`, and package tests for the customer app, admin panel and website.
- Admin web release build and Android release APK smoke build with CI `--dart-define` values.
- Deno lint/check for Supabase Edge Functions.
- Supabase local reset and schema lint at error level.

Local validation in the current container is limited because Flutter, Dart, Deno and Supabase CLI are not installed. The included `tool/project_audit.sh` script runs the full audit automatically when those tools are present and gracefully reports missing toolchains.

## Platform Synchronization

All app surfaces share the same Supabase backend:

- Customer app lead, checkout, activity, support, loyalty, notification and booking flows use Supabase-backed repositories.
- Website lead capture, WhatsApp click tracking and visitor activity use the same CRM and activity tables.
- Admin CRM and Enterprise command center consume the same live Supabase tables and realtime streams.
- Migrations provision RLS, indexes, triggers, helper functions and realtime publication membership for the operational tables.

## Database Readiness

The migrations now cover these production domains:

- Core catalog, packages, areas, orders, payments, notifications and profiles.
- Marketplace content, website CMS, SEO pages, banners, reviews, FAQs and blogs.
- CRM leads, follow-ups, communication logs, notification templates, checkout recovery and lead attribution.
- Enterprise kitchen, recipes, raw materials, inventory movement, purchase workflow, finance ledger, delivery, staff ERP, support timeline, wallet/loyalty, BI metrics, AI insights and automation monitoring.

Security posture:

- Customer-facing tables use owner-based RLS where customers must only read their own records.
- Staff/admin ERP tables use `public.is_admin_staff()` or `public.is_admin()` policies.
- Customer-safe support, delivery, wallet and invoice policies are scoped through authenticated user ownership.
- Public read policies are limited to intentionally public content such as active membership levels or published content.

## Runtime Readiness Checklist

Use `tool/project_audit.sh` before release. A production release must pass:

1. `git diff --check`
2. Conflict marker scan
3. Prohibited unfinished-marker scan
4. Package import validation
5. Dart formatting check
6. Flutter analysis and tests for root, admin and website packages
7. Deno lint/check for edge functions
8. Supabase schema lint/reset
9. Android, web and PWA build smoke validations in CI

## Release Environment Variables

The `.env.example` file documents the required environment variables for Supabase, Firebase, Google Maps, Razorpay, Fast2SMS, WhatsApp and CRM dispatch secrets. Production deployments must source secrets from the hosting provider secret manager or CI secret store; secrets must not be committed.

## Backup and Restore

Recommended production backup plan:

- Enable Supabase PITR or daily database backups for the production project.
- Export storage bucket manifests for media and invoices.
- Keep migration history immutable and apply migrations through CI/CD.
- Validate restore in a staging Supabase project before production incidents.

Restore procedure:

1. Restore Supabase database backup or PITR snapshot.
2. Reapply migrations newer than the snapshot if needed.
3. Restore storage bucket objects.
4. Reconfigure Edge Function secrets.
5. Run `tool/project_audit.sh` and smoke-test app, website and admin flows.

## Admin and Staff Manual

Admin users should use:

- Dashboard for daily orders, revenue and upcoming event visibility.
- CRM for leads, live activity, communication logs, notification templates, campaigns and AI marketing assets.
- ERP for kitchen, staff, finance, CMS, marketing, module health, AI insights and automation monitoring.
- Catalog for category/package management.
- Operations for order preparation, dispatch and staff workflows.

Staff users must be assigned the correct role in `profiles.role`; RLS depends on role-aware policies.

## Customer Manual

Customers can use the app/website to browse packages, customize menus, manage cart/checkout, save favorites, track orders, receive notifications, manage profile/addresses, raise support tickets and participate in loyalty/referral programs. Guest lead capture is synchronized into the CRM through Supabase.

## Known Environment Limitation

This container cannot execute Flutter/Dart/Deno/Supabase validations because the CLIs are not installed. The repository-level CI workflow is the source of truth for full production validation in an environment with those tools installed.
