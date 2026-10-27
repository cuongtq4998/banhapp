# Place Order Test Report: Executable tests, slice 0 and slice 1 plan

Part of the place-order test plan and report, v1.7 (index: [place-order-tests.md](../place-order-tests.md)). Sections in this part: 4.4 Slice 0 executable tests, 4.5 Slice 1 executable tests (plan cases and extra cases). Section numbers and ids are unchanged from v1.6.

| Ids in this part | Range |
| ---------------- | ----- |
| Test cases defined (table rows) | TC-55 to TC-98 (36) |
| Test cases mentioned | TC-1 to TC-265 (82) |
| Slice 1 plan ids defined (TC-S1) | TC-S1-01 to TC-S1-29 (29) |
| Defects mentioned | D-1 to D-12 (11) |

### 4.4 Slice 0 executable tests [v1.1 | 2026-10-26; v1.2 results on b613c6d]

Executable QA package: `backend/Tests/qa/` (own `Package.swift`; compiles `backend/Sources/App` through a symlink without `entrypoint.swift`; run `cd backend/Tests/qa && swift test`; for database tests add `DATABASE_MIGRATION_URL=postgres://...` of a throwaway database). Developers' own tests (`backend/Tests/AppTests`) are not mine; round 1: 26 pass on f940495; round 2: 83 tests, 73 pass, 10 database tests skipped, 0 fail on b613c6d.

Plan cases that belong to slice 0 and how they are covered (all other plan cases wait for slices 1 to 3):

| Plan case | Slice-0 part | QA test (class.method) | Result (round 1 f940495 / round 2 b613c6d) |
| --------- | ------------ | ---------------------- | ----------------- |
| TC-55 | `/healthz` 200 `{"status":"ok"}`, no-store | HealthEdgeTests.testShallowBodyIsExactlyStatusOk, testFixturesMatchWireFormat | Pass / Pass |
| TC-54 (health part) | deep check 503 degraded when database fails; real stopped database | HealthEdgeTests.testDegradedBodyAndHeaders, testRecoveryAfterFailureNoStickyState (stub); real database stop | Pass (stub) / Pass (stub, stubbed through `app.services`); real DB Blocked |
| TC-59 | cancel releases capacity, event written, second cancel changes nothing | DatabaseTests.testCancelReleasesCapacityOnceAndWritesEvent | Not run (no PostgreSQL) / Not run (no PostgreSQL) |
| TC-60 | transition matrix (4 valid, 8 invalid), snapshot columns immutable | DatabaseTests.testStatusTransitionMatrix, testSnapshotColumnsAreImmutable, testPersonalColumnsChangeOnlyThroughPurge | Not run (no PostgreSQL) / Not run (no PostgreSQL) |
| TC-61 | reconciliation after cancel | DatabaseTests.testReconciliationHoldsAfterCancels | Not run (no PostgreSQL) / Not run (no PostgreSQL) |
| TC-66 | all seed rows `is_sample = true`; no visible marker text | DatabaseTests.testSeedRowsAreAllMarkedSample; RepositoryLayoutTests.testSeedHasNoSampleMarkerInVisibleText | static: Pass / Pass; DB: Not run / Not run |
| TC-69 | seed `phone_contact` E.164 (CHECK accepts the seed insert) | DatabaseTests.testSeedIsIdempotentAndEverythingIsSample (inserts under the CHECKs) | Not run (no PostgreSQL) / Not run (no PostgreSQL) |
| TC-70 | CHECK, UNIQUE, FK guards at database level | DatabaseTests.testCheckConstraintsRejectBadRows (26 bad rows), testIdempotencyKeyAndOrderCodeAreUnique, testItemChecksAndRestrictiveForeignKeys, testOrderEventIsAppendOnly | Not run (no PostgreSQL) / Not run (no PostgreSQL) |

Slice-0 extra cases (`extra`, reasons in the Notes column), numbered TC-71 and up:

