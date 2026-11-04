# WAKNO LABS Worker — Admin 2.0 draft

This directory contains a branch-only Worker implementation based on the Worker source supplied for review. It is not deployed. The existing public page layout, approved headers, and DTF price calculations are left untouched; the two public forms only add structured order data and a browser-held idempotency ID to their existing POST.

## Bindings and secrets

The Worker expects the existing OAuth and Resend settings, plus D1:

- D1 binding: `DB`
- Existing values: `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `RESEND_API_KEY`
- Optional email recipient override: `ORDER_NOTIFICATION_EMAIL` (defaults to the current `waknolab@gmail.com`)
- Cloudflare Web Analytics: secret `CF_ANALYTICS_API_TOKEN`; non-secret vars `CF_ACCOUNT_ID` and `CF_RUM_SITE_TAG`

Do not commit any secret values. The site beacon token remains public site configuration; it is not the Analytics API token.

## D1 migration

Use the existing Cloudflare project configuration and database name/ID. Apply the SQL migrations in `migrations/` before enabling the new form endpoint. The migration creates customers, identity keys, service and DTF order details, status history, internal notes, email outbox, and short-lived hashed-IP rate-limit buckets.

## Order and email flow

`/api/offer` validates the current form payload, persists the order and both notification jobs to D1 in one D1 batch, and only then returns success. Resend sends asynchronously from the durable outbox. The scheduled Worker retries failed notifications with stable Resend idempotency keys; the admin order record remains available if an email attempt fails. If D1 is unavailable, the form gets an error and the Worker does not claim that the order was saved.

The existing authenticated content editor remains available at `/admin/content`. `/admin` is the new orders and CRM dashboard. GitHub content editing still follows the existing mechanism and is not changed by this draft.

## Analytics

The dashboard queries Cloudflare's RUM pageload dataset through the GraphQL Analytics API. It shows visits and page views, marks sampling, and leaves values blank when configuration or data is unavailable. Cloudflare defines a visit as a page view from another site or a direct link; it is not a count of individually identified people. The RUM API query still needs to be verified against the WAKNO Cloudflare account before deployment.

## Features still requiring the existing production setup

This is a review draft, not a complete replacement of the current content editor. Bulk portfolio uploads with preview/reorder/hide/delete, website content draft preview and restore UI, full SEO/color controls, and a dashboard-driven backup/restore workflow are not implemented here. The current /admin/content editor remains available and continues its existing GitHub publishing flow. These areas need to be designed against the actual Worker configuration and current content.json contract before changing publishing behavior.

## Deployment gate

`wrangler.example.toml` is a template, not a replacement for the missing production `wrangler.toml` / `wrangler.jsonc`. Confirm the deployed Worker route, OAuth callback origin, existing bindings, and compatibility date before copying any changes into production configuration. This draft must not be deployed until the D1 database is created, migrations are applied, secret bindings are set, and the current Cloudflare config is reconciled.
