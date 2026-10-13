---
name: banking-standards
description: Must-follow rules for the banking libraries (money, ledger, kyc-core, payments-core, card-core, risk-rules, risk-models, banking-provider, neobank-api) - double-entry and hold invariants, idempotency, SEPA and SCT Inst identifiers, timeouts and ISO 20022 reason codes, PSD2 SCA elements, attempts and exemptions, KYC risk bands, screening and tipping-off, card authorization and clearing, safeguarding, audit, redaction and retention. Use when writing or reviewing code that moves money, books ledger entries, models payments, cards, customers or risk decisions, or when a question mentions SEPA, pacs.008, camt.053, SCA, PSD2, AML, PEP, sanctions, chargeback, 3DS, safeguarding or DORA.
---

# Banking standards

Rules for agents working on the neobank libraries. Each rule points at the research note
that holds the source, exact values and field lists:
`specs/research/banking-infrastructure/` in the specs repository (`README.md` indexes the
notes; `implications.md` is the per-repository checklist). Design:
`specs/design/neobank.md`. When a rule here and a note disagree, the note wins; fix this
page.

## Outcomes

1. Book every money movement as balanced, idempotent, never-edited ledger entries.
2. Model a payment's life with the scheme's own identifiers, statuses, timeouts and
   reason codes.
3. Decide SCA and risk for an operation and record why, in a form an auditor can replay.
4. Keep PII, card data and secrets out of logs, journals, fixtures and the ledger.

## Reference modules

- `ledger`: `Journal`, `Record` (`Linked`, `Rejected`, `Day_closed`), `Hold`, `Reversal`,
  `Trial_balance`.
- `payments-core`: `Transfer` (status machine), `Sca`, `Iban`, `Reconciliation`.
- `kyc-core`: `Kyc_case`, `Screening`, `Pii`, `Audit`.
- `risk-rules`: `Engine`, `Rules`, `Policy`, `Review_queue`.

## Ledger (note: `ledger.md`)

- Every entry balances per currency; customer accounts are liabilities; only settlement
  and external accounts may go negative. Amounts are integer minor units from `money`;
  never floats; a currency's exponent never changes.
- Nothing is edited or deleted. Corrections are reversals or `Adjustment` entries with a
  maker and a different checker.
- Idempotency keys are booked forever: same key and same content is a duplicate (return
  the original), same key and different content is an error, and a state-dependent
  refusal is recorded so a retry gets the same refusal. Derive keys from the client's
  request id or the provider's event id and state, never from a server clock.
- Holds: place, then capture (partial capture releases the rest) or release, at most once,
  with an expiry; settlement over a hold is one entry. Several entries that must land
  together (FX legs and fee) go in one `Linked` record.
- After `Day_closed` nothing is booked on or before that business date; late events book
  on the current date with their original effective time kept.
- Clearing accounts must return to zero; reconciliation produces break records and
  adjustments, never overwrites balances.

## Payments (note: `payment-schemes.md`)

- SEPA ids (`end_to_end_id`, Max35) are ours, in the Latin set
  `a-z A-Z 0-9 / - ? : ( ) . , ' +` and space, no leading or trailing `/`, no `//`;
  `uetr` is a UUIDv4; unstructured remittance at most 140 characters; charge bearer `SLEV`.
- SCT Inst: 10 s from acceptance, then `Timed_out` and release the hold; a late `Settled`
  books a fresh debit. SCT settles D+1. Returns and recalls are new credits with an ISO
  reason code (`AC01`, `AC04`, `AM04`, `DUPL`, `FRAD`, `TECH`, ... see the note's table).
- The final state comes from a webhook or poll, never from the initiating response.
- Crypto: credit BTC at 3 confirmations (6 above EUR 10 000), ETH and ERC-20 at the
  `finalized` tag; a reorg after credit is a reversal plus a case. Lightning is paid when
  the preimage hashes to the invoice's payment hash; keep the preimage.
- Travel rule: originator and beneficiary data on every crypto transfer; proof of
  ownership before sending more than EUR 1 000 to a self-hosted address.

## SCA (note: `strong-customer-authentication.md`)

- Two elements from different categories (knowledge, possession, inherence); SMS OTP,
  TOTP and device keys are all possession.
- The code is bound to amount, currency and payee; any change invalidates it; a code is
  used once; at most 5 failed attempts; failures never say which factor was wrong;
  5 minutes idle session.
- Every payment without SCA records its exemption and RTS article (Art 13 trusted
  beneficiary, 14 recurring, 15 own accounts, 16 low value EUR 30 / 100 / 5, 18 TRA);
  skipping SCA moves fraud liability to us.
- Never store or log an OTP, PIN or password; store the outcome.

## KYC and AML (note: `kyc-aml.md`)

- Risk band Low, Medium, High from customer, country, product and channel factors; PEP,
  high-risk third country or confirmed adverse media force High; manual changes need a
  recorded reason and operator.
- Screen at onboarding, on every list update, on data change and on every payment
  counterparty; discounting a hit needs two different operators.
- Never expose alerts, cases or suspicious activity reports to the customer (tipping-off);
  a held payment reads "under review".
- Retain CDD and transaction records 5 years after the relationship ends, then erase PII;
  the ledger holds ids, not PII.

## Cards (note: `cards.md`)

- An authorization is a hold keyed by `auth_id`; advices and stand-in approvals are
  recorded, not decided; clearings may be partial, repeated, above the auth or without
  one; refunds are new credits; holds expire (7 days default, 30 for lodging, car rental,
  cruise).
- Decline with the right code: `51` funds, `57` not permitted or frozen, `61` amount limit,
  `65` frequency limit, `05` generic.
- PAN, CVV and PIN never reach our servers; show at most the last four digits.

## Risk and models (notes: `fraud-and-monitoring.md`, `risk-and-treasury.md`)

- Rules first, model second; both produce `Allow | Review | Block` with reasons that name
  the facts used, and every decision is reproducible from a logged context.
- One feature function serves training export and scoring; a model ships with parity
  vectors (1e-6), calibrated thresholds from the alert budget, and a shadow period.
- Customer money is matched by safeguarding assets; reconcile per currency daily and
  propose top-ups, never post them silently.

## Reliability and security (note: `reliability-and-security.md`)

- Exactly-once effects come from at-least-once delivery plus dedup: API idempotency keys
  (24 hours), an outbox for provider calls, an inbox keyed by provider event id.
- Verify webhook signatures on the raw bytes in constant time before parsing.
- Redact: PAN and IBAN to the last four, never OTP, CVV, PIN, tokens or keys; secrets only
  from the environment, in a type that prints as `<redacted>`.
- Audit records say who, on whose behalf, what, when, where and the outcome; append-only.

## Storage

PostgreSQL holds application state, but it must stay replaceable. Each service defines
its own `Store.S` in domain types with `Store_memory` and `Store_pg` implementations
and one conformance suite over both; SQL and pg-async types live only in `store_pg.ml`
and `migrations/`. One schema per service, no cross-service joins, idempotency keys on
every write, the ledger journal append-only outside the database. Domain libraries
never depend on pg-async.