| TC | Type | Test | Notes (reason) | Result |
| -- | ---- | ---- | -------------- | ------ |
| TC-71 | extra | HealthEdgeTests.testDeadlineIsAboutTwoSeconds, testFastSuccessDoesNotWaitForDeadline | Deep timeout is 2 s (api.md 4.4), not early, not late | Pass | Pass / Pass |
| TC-72 | extra | HealthEdgeTests.testManyParallelDeepChecksWithSlowDatabase | 25 parallel deep checks with a hung database: all 503 in under 5 s, none queue | Pass / Pass |
| TC-73 | extra | HealthEdgeTests.testDeepQueryVariants, testOnlyGetIsServed, testHeadRequestDoesNotFailLikeAServerError, testTrailingSlashAndCase | Odd queries stay shallow; POST/PUT/DELETE/PATCH not 200 and not 5xx; HEAD (used by many uptime monitors) 200; `/healthz/` 200 | Pass / Pass |
| TC-74 | extra | HealthEdgeTests.testErrorDetailsNeverLeakIntoResponse | Probe error text with credentials never reaches the body | Pass / Pass |
| TC-75 | extra | ConfigEdgeTests (round-1 tests plus pool sizing budget 1..40 x 7 core counts, pool max 0, serve config does not fall back to the DDL URL) | Port boundaries, whitespace, case sensitivity, pool max, values never echoed in errors | Pass / Pass |
| TC-76 | extra | ConfigEdgeTests.testMigrateNeedsOnlyTheMigrationRole (+ 4 MigrationConfig tests: URL required and trimmed, stage required and validated, no echo) | `migrate` with only APP_ENV and DATABASE_MIGRATION_URL (what the staging deploy job passes) | Fail (D-2) / **Pass** (D-2 fixed) |
| TC-77 | extra | ConfigEdgeTests.testTrailingNewlineIsTrimmed | Secret pasted with trailing newline, CRLF | Fail (D-5) / **Pass** (D-5 fixed) |
| TC-78 | extra | SplitterEdgeTests (12 tests) | Empty input, CRLF, comment and dollar markers inside strings, `$1`, unterminated input, Vietnamese text, 20 000 statements under 5 s | Pass / Pass |
| TC-79 | extra | SplitterEdgeTests.testEscapeStringWithBackslashQuote, testQuotedIdentifierWithSemicolon, testNestedBlockComment | Valid PostgreSQL the old scanner cut wrongly | Fail x3 (D-4) / **Pass** x3 (D-4 fixed; residual gap is D-11) |
| TC-80 | extra | DatabaseTests.testMigrationRerunIsNoOpAndSchemaIsComplete, testRevertIsRefused, testFailingMigrationLeavesNothingBehind | Re-run is a no-op (ledger), 9 tables and 4 triggers, revert refused, a failing file leaves no table | Not run (no PostgreSQL) / Not run (no PostgreSQL) |
| TC-81 | extra | DatabaseTests.testSeedIsIdempotentAndEverythingIsSample | Seed twice (and a third time) gives identical row counts | Not run (no PostgreSQL) / Not run (no PostgreSQL) |
| TC-82 | extra | DatabaseTests.testActorSettingsAreRecordedInTheEvent, testBogusActorTypeFailsTheUpdateAtomically, testCompletionAndConfirmationDoNotTouchCapacity, testCancelWithMissingDayLoadRowDoesNotFail, testCancelThatWouldMakeCounterNegativeIsBlockedAndAtomic, testPaymentStatusStaysMutable, testBlankPersonalDataWithoutPurgeMarkerIsRejected | Trigger edge behaviour: actor settings, atomic failure, no day_load row, counter would go negative | Not run (no PostgreSQL) / Not run (no PostgreSQL) |
| TC-83 | extra | RepositoryLayoutTests.testMonorepoComponentsExist, testMigrationNumberingHasNoGapsOrDuplicates, testMigrationsAreForwardOnlyAndFreeOfDestructiveStatements, testSeedNeverDeletesOrUpdates | Layout (ADR-0004) and migration hygiene | Pass / Pass |
| TC-84 | extra | RepositoryLayoutTests.testDockerfileCopiesEveryTargetPathOfPackageSwift | Image build context holds every path Package.swift declares (verified separately in round 1: `swift package describe` in a copy without `Tests/` fails with "invalid custom path 'Tests/AppTests'") | Fail (D-1) / **Pass** (Dockerfile now has `COPY backend/Tests ./Tests`; image build itself not run, no Docker) |
| TC-85 | extra | RepositoryLayoutTests.testEnvExampleCoversEveryVariableWorkflowsAndComposeUse, testWorkflowsDeclareLeastPrivilegeAndNoPullRequestTarget, testSecretsAreOnlyReferencedByMainOnlyJobs, testNoCredentialLookingValuesCommitted | `.env.example` names only; workflows read-only permissions, no `pull_request_target`; secrets only in the push-only deploy job; no credential patterns outside throwaway placeholders | Pass / Pass |
| TC-86 | extra | (manual review, no test) | Workflow gaps found by reading: D-3, D-6, D-7, D-8 | round 2 review: D-6, D-7, D-8 fixed; D-3 still open (workflow-level group); new D-12 |
| TC-87 | extra | iOS and Android shells | Configuration read only: iOS deployment target 17.0, bundle id `app.banh.customer`, iPhone only; Android minSdk 26, applicationId `app.banh.customer` (ADR-0005, ADR-0016 agree). Shell builds not run here (iOS workflow needs Xcode 27 runner; Android needs SDK 37) | Blocked (build), config Pass |

