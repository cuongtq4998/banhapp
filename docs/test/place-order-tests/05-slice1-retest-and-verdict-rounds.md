# Place Order Test Report: Slice 1 retest round 5 and verdict round 6

Part of the place-order test plan and report, v1.7 (index: [place-order-tests.md](../place-order-tests.md)). Sections in this part: 4.7 Slice 1 verdict round 6, 4.6 Slice 1 backend retest round 5, 5. Additional Cases. Section numbers and ids are unchanged from v1.6.

| Ids in this part | Range |
| ---------------- | ----- |
| Test cases defined (table rows) | none |
| Test cases mentioned | TC-66 to TC-267 (13) |
| Slice 1 plan ids defined (TC-S1) | TC-S1-30 to TC-S1-44 (15) |
| Defects mentioned | D-15 to D-20 (6) |

### 4.7 Slice 1 verdict round 6 (backend, iOS, Android) [v1.6 | 2026-10-27]

Commit 0aa9b8c (feature/place-order, docs-only tip dfb58f2). Method: evidence review plus code reading in the worktree; I did not rerun the suites (no PostgreSQL here; the host hook blocks raw `xcodebuild`). Evidence used: GitHub CI on 0aa9b8c, backend, iOS and Android workflows green; backend `swift test` plus QA package 177 tests, 0 failures against postgres:16 with the sample seed (so the 50 round 5 skipped database tests, including the 29 catalogue tests and AC-32/AC-33 API tests, were executed and passed); 28 Android Compose UI tests passed locally through ddagent (reported by the orchestrator).

Changed expectation: TC-133 and TC-134 (and mirrors TC-233, TC-234) followed the pre-v1.4 rule (Error with fewer than four cakes). Updated to PRD v1.4 (BR-13, AC-32 to AC-34, Q-15): active cakes are shown, Error only at zero.

| Case / AC | Backend | Android | iOS | Status |
| --------- | ------- | ------- | --- | ------ |
| AC-1, AC-2 (TC-101/102/132, TC-201/202/232) | CatalogContractTests (CI) Pass | Compose tests Pass (local) | HomeViewModelTests, LaunchGateTests Pass (CI); UI Not run | Pass (Android, API); iOS unit only |
| AC-3 (TC-103 to 105, 203 to 205) | n/a | link logic unit tests Pass (CI) | FormattingAndLinkTests Pass (CI) | Conditional: real device with Zalo and dialer Not run |
| AC-4 (TC-106/107/133, 206/207/233) | four cakes, shape and order Pass (CI) | `ProductsScreenTest` Pass | CatalogScreenModelTests Pass (CI) | Pass (unit/Compose); iOS UI Not run |
| AC-5 (TC-108/134, 208/234) | n/a | detail tests Pass | `testDetailFindsTheCakeById`, unknown id failed load Pass (CI) | Pass at unit level; navigation into S-5 belongs to slice 2 |
| AC-32 (1, 2, 3 active) | `testAC32_...` Pass (CI, executed) | `fewerThanFourCakesAreShownAsTheyAre`, `threeCakesShowThreeCards` Pass | `testProductListShowsEveryActiveCakeFromOneToFour` Pass (CI) | Pass; the "order flow offers only active cakes" half is slice 2 |
| AC-33 (zero active) | `testAC33_...` Pass (CI, executed) | `zeroCakesShowEmptyStateWithRetryAndNoCard`, `noCakeAtAllIsAnEmptyAnswerNotAFailedLoad` Pass | `testProductListIsAnErrorOnlyWhenEmpty` Pass (CI) | Pass for list and Error; recovery without reinstall and "Place order starts no flow" Not run (slice 2) |
| AC-34 | slice 1 part only (hidden cake absent) Pass | n/a | n/a | Slice 3 |
| AC-21 (Vietnamese text), AC-27 (no payment words), AC-29 (no marker word) | TC-66 seed text, privacy page checks Pass (CI) | LocalizationTests equivalents Pass | LocalizationTests Pass (CI) | Pass for slice 1 screens; screen walk Not run |
| TC-145/146, 245/246 (offline cache, 7 days) | ETag and 304 Pass (CI) | CatalogRepositoryTest Pass (CI) | CatalogCacheTests, CatalogRepositoryTests Pass (CI) | Pass at unit level; offline cold start on device Not run |

