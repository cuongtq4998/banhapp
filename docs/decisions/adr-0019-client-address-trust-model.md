# ADR-0019: Client address trust model (TRUST_PROXY and proxy hop count)

| Field    | Value |
| -------- | ----- |
| ADR      | 0019 |
| Version  | 1.0 |
| Status   | Proposed (security: the rate-limit identity; needs one staging check and the owner's confirmation of the recommendation) |
| Date     | 2026-10-27 |
| Decider  | atlas-architect proposes; product owner confirms (security) |
| Based on | ADR-0014, ADR-0017; `backend/Sources/App/Config/AppConfig.swift:26,63-66,146-153`; `backend/Sources/App/Http/ClientAddress.swift`; deployment.md 3.1; auth.md section 4; QA defect D-17 (docs/test/place-order-tests.md) |

## Context

Rate limits are per client address (ADR-0014, ADR-0017). The service runs behind the host's proxies, so the connection address is a proxy, not the customer. The code reads the client from the `X-Forwarded-For` header only when `TRUST_PROXY=true` (default false), and takes the **last** entry of all header lines joined in order. This is right only when exactly one trusted proxy appends the address it saw (a proxy appends and keeps what the client sent, so only the last entry is out of the client's reach). No ADR recorded the model. QA defect D-17 (first header line only) is fixed; QA also asked how many hops there are (question to the architect).

New evidence on 2026-10-27: the host's own articles say all inbound traffic to its web services passes through a CDN network and then the host's load balancers, and that the header is appended to, not replaced (sources below). That contradicts the assumption "exactly one proxy" in deployment.md 3.1 and in the `ClientAddress` comment. The exact content of the header at the service (one or two entries) is not documented; it must be observed.

## Decision Drivers

- A wrong identity has two failures of different weight: too few hops trusted means every customer shares one budget (too tight, safe); too many hops trusted means a client picks its own identity and bypasses the limits (unsafe; matters most for `POST /v1/orders` in slice 3).
- No cost, no new service.
- The host may change (ADR-0003 keeps hosting reversible), so the rule must not depend on one vendor's header.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Keep the boolean (last entry) | Built and tested | Wrong if two hops append entries: all customers share the CDN or load balancer address |
| B. Trusted hop count `TRUST_PROXY_HOPS` (integer, default 0): the client is the entry counted from the right by the count | Vendor-neutral; matches the standard "trusted proxy count" method; one integer to verify on staging | A wrong count is silent; needs the verification step |
| C. Read a vendor header (the CDN's client-address header) | The CDN overwrites it, so the caller cannot forge it | Absent on private paths and after a host change; ties code to one vendor; unverified for this service |
| D. Trusted proxy address list | Strongest | Proxy ranges are not published as a stable list in the documents read; high upkeep |

## Decision (recommended, pending the staging check)

Option B.

1. Replace `TRUST_PROXY` (boolean) by `TRUST_PROXY_HOPS` (integer, 0 to 5, default 0). 0 means: use the connection address and ignore the header. n means: join all `X-Forwarded-For` lines in order, split on commas, and take the n-th entry from the right (1 = last entry, the current behaviour). If the list has fewer than n entries, or the entry is empty, fall back to the connection address (the safe, shared key) and log a warning once per start with no address in it.
2. Compatibility: for one release `TRUST_PROXY=true` is read as hops 1 and `false` as 0; setting both with different meanings fails the start. Remove the boolean in the next release. `.env.example`, deployment.md 3 and auth.md section 4 name the new variable.
3. The value is **verified, not assumed**: after the first staging deploy and after any change of host, domain or CDN setup, the operator sends `GET /healthz` with a forged `X-Forwarded-For: 203.0.113.9` from a known address and checks (access log or a debug build) which entry is the caller's real address; hops = its position from the right, counting the forged entry's position as not trusted. Until verified, staging and production run with hops 1 only if the check shows one entry from the proxies, otherwise the observed number. If nothing can be verified, use 0 (too tight but safe).
4. Failure modes: hops too low gives one shared budget (429 for everyone at 120 reads per minute: visible, an alert fires, see ADR-0014); hops too high lets a client choose its key (silent). When unsure, choose lower and raise the read limit (`RATE_LIMIT_READ_PER_MINUTE`) instead.
5. `ClientAddress` also keeps the rule that the header is never read when hops is 0, whatever the client sends.
6. Limits that do not depend on the address (per-phone limit of slice 3, daily capacity) remain the second line of defence; the address limit is not a security boundary against a determined attacker (ADR-0014).

## Consequences

- Positive: correct behind any number of hops once measured; no vendor lock; failure is visible when too low.
- Negative: a code and configuration change (developer task, small: one parser function, tests for 0, 1, 2 hops, repeated lines, fewer entries than hops, empty entries); one manual verification per environment.
- Until it ships, deployment.md 3.1 states that the one-proxy assumption is contradicted by the host's articles and must be verified on staging; with the current boolean a wrong assumption only makes limits too tight (all customers share one key), never forgeable, because the last entry is the one the nearest proxy wrote.
- Owner decision requested: confirm option B (it affects which requests are throttled). No money, no customer data.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Without a trusted-proxy rule no part of `X-Forwarded-For` is trustworthy; only entries added by trusted proxies may be used for rate limiting; two methods: trusted proxy count from the right, or trusted proxy list; several header lines are one list, join them | https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/X-Forwarded-For | 2026-10-27 | High |
| Host: web services sit behind a load balancer that terminates TLS; the service is not directly reachable | https://render.com/docs/web-services | 2026-10-27 | High |
| Host: inbound traffic passes through the CDN network and then the host's load balancers; the app sees a proxy address by default; read `x-forwarded-for` | https://render.com/articles/how-render-handles-ddos-attacks | 2026-10-27 | Medium (marketing article, not reference documentation; does not say how many entries appear) |
| Host: the CDN appends to `X-Forwarded-For` rather than replacing it, so the leftmost entry is forgeable; the CDN's own client-address header is overwritten by the CDN | https://render.com/articles/host-pocketbase-on-render | 2026-10-27 | Medium (article about another product) |
| Reference documentation of the host on the client address header | Not found (the docs pages read do not mention it) | 2026-10-27 | Unverified |

## Links

Related: ADR-0014, ADR-0017, ADR-0003; auth.md section 4; deployment.md sections 3 and 3.1.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-27 | First version (Proposed). |