Round 2 additions [v1.2 | 2026-10-26], all `extra`, in `ReviewEdgeTests.swift` (adversarial review of the refactored code):

| TC | Type | Test | Notes (reason) | Result on b613c6d |
| -- | ---- | ---- | -------------- | ----------------- |
| TC-88 | extra | ErrorPipelineEdgeTests.testUnexpectedErrorIsInternalErrorAndNothingLeaks, testCancellationErrorIsAnInternalError | A thrown error carrying SQL, a phone number and a password becomes `INTERNAL_ERROR`; nothing of it is in the body or in any log line; `X-Request-Id` equals the body `request_id` | Pass |
| TC-89 | extra | testAbortStatusTable, testOtherClientErrorsFollowTheDocumentedRule | Abort status to code table (400, 404, 405, 413, 415, 422, 429, 500, 502, 503, 504 and 401, 403, 408, 409, 410, 418); Abort `reason` never leaks | Pass |
| TC-90 | extra | testRetryAfterHintVariants, testDefectRetryAfterHintIsSane | 429 hint `5`, `0`, `abc`, empty, `1.5`; negative and 11-digit hints | Variants Pass; sanity **Fail** (D-10) |
| TC-91 | extra | testMalformedJsonBodyIsValidationFailed | Broken JSON, wrong type, wrong content type give the envelope, 422 | Pass |
| TC-92 | extra | testBodyLimitBoundaryThroughTheLiveTester, testBodyLimitOverRealHttpWithContentLengthAndChunked | 0, 1, 8191, 8192 bytes accepted; 8193 and 32768 give 413 `PAYLOAD_TOO_LARGE` envelope with request id; same over real HTTP with Content-Length and with chunked transfer (no length) | Pass |
| TC-93 | extra | testDefectWrongMethodOnExistingPathIsMethodNotAllowed, testUnknownPathsReturnTheEnvelope | POST, PUT, DELETE, PATCH on `/healthz` (api.md v1.5: wrong method answers 404 `NOT_FOUND`); unknown, NUL, encoded-slash and 4000-character paths give the 404 envelope | 404 for wrong method and unknown paths: Pass (round 3) |
| TC-94 | extra | testClientRequestIdIsIgnoredAndIdsAreUnique, testParallelRequestsKeepOneRequestIdPerLogLine | Forged `X-Request-Id` ignored; 20 sequential and 40 parallel requests get distinct valid UUIDs, one per log line | Pass |
| TC-95 | extra | testAccessLogNeverCarriesRawClientText, testAccessLogCarriesErrorCodeStatusAndDuration | Hostile `X-Platform` and `X-App-Version` (CRLF, uppercase, 4-part version, Arabic-Indic digits, `../`), query string with name and phone, encoded newline path: no raw client text, no line break in any metadata value, one access line per request, route `-` for unmatched | Pass |
| TC-96 | extra | SplitterReviewTests (13 tests) | Standard string backslash literal, `E''` escapes, doubled quotes in identifiers, dollar tags (digits, unicode, nested `$$`), comments inside bodies, `;;`, BOM and NUL input, real migration files split into balanced statements, bad migration file names rejected, missing directory throws | Pass |
| TC-97 | extra | SplitterReviewTests.testDefectDollarSignInsideAnIdentifierIsNotAQuote | `SELECT a$b$c; SELECT 2`: PostgreSQL treats `a$b$c` as one identifier, the scanner opens a dollar quote and returns one statement | **Fail** (D-11) |
| TC-98 | extra | DeadlineEdgeTests (8 tests) | 2000 sequential fast calls, error passthrough, 200 ms timeout on time, operation ignoring cancellation still times out, caller cancel returns `CancellationError` within 1 s, pre-cancelled caller, zero and negative limits, 600 concurrent races where operation and timer finish together (no double resume, no crash). Debug build only; the release-build crash the developer mentions was not reproduced or retested (no `-c release` test possible with `@testable`) | Pass |