Round 5 defects, re-evaluated on 0aa9b8c: the QA package that failed 4 tests on a934ae8 (D-17, D-18, D-19, D-20) passes 177 of 177 in CI, the developer test of D-15 passes, and `.github/workflows/backend.yml` now sets `SHOP_ID` for the release smoke test (D-16). Code reading: `ClientAddress` joins repeated `X-Forwarded-For` lines (D-17), `FixedWindowRateLimiter` keeps one window per address (D-18), the 304 fixture tag is 32 hex (D-20). All six marked Fixed on the strength of green CI, not on my own rerun.

Remaining gaps: iOS UI tests on a simulator (not run locally); real device (AC-3, image loading, VoiceOver, TalkBack, Dynamic Type, 200% font); iOS 17 runtime; Android match with the design board (visual, by eye); offline cold start; AC-34 order-time and the order-flow halves of AC-32/AC-33 (slices 2 and 3); release smoke step result on the real workflow was read, not observed by me; hop count behind two proxies (question to atlas-architect, section 4.6).

### 4.6 Slice 1 backend retest, round 5 [v1.5 | 2026-10-26]

Commit a934ae8. Commands: `cd backend && swift test`; `cd backend/Tests/qa && swift test`. QA package adapted: `ConfigEdgeTests` base now has `SHOP_ID`; `CatalogApp` (support) sets the working directory to `backend/` (so `assets/` resolves, as when the server runs from source), passes `SHOP_ID` of the seed shop and the new config fields; seed constants follow `sample.sql` (shop "Tiệm Bánh An Nhiên", phone `+84900000000`, Zalo `84900000000`); image rules follow api.md 4.6 (`/assets/images/*`, `public, max-age=31536000, immutable`, 404 `no-store`); ETag is checked as 32 lowercase hex; HEAD and query rules follow api.md v1.6.

Results (host): developer package 165 tests, 16 skipped (database), 0 fail. QA package 177 tests, 50 skipped (database: 21 DatabaseTests + 29 catalogue tests), **123 pass, 4 fail** (7 assertions), 0 blocked by the code under test. Legend: Pass = ran and passed on a934ae8; Fail = ran and failed (defect id); Skip = needs PostgreSQL, not run, no evidence yet (CI skipped it).

Previously expected-to-fail tests (round 4, 17 tests + 3 ConfigEdge failures caused by the merge):

| Test | Round 5 result | Evidence / decision |
| ---- | -------------- | ------------------- |
| ConfigEdgeTests.testPortBoundaries, testSurroundingSpacesAreTrimmed, testTrailingNewlineIsTrimmed | Pass | Test defect (base lacked `SHOP_ID`, now required outside local); fixed in the QA test |
| CatalogFailureTests (3: unreachable database 503, no database 503, conditional during outage) | Pass | 503 envelope, no leak, shallow health stays 200 |
| ReadRateLimitTests.testTC50, testExtra_ReadGroupIsOneSharedBudget, testExtra_SpoofedForwardedFor..., testExtra_LimitedResponse... | Pass | Limiter exists; 121st read is 429, Retry-After 1..60 |
| StaticContentTests: privacy (5 tests), asset files (2), fixtures (2), asset methods (1) | Pass after test fixes | Failures on the first run were all test defects of mine: working directory (privacy 404), fixture kinds (empty and 304 fixtures are not "four cakes"), image path `images/...` rule |
| testTC67_MissingAssetIsNotFoundEnvelope | **Fail** | D-19 (code): 404 outside the static handler has no `Cache-Control: no-store` |

New and changed cases:

