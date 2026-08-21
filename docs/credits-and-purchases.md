# Credits & purchases

Try-on is the only feature that costs real money — roughly **$0.024 per garment**
in Replicate inference. Credits exist so that cost is bounded and paid for.

One credit buys one garment application. A two-piece outfit costs 2 credits.

## Money flow

```
signup ──── trigger grants 3 credits ────┐
                                         ▼
Play purchase ──> RevenueCat ──> revenuecat-webhook ──> grant_credits()
                                                              │
                                                        user_credits
                                                              │
Flutter ──> try-on (create) ──> spend_credit() ──> Replicate  │
                     │                                        │
                     └── prediction failed ──> refund_credit()┘
```

## Ledger design

| Table | Role |
| --- | --- |
| `user_credits` | Current balance. Read-only to clients under RLS. |
| `credit_transactions` | Append-only audit trail. Every balance change has a row. |
| `tryon_jobs` | One row per garment application; links a Replicate prediction to its owner. |

Three properties matter and are enforced in SQL, not in application code:

- **Clients cannot mint credits.** `user_credits` has a SELECT policy and no
  others, so every mutation must come through a `SECURITY DEFINER` function
  called with the service role key.
- **Spending is atomic.** `spend_credit()` puts `balance >= amount` inside the
  `UPDATE`, so concurrent requests cannot both take the last credit.
- **Refunds and grants are idempotent.** A unique index on
  `(user_id, reason, ref)` means a retried webhook or a client polling a failed
  prediction in a loop changes the balance exactly once.

## Edge function secrets

Set with `supabase secrets set KEY=value`.

| Key | Function | Notes |
| --- | --- | --- |
| `REPLICATE_API_TOKEN` | try-on | |
| `TRYON_DAILY_GLOBAL_CAP` | try-on | Optional, default 300. Global predictions per UTC day — a runaway-loop backstop, ~$7/day at the cap. |
| `REVENUECAT_WEBHOOK_SECRET` | revenuecat-webhook | Must match the Authorization header value set in RevenueCat. |
| `ALLOW_SANDBOX_PURCHASES` | revenuecat-webhook | `true` only while testing. See below. |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected by the edge runtime.

## RevenueCat setup

1. Create the products in Google Play as **consumables**, with ids matching
   `CREDIT_PACKS` in [../supabase/functions/revenuecat-webhook/index.ts](../supabase/functions/revenuecat-webhook/index.ts).
   The map is the authority on how many credits each grants — the webhook never
   trusts a quantity from the payload.
2. In RevenueCat, add the webhook URL
   `https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook` and set
   the Authorization header to the same value as `REVENUECAT_WEBHOOK_SECRET`.
3. The webhook is deployed with `--no-verify-jwt` (see
   [../.github/workflows/deploy-functions.yml](../.github/workflows/deploy-functions.yml))
   because RevenueCat has no Supabase user JWT. It authenticates on the shared
   secret instead.

4. Put the **public** Play SDK key (`goog_…`) in `.env` as
   `REVENUECAT_ANDROID_API_KEY`. Leaving it blank disables purchases and leaves
   the rest of the app working, which is the intended development setup.

> **The RevenueCat app user id must be the Supabase user id.** Otherwise
> RevenueCat sends an anonymous `$RCAnonymousID:…` and there is no account to
> credit. The webhook logs and drops these; the money is taken and nothing is
> granted. [purchases_service.dart](../lib/services/purchases_service.dart)
> keeps the two in lockstep by subscribing to `onAuthStateChange`.

## Client flow

| File | Role |
| --- | --- |
| [purchases_service.dart](../lib/services/purchases_service.dart) | RevenueCat SDK wrapper; identity sync; catalogue and purchase. |
| [credits_provider.dart](../lib/services/credits_provider.dart) | Reactive balance. Mirrors the server, never writes it. |
| [credits_sheet.dart](../lib/pages/credits_sheet.dart) | Top-up sheet with packs, prices and Restore. |
| [tryon_page.dart](../lib/pages/tryon_page.dart) | Balance chip; opens the sheet on `insufficient_credits`. |

The purchase completes in the store *before* the credits exist, because the
grant happens out-of-band when RevenueCat calls the webhook. `awaitTopUp()`
polls the balance for up to 25s to cover that gap. If it times out the sheet
says the credits are on their way rather than reporting a failure — the grant is
late, not lost, and RevenueCat retries undelivered webhooks.

Pack names and prices come from the store listing, so the credit amounts live in
exactly one place: `CREDIT_PACKS` on the server. Name the Play products
accordingly (e.g. "20 try-on credits").

### Sandbox and the Test Store

Play license testers and RevenueCat's **Test Store** both generate `SANDBOX`
events. These are ignored unless `ALLOW_SANDBOX_PURCHASES=true`, so the
12-tester closed-testing group cannot mint real credits. Turn it on while
verifying the purchase flow, then off.

The Test Store is the way to exercise the full purchase → webhook → credit loop
before you have a Play Console account: its `test_…` key needs no store setup at
all. It also bypasses the stores entirely, so shipping that key would let anyone
mint credits — release builds refuse to configure with a `test_` key, and a
`goog_` key from a real Google Play app is required for anything you hand out.

## Refunds

Google reports refunds as `CANCELLATION`, often long after the purchase.
`revoke_credits()` reverses the amount recorded in the ledger for that
transaction — read back from `credit_transactions`, so changing `CREDIT_PACKS`
later cannot claw back a different number than was granted.

The balance is clamped at zero. If the credits are already spent we have already
paid Replicate, and a negative balance would lock the user out permanently; the
loss is capped at one pack.

`UNSUBSCRIBE` cancellations are **not** refunds and never revoke anything.

## Changing the signup grant

Three credits per signup is ~$0.072 of inference per account. Two constants must
change together:

- `handle_new_user_credits()` in
  [../supabase/migrations/20260811000000_credit_ledger.sql](../supabase/migrations/20260811000000_credit_ledger.sql)
  (via a new migration — do not edit an applied one)
- the comment block in [../supabase/functions/try-on/index.ts](../supabase/functions/try-on/index.ts)