Not covered in slice 0 and why: real concurrent double-cancel (needs committed data and two connections; plan TC-19/TC-20 style, add when PostgreSQL is available), Docker image run (no Docker), deploy job (needs secrets), real database stop for TC-54.

### 4.5 Slice 1 executable tests [v1.4 | 2026-10-26]

Commit: e9c097b (base) plus the uncommitted QA files. Command: `cd backend/Tests/qa && swift test` (database tests: add `DATABASE_MIGRATION_URL=postgres://...` of a throwaway database that already holds, or may receive, the schema and sample seed; row-changing tests additionally need `QA_ALLOW_DB_MUTATION=1`). The catalog tests use the API only through the in-memory tester (`app.test`), so they need only the route, not the repository class names; `FixedWallClock` and `app.services.clock` give the controlled clock (E-1 for the catalog part). Results below: round 4 (slice 1, early) on e9c097b.

Legend for the Result column: **XF** = expected to fail until the slice 1 backend merges (route or file absent in e9c097b), **Skip** = needs a database, **Pass** = ran and passed on e9c097b, **Manual** = client or device case, documented in 4.2 and 4.3, not an automated test here.

#### 4.5.1 Plan cases and acceptance criteria of slice 1

| AC / plan case | Slice 1 part | QA test (class.method) | Level | Result on e9c097b |
| -------------- | ------------ | ---------------------- | ----- | ----------------- |
| AC-1 (FR-1) | Logo-only launch, 1.0 to 2.0 s (A-9: guidance) | TC-101, TC-165 (iOS); TC-201, TC-265 (Android) | Manual / UI (clients) | Not run (client branches not merged) |
| AC-2 (FR-2), TC-1 | Shop name, greeting, contacts in the catalog | CatalogContractTests.testTC1_ShapeMatchesTheContract, testTC1_ShopSettingsDistrictsAndSlotsComeFromTheTables | API (DB) | Skip (XF without route) |
| AC-2 on screen | Six elements on S-2, states | TC-102, TC-132 (iOS); TC-202, TC-232 (Android) | Manual / UI | Not run |
| AC-3 (FR-2), TC-69 | `phone_contact` E.164, `zalo_contact` 3+ characters (shape only) | Slice1.shapeProblems via testTC1_ShapeMatchesTheContract; testTC1_CatalogFixturesExistAndSatisfyTheContractCheck | API / fixtures | Skip / XF |
| AC-3 on device | Zalo and dialer open | TC-103, TC-104, TC-105 (iOS); TC-203 to TC-205 (Android) | Manual on real devices (ADR-0015); TC-105 UI with stub | Blocked (no device) |
| AC-4 (FR-3), TC-1 | Exactly four products with picture path, name, description, price, in `sort_order` | testTC1_SampleCakesInSortOrderWithSeedContent, testTC1_ShapeMatchesTheContract, testTC67_EveryImageUrlOfTheCatalogServesAnImage | API (DB) | Skip |
| AC-4 on screen | Four cards, states | TC-106, TC-107, TC-133 (iOS); TC-206, TC-207, TC-233 (Android) | Manual / UI | Not run |
| AC-5 (FR-4) | Order button opens S-5 with that cake at 1 | No API part. TC-108, TC-134 (iOS); TC-208, TC-234 (Android) | Manual / UI | Not run |
| AC-10, AC-11 (catalog part), TC-1 | Slots list without per-date data; districts with fees | testTC1_ShopSettingsDistrictsAndSlotsComeFromTheTables | API (DB) | Skip |
| AC-21 (FR-14), TC-56 | Error envelope for 429, 503, 404 on the slice 1 routes; no server text | testTC54_*, testTC50_*, testExtra_LimitedResponseIsStillTheContractEnvelope..., testTC67_MissingAssetIsNotFoundEnvelope, testExtra_OtherMethods... | API | 429 and 503: XF; 404 asset: Pass |
| AC-21 on screen | All text Vietnamese, keys exist | TC-125 (iOS), TC-225 (Android); keys listed in UI section 8 (the S-1 to S-4 keys all have a copy row: checked by reading) | Manual / UI | Not run |
| AC-27 (FR-19), TC-2 | No payment words or fields in the catalog, privacy page, fixtures | testTC2_NoSampleMarkerPaymentWordOrInternalFieldAnywhere, testTC67_PrivacyPageHasNoPaymentWordsNoRemoteScriptsAndNoTrackers, fixtures check | API / static | Skip / XF / XF |
| AC-27 on screen | No payment text on screens | TC-130 (iOS), TC-230 (Android) | Manual / UI | Not run |
| AC-29, TC-66 | No sample marker in seed text, catalog, fixtures; `is_sample` never exposed | testTC66_SampleSeedTextHasNoVisibleSampleMarker, testTC2_*, DatabaseTests.testSeedRowsAreAllMarkedSample (slice 0) | static / API | static: **Pass**; API: Skip |
| AC-29 on screen | S-2 to S-9 show no marker | TC-131 (iOS), TC-231 (Android) | Manual / UI | Not run |
| TC-3 (ETag, 304) | `ETag` set, `Cache-Control: no-cache`, equal data gives equal ETag, 304 with empty body, price change gives 200 and new ETag | testTC3_Headers200, testTC3_SameDataSameEtagAndConditionalRequestIs304WithEmptyBody, testTC3_PriceChangeGivesNewEtagAndOldEtagIsNoLongerFresh (needs `QA_ALLOW_DB_MUTATION=1`) | API (DB) | Skip |
| TC-50 (rate limit) | 120 per minute pass, the 121st is 429 with `Retry-After` (1 to 60) equal to `details.retry_after_seconds`, envelope, no ETag | ReadRateLimitTests.testTC50_The121stReadInAMinuteIsRateLimited | API (no DB) | **XF** (fails at request 121: no limiter) |
| TC-51 (proxy header) | Default (TRUST_PROXY off): spoofed `X-Forwarded-For` does not reset the budget. The `TRUST_PROXY=true` half needs a config hook not yet specified in code | ReadRateLimitTests.testExtra_SpoofedForwardedForHeaderDoesNotResetTheBudgetByDefault | API (no DB) | XF; trusted half Blocked |
| TC-54 (catalog part) | Database unreachable gives 503 `SERVICE_UNAVAILABLE`, `ERR_SERVER`, no leaks, within 10 s; shallow health stays 200 | CatalogFailureTests.testTC54_UnreachableDatabaseIsServiceUnavailableNotInternalError, testTC54_NoDatabaseConfiguredAtAllIsServiceUnavailableAndDoesNotCrash | API (no DB needed: connection refused) | **XF** (404 today) |
| TC-57 (catalog part) | Wrong method, unknown paths, unknown query parameters answer defined 4xx, no 5xx | testExtra_OtherMethodsAreTheDocumentedNotFoundEnvelope, testExtra_PathVariantsNeverReachAnErrorState, testExtra_UnknownQueryParametersAreHarmlessAndDoNotForkTheCache | API (DB) | Skip |
| TC-62 (catalog part) | `server_date` in shop time at 16:59:59Z and 17:00:00Z, year end | testTC62_ServerDateFollowsShopTimeAroundMidnight | API (DB) | Skip |
| TC-66 | Seed rows are samples; no marker text | see AC-29 | static / DB | static Pass |
| TC-67 | `/privacy` HTML, charset, collected items, purpose, recipients; asset files exist, cache header `public, max-age=86400`, missing asset 404 | StaticContentTests.testTC67_* (7 tests), CatalogContractTests.testTC67_EveryImageUrlOfTheCatalogServesAnImage | API / static | privacy and asset files: **XF**; missing asset 404: Pass |
| TC-53 (catalog under `ORDERING_ENABLED=false`) | Needs the setting (slice 3) and Q-A10 | none yet | | Blocked (slice 3) |
| TC-145, TC-146, TC-132 to TC-134, TC-135 (offline, cache 7 days, S-2 to S-4 states) | Client-side cache and states (ADR-0011) | iOS TC-145, TC-146, TC-132 to TC-134; Android TC-245, TC-246, TC-232 to TC-234 | Manual / UI with stub server (E-5) and the shared fixtures | Not run (client branches not merged) |