| ID | Type | Test | Notes | Result on a934ae8 |
| -- | ---- | ---- | ----- | ----------------- |
| TC-S1-30 | extra | ConfigEdgeTests.testShopIdIsRequiredOutsideLocalAndMustBeAUuid, testLocalRunMayOmitShopIdAndDatabase | `SHOP_ID` required in staging and production, UUID only, optional locally | Pass |
| TC-S1-31 | extra | testTrustProxyDefaultsOffAndParsesStrictly, testReadRateLimitDefaultAndBounds, testPublicAssetBaseUrlTrailingSlashesAreRemoved, testSlice1ConfigErrorsNeverEchoValues | `TRUST_PROXY` `true`/`false` only (case-insensitive), limit at least 1, no value echoed in errors | Pass |
| TC-S1-32 | extra | ReadRateLimitTests.testExtra_NotFoundCountsAndALimitedRequestDoesNot | api.md v1.6: 404 counts, 429 does not move the window | Pass |
| TC-S1-33 | extra | testExtra_WindowEdgesAndRetryAfterRounding | Controlled clock: Retry-After rounded up, 1 at 59.9 s, new window at exactly 60 s, clock moving backwards does not lock out | Pass |
| TC-S1-34 | extra | testExtra_EachAddressHasItsOwnWindow | api.md v1.6: window starts at the first counted request of that address | **Fail** (D-18) |
| TC-S1-35 | extra | testExtra_TrustedProxyKeysTheBudgetOnTheLastForwardedEntry, testExtra_TrustedProxyWithoutHeaderSharesTheConnectionAddress | With `TRUST_PROXY=true` the last entry of one header line decides; forged leading entries do not escape; odd values never 5xx | Pass |
| TC-S1-36 | extra | testExtra_TrustedProxyReadsTheLastEntryAcrossRepeatedHeaderLines | RFC 9110 5.3: repeated header lines are one list | **Fail** (D-17) |
| TC-S1-37 | extra | testExtra_ParallelBurstNeverExceedsTheBudget | 200 parallel reads, limit 50: exactly 50 pass | Pass |
| TC-S1-38 | extra | StaticContentTests.testExtra_OnlyImagesWithImageExtensionsAreServed | 18 traversal and encoding forms under `/assets/images/` (`..%2f`, `%2e%2e`, `%252e`, overlong UTF-8, full-width dots, backslash, NUL, hidden file, wrong extension, trailing slash): never the privacy page, never 5xx, only images served | Pass |
| TC-S1-39 | extra | testExtra_ImageUrlVersionIsTheFileSha256Prefix | `?v=` of `catalog-ok.json` equals the first 8 hex of the SHA-256 of the file | Pass |
| TC-S1-40 | extra | testExtra_AssetsDirectoryAndRootAreNotListed, testExtra_AssetMethodsRangeAndRevalidation | `/assets`, `/assets/images` give 404; immutable cache header, version query ignored, Range, bad Range, POST/PUT/DELETE not 200. HEAD body not observable (the in-memory tester does not strip HEAD bodies) | Pass |
| TC-S1-41 | extra | testTC3_NotModifiedFixtureFollowsTheEtagContract | 304 fixture: status 304, body null, repeats the tag, `no-cache`, tag is 32 lowercase hex | **Fail** (D-20) |
| TC-S1-42 | extra | testTC1_CatalogFixturesExistAndSatisfyTheContractCheck | `catalog-ok.json` four cakes; `catalog-empty.json` has `products: []` (AC-33) | Pass |
| TC-S1-43 | extra | CatalogFailureTests.testExtra_HeadIsAnsweredLikeGetNotAs404 | Observed: HEAD is answered like GET by Vapor; api.md 4.1 says HEAD answers 404 (DOC-11) | Pass (pins observed behaviour) |
| AC-32 (API) | acceptance | CatalogContractTests.testAC32_OneTwoOrThreeActiveCakesAreListedExactly (needs `QA_ALLOW_DB_MUTATION=1`) | 3, 2, 1 active cakes and a hidden one in the middle: exactly the active ones in sort order, no padding, shape valid | Skip (no PostgreSQL, no CI run) |
| AC-33 (API) | acceptance | testAC33_ZeroActiveCakesIsAnEmptyListNotAnError | Zero active: 200 with `products: []`, districts and slots intact, new ETag, old tag no 304; one cake active again appears on the next request | Skip |
| AC-32, AC-33 (UI) | acceptance | iOS and Android UI cases with `catalog-empty.json` and a three-cake fixture | List of the active cakes only; Error state at zero; recovery without reinstall | Not run (client slices) |
| AC-34 | acceptance | Order-time hidden cake (`PRODUCT_UNAVAILABLE`, data kept, nothing stored, price kept on old orders) | Slice 1 only exposes the hidden cake's absence from the catalogue (AC-32 test) | **Slice 3** (order endpoint absent); slice 1 part Skip |
| TC-S1-44 | extra | testExtra_AllDistrictsAndSlotsInactiveGiveEmptyLists, testExtra_ChangedShopSettingIsServedAndNoteLengthStaysAConstant, testExtra_UnknownShopIdDoesNotLeakOrCrash, testExtra_AssetBaseUrlPrefixesEveryImageUrl | Empty lists valid, settings follow the table, `note_max_length` stays 200, unknown `SHOP_ID` is 500 `INTERNAL_ERROR` without data (CatalogRepository doc), `PUBLIC_ASSET_BASE_URL` prefix | Skip (the unknown-shop case will fail on CI: D-15) |

