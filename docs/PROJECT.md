# Project record

## Objective

Rack webhook inbox that captures, inspects and forwards requests with byte-exact bodies and preserved headers, signed with Standard Webhooks HMAC-SHA256 signatures

## Scope

- In scope: the public API documented in [README.md](../README.md), documented and tested.
- Out of scope: anything that needs dependencies or I/O without an accepted ADR.

## Timeline

| Date | Event |
|---|---|
| 2026 | Repository created from the factory utility template. |

## Effort metrics

Measured values only; a value that has not been measured stays "pending measurement".

| Metric | Value |
|---|---|
| Tokens (input / output) | 5245246 / 60519 |
| Hours (human) | pending measurement |
| Cost (USD) | 1.6113 |

## Factory run u955 (measured from API usage)

| Date (UTC) | Phase | Model | Batch | Input | Output | Cache write | Cache read | Cost (USD) |
|---|---|---|---|---|---|---|---|---|
| 2026-11-17 | generation | google/gemini-4-argon | yes | 6217 | 27890 | 0 | 0 | 0.5827 |
| 2026-11-17 | fix-1 | google/gemini-3.8-flash | no | 100119 | 1573 | 0 | 573200 | 0.1240 |
| 2026-11-17 | fix-2 | google/gemini-3.8-flash | no | 160797 | 631 | 0 | 936162 | 0.1932 |
| 2026-11-17 | fix-3 | google/gemini-3.8-flash | no | 129939 | 19446 | 0 | 1208532 | 0.2610 |
| 2026-11-17 | fix-4 | google/gemini-3.8-flash | no | 144423 | 6440 | 0 | 1057129 | 0.2118 |
| 2026-11-18 | audit | google/gemini-3.8-flash | no | 125078 | 1103 | 0 | 388998 | 0.1271 |
| 2026-11-18 | threat-model | google/gemini-3.8-flash | no | 106938 | 916 | 0 | 301726 | 0.1063 |
| 2026-11-18 | docs | google/gemini-3.1-flash-lite | no | 5988 | 2520 | 0 | 0 | 0.0053 |

Total: $1.6113. Prices: vertex line, as measured by its adapter. Providers serve the current version of each model id, so the date tells which version answered; versions, launch stages and price sources per line are in the factory's model register (docs/MODELS.md).