#### 4.5.2 Extra cases of slice 1

Reasons are in the Notes column. IDs use the prefix `TC-S1-` because TC-101 and up are the iOS range.

| ID | Type | Test | Notes (reason) | Result on e9c097b |
| -- | ---- | ---- | -------------- | ----------------- |
| TC-S1-01 | extra | CatalogContractTests.testExtra_ConditionalRequestVariants | Strong and weak form of the same tag (RFC 9110 13.1.2 weak comparison for `If-None-Match`), list with spaces and tabs, `*` give 304; different tag, unquoted tag, empty, whitespace, trailing garbage, truncated quote, lowercase `w/`, comma only give 200 with the full body. Reason: a client or proxy may weaken or reorder the tag; a wrong 304 hides a price change | Skip (XF) |
| TC-S1-02 | extra | testExtra_LargeIfNoneMatchNeverCausesAServerError | 1 KB to 1 MB `If-None-Match`, with and without the right tag last: never 5xx, still correct 200 or 304. Reason: parsing cost and crash on odd input | Skip (XF) |
| TC-S1-03 | extra | testExtra_HeaderNameCaseAndRepeatedHeaderLines | Lowercase header name; two `If-None-Match` lines combine as a list (RFC 9110 5.3) | Skip (XF) |
| TC-S1-04 | extra | testExtra_IfModifiedSinceAloneDoesNotProduce304 | No `Last-Modified` is promised; validators are ETag only | Skip (XF) |
| TC-S1-05 | extra | testExtra_EtagChangesWhenOnlyServerDateChanges | `server_date` is in the body, so a new day must not 304 on yesterday's tag (clients use `server_date` instead of the device date) | Skip (XF) |
| TC-S1-06 | extra | testExtra_HeadMirrorsGetWithoutBody | HEAD gives 200, empty body, same ETag. Reason: proxies and monitors | Skip (XF) |
| TC-S1-07 | extra | testExtra_OtherMethodsAreTheDocumentedNotFoundEnvelope | POST, PUT, DELETE, PATCH answer 404 `NOT_FOUND` (api.md v1.5) | Skip (XF) |
| TC-S1-08 | extra | testExtra_UnknownQueryParametersAreHarmlessAndDoNotForkTheCache | `?x=1`, `?slot_id=`, `?cakes=2`, NUL, 5000-character value, `?deep=1`: 200 with identical body and ETag, or 422; never 5xx. Reason: api.md says "none" and is silent on extras (Q-A3); extras must not create new cache entries | Skip (XF) |
| TC-S1-09 | extra | testExtra_PathVariantsNeverReachAnErrorState | Trailing slash, case, double slash, `v2`, NUL, extension: 200 or 404 envelope, never 5xx | Skip (XF) |
| TC-S1-10 | extra | testExtra_AcceptHeaderVariantsStillGetJsonOrNotAcceptable | `Accept: text/html`, `*/*`, XML, `q=0`, garbage | Skip (XF) |
| TC-S1-11 | extra | testExtra_ParallelReadsAreConsistent | 40 parallel reads: same body and ETag. Reason: shared repository state | Skip (XF) |
| TC-S1-12 | extra | testExtra_VietnameseTextIsUtf8NotEscapedAndNotMangled | Literal UTF-8 text `Bánh đậu xanh nhân mỡ`, no `\u` escapes, no U+FFFD, charset utf-8 if stated; the shape check also requires NFC and no control characters in every string | Skip (XF) |
| TC-S1-13 | extra | testTC1_SampleCakesInSortOrderWithSeedContent (values pinned in `Slice1.Seed`) | Order, names, descriptions, prices and ids of the four sample cakes, five districts and four slots equal the seed. Reason: a change of the sample data must be a visible change here | Skip (XF) |
| TC-S1-14 | extra | testExtra_InactiveRowsAreHiddenAndOrderFollowsSortOrder, testExtra_InactiveProductIsHiddenSoClientsSeeFewerThanFour (need `QA_ALLOW_DB_MUTATION=1`) | Inactive district, slot, product are hidden; `sort_order` decides the order; with one cake inactive the server returns three (the app then shows Error, see DOC-10) | Skip |
| TC-S1-15 | extra | CatalogFailureTests.testExtra_ConditionalRequestDuringOutageStillNever304 | `If-None-Match: *` or a tag during an outage must give 503, not 304 | XF |
| TC-S1-16 | extra | testTC54_NoDatabaseConfiguredAtAllIsServiceUnavailableAndDoesNotCrash | No database registered: Fluent traps with `fatalError` if the route asks for it without `Request.databaseHandle` | XF |
| TC-S1-17 | extra | ReadRateLimitTests.testExtra_ReadGroupIsOneSharedBudget | api.md lists `/v1/*`, `/healthz`, `/privacy`, `/assets/*` as one group at 120 per minute (see DOC-3 for the ambiguity) | XF |
| TC-S1-18 | extra | testExtra_SpoofedForwardedForHeaderDoesNotResetTheBudgetByDefault | Changing `X-Forwarded-For` must not reset the limiter with proxy trust off | XF |
| TC-S1-19 | extra | testExtra_LimitedResponseIsStillTheContractEnvelopeForEveryReadRoute | While limited, every read route (including 404 paths) answers the 429 envelope | XF |
| TC-S1-20 | extra | StaticContentTests.testTC67_PrivacyPageHasNoPaymentWordsNoRemoteScriptsAndNoTrackers | No script, no cleartext link, no tracker on the privacy page (public store listing page) | XF |
| TC-S1-21 | extra | testExtra_PrivacyHeadAndMethods | HEAD 200 without body; POST, PUT, DELETE 404; variants never 5xx | XF |
| TC-S1-22 | extra | testExtra_AssetsRouteDoesNotEscapeItsRoot | 13 traversal forms (`..`, encoded, backslash, double slash, dotfiles, NUL) never serve `Package.swift`, a migration or passwd and never 5xx | **Pass** (route absent; must still pass after the route lands) |
| TC-S1-23 | extra | testExtra_AssetsDirectoryAndRootAreNotListed | No directory listing | **Pass** (same remark) |
| TC-S1-24 | extra | testExtra_AssetMethodsRangeAndRevalidation | Cache header on the file, HEAD, `Range` (200 or 206), absurd range not 5xx, `If-None-Match` gives 304 when an ETag is sent, POST/PUT/DELETE not 200 | XF |
| TC-S1-25 | extra | testTC67_MissingAssetIsNotFoundEnvelope | Missing file (also an encoded Vietnamese name) gives the 404 envelope and no `max-age=86400` | **Pass** |
| TC-S1-26 | extra | testExtra_FixtureReadmeListsEveryCatalogFixture | Every fixture file is described in `contracts/fixtures/README.md` | **Pass** |
| TC-S1-27 | extra | testTC67_AssetFilesAreRealImagesOfReasonableSize, testTC67_EverySeedImagePathHasAFileInTheRepository | Four images present for the four seed `image_path` values, magic bytes match the extension, each under 1 MB (mobile data) | XF |
| TC-S1-28 | extra | testTC1_CatalogFixturesExistAndSatisfyTheContractCheck, testTC1_CatalogFixtureMatchesTheSampleSeedWhereItClaimsToBeTheSeed | `contracts/fixtures/catalog-*.json` exist (architecture.md slice 1) and pass the same shape and text checks as the live response, so the three suites agree | XF |
| TC-S1-29 | extra | testTC66_SampleSeedTextHasNoVisibleSampleMarker | Word-boundary scan of every seed string literal (diacritics folded) for sample, demo, test, payment words | **Pass** |

Not automated here (and why): ETag derived from content versus version (not specified, DOC-2); 429 window reset after 60 s (needs a limiter clock hook that is not in the documents; Blocked until the dev guide names one); real HTTP behaviour of header size limits (the in-memory tester does not enforce NIO limits); `TRUST_PROXY=true` (needs the setting); image rendering and placeholder (UI cases TC-107, TC-134); S-1 timing (A-9 guidance, UI only).

What the developers must provide for slice 1 (additions to section 3): the catalog route using `Request.databaseHandle` (503 without a database), asset and privacy files under `backend/assets/` (path of the product images stated in api.md), a limiter whose window can be driven by `app.services.clock` or a test hook, `contracts/fixtures/catalog-ok.json` (plus any other `catalog-*.json`), and a note in the dev guide for `QA_ALLOW_DB_MUTATION`.