Changed expectations of existing DB tests (ADR-0017): ETag shape 32 hex; 304 repeats `Cache-Control: no-cache`, no `Content-Type`; unknown query parameter must give 200 with the same body and tag; HEAD accepts 200 or 404; image URL starts `/assets/images/` with `?v=<8 hex>` and the immutable header. All Skip here.

Code review of the slice 1 backend (by reading, plus the tests above):

| Area | Finding |
| ---- | ------- |
| ETag determinism | Sound: `sortedKeys` and `withoutEscapingSlashes` encoder, SQL `ORDER BY sort_order, id`; hash is SHA-256 of the body, 32 hex. The ETag covers `server_date` and `image_url` as documented. Not run against a database. |
| Rate limit | D-17, D-18. Also: `/healthz` counts, so a platform health check behind a shared proxy address (`TRUST_PROXY` off) shares the budget with customers (risk, documented in `.env.example`). Memory is bounded by the per-window reset. |
| TRUST_PROXY | Last entry of the first header line only (D-17). With two proxies in front (a CDN and the host) the last entry is the inner proxy, so all customers would share one budget; hop count is not stated in deployment.md (question to atlas-architect). |
| Static route | Segment allow-list, hidden names refused, extension allow-list, only `images/` served; 18 hostile paths pass. Symlinks inside `assets/images` are followed (the repository has none; informational). 404 header gap: D-19. |
| Privacy page | Vietnamese, `lang="vi"`, UTF-8, no script, no tracker, no payment word, names all four data items, purpose, recipient, storage, retention (placeholders say the shop will update: acceptable, retention is launch data). `Cache-Control: no-cache`. |
| Seed values | No marker word (TC-66 Pass), phone `+84900000000` consistent with ADR-0017 item 8. |
| Log policy | Access log has route template only, no query, address, body; "Product image file not found" logs the shop's image path only; the unknown-shop error logs the type only. The AsyncKit connection-failure log of the driver includes the database host and port (infrastructure, no customer data; informational). |
| CI | D-15, D-16. |

## 5. Additional Cases

Cases marked `extra` above were added by the tester beyond the 29 ACs. Reasons are in the Preconditions column of each case (boundary at exactly N=2, 1 lead days, 30 days ahead, quantity 2 and 1, daily-limit exact fit and one-over; two orders racing for the last cakes; duplicate submit with one key; rate limit and per-phone limit; every API error code; price change; offline, cache and draft; six UI states per screen; accessibility; Vietnamese text; time zone and clock; logs and enumeration; database guards). Android-only extras are TC-266 and TC-267. Slice 1 extras are TC-S1-01 to TC-S1-29 (section 4.5.2) and TC-S1-30 to TC-S1-44 (section 4.6). [v1.5 | 2026-10-26]
