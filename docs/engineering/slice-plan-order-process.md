# Slice plan: new order process and delivery fee (early review)

Forge early review, 2026-11-02, for admin-orders PRD v1.10 and place-order v1.7 (`docs/product/admin-orders/09-order-process-and-delivery-fee.md`). No code written. Counts are files that match the status literals (`"New"`, `"Confirmed"`, `"Completed"`, `.new/.confirmed/.completed`, `confirm`/`complete` actions) by grep, build folders and `.pbxproj` excluded. A file can still need a change without matching (fee and date work); those are named in section 1. [v1.0 | 2026-11-02]

## 1. What breaks or must change

Backend, 7 source files, 28 test files, 2 SQL files:
- `Services/Admin/Orders/OrderStatus.swift`: enum has 4 cases; `isOpen`, `canMove` (4 moves), `allowedActions` (`confirm`, `complete`, `cancel`) all change. Cancel must be allowed only from Received and Processing.
- `Services/Admin/Orders/OrderListQuery.swift` (filters todo/new/confirmed/completed), `OrderWindow.swift` (raw SQL `status IN ('New','Confirmed')`), `Repositories/Admin/AdminOrderQueries.swift` (`allowedActions`, status reads), `StatusRequest.swift` (parse; `canMove` check), `AdminOrderService.changeStatus`, `AdminOrderStore.move` (compare-and-set: still right, but the UPDATE must also write the fee or date fields in the same statement).
- `Services/Admin/Orders/OrderViews.swift`, `Repositories/Admin/AdminOrderRows.swift`: add expected date, real fee, collect amount; `ReviewAccountStore.swift`, `ReviewAccountCommand.swift` seed demo orders with old status words.
- `Services/OrderPricing.swift`, `OrderRequestHash.swift`, `OrderFieldErrors.swift`, `PostgresOrderRepository+Insert.swift`: the customer total today is cakes + district fee (`expected_total_vnd`, hash, `price_changed` error). Under Q-30/Q-31 the customer sees an estimate and the cakes total; the order-create contract and hash change.
- SQL, `0001_init.sql` and `0003_admin_orders.sql`: `CHECK (status IN (4 values))`, `customer_order_total_is_sum CHECK (total_vnd = items_subtotal_vnd + delivery_fee_vnd)`, `customer_order_immutable()` freezes `delivery_fee_vnd` and `total_vnd`, `customer_order_open_idx` partial index on `('New','Confirmed')`, `customer_order_release_capacity()` (releases `day_load` only on Cancelled; keeps working), `order_event` writes from/to status as text. Old rows hold the old words.
- Push text: I did not find where the admin push message is composed (`FcmPushSender` only sends); needs a follow-up grep, see section 6.
- Tests to rewrite: 28 backend files (AppTests Admin/Database, qa/ folder belongs to probe-qa).

Contracts, 5 files: `fixtures/admin/{order-detail,order-status-change,orders-list,error-order-state-changed,error-status-transition-invalid}.json` plus Swift package `contracts/swift` (`OrderCreatedResponse.swift`, `OrderContractsTests.swift`) for the fee fields; `order-error-price-changed.json`, `catalog-ok.json` if the district fee becomes "estimate".

iOS customer (`ios/BanhApp`), 4 status matches plus fee files: `Core/Order/OrderPricing.swift`, `Features/Order/Review/{OrderSubmitter,ReviewViewModel}.swift`, `Recipient/RecipientViewModel.swift` (district fee line), `OrderPricingTests`, `OrderSubmitterRulesTests`, `HTTPOrderAPITests`, `FlowAndVersionTests`, UI stub `UITestStubOrders.swift`. Review and confirmation screens show estimate wording.

iOS admin (`ios/BanhAdmin` 12, `BanhAdminShared` 2, `Packages/BanhDesign` 3 for `Palette`/`Badges`, tests 6+4): `Core/Models/OrderModels.swift`, `Core/API/OrdersAPI.swift`, `Features/Orders/{OrderDetailView,OrderDetailViewModel,OrderRowView,OrderFilterBar,DetailCards}.swift`, `Core/Support/AStrings*.swift`, `Localizable.xcstrings`, `AccessibilityID.swift`, `Debug/Stub*`, plus staff/cakes/rules views that use the status words (`StaffView`, `CakesView`, `RulesViewModel`, `TokenStore`, `SessionManager` matched "Confirmed" probably by other meaning; check before editing).

Android customer (`android/app`, 11 matches, mostly strings and order screens) and admin (`android/admin` 14, `android/core` 4: `core/model/OrderModels.kt`, `core/design/StatusTokens.kt`, `core/common/ShopDates.kt`): `OrdersApi.kt`, `OrderDetailViewModel.kt`, `OrderTexts.kt`, `FilterBar.kt`, `AdminTags.kt`, `strings.xml`, stub `StubOrders.kt`, tests `OrderDetailReducerTest.kt`, androidTest flows. Android is documented as not built in this host (dev-guide section 8); expect unverified results.

Total with status literals: about 102 files across the repo (backend 37, contracts 5, iOS 32, Android 29), plus fee and date files that do not match the pattern.

## 2. Risks and open technical questions

For atlas-architect:
1. Status storage: keep text with a new CHECK (6 values), or a lookup. Store DB values as new words (Received, Processing, DeliveryDateScheduled, DeliveryStarted, Finished, Cancelled)? Recommend renaming in data (one forward `UPDATE`), not an alias layer.
2. Fee columns: `customer_order.delivery_fee_vnd` is frozen and the CHECK ties `total_vnd` to it. Proposal: keep the old columns as the estimate snapshot (`estimated_fee_vnd` semantic), add `real_fee_vnd integer NULL CHECK (>= 0)`, `fee_entered_by`, `fee_entered_at`; drop the sum CHECK in favour of `total_vnd = items_subtotal_vnd` for cakes total, or keep it for estimate. Decide the definition of `total_vnd`. Collect amount = `items_subtotal_vnd + real_fee_vnd`, computed in the view, not stored.
3. Expected date: `expected_delivery_date date NULL`, movable; each move needs an event (BR-3 record). `order_event.event_type` CHECK has only `created`, `status_changed`: add `expected_date_changed` and `fee_entered` or reuse a side table. `day_load` keeps counting the requested date (Q-36 assumption); confirm so the trigger stays untouched.
4. Transitions: one endpoint `POST /v1/admin/orders/{code}/status` with extra body fields (`expected_delivery_date` on schedule, `delivery_fee_vnd` on start), plus a separate date-move endpoint? Needs the `allowed_actions` vocabulary.
5. Can "Delivery date scheduled" be skipped, or can Delivery started go backwards? Table needed. Can a scheduled date be moved after Delivery started?
6. Stale-view rules: compare-and-set on status alone is not enough for a date move (two staff move the date); add expected old date, or an `updated_at` check.
7. Old orders in the field: Delivered orders with old total and no real fee: collect amount fallback = stored total (state it).
8. Push: text for each new step, and whether the customer gets any push (customer has no account; probably none).

For canvas-ui: step indicator for 6 states; list filter labels (todo/new/confirmed/completed become?); badge colours for 4 new states (`Palette`, `Badges`, `StatusTokens`); fee entry field (VND, 0 allowed, error copy); date picker limits for the expected date; cancel hidden or disabled copy; customer estimate wording; unfinished marking (BR-9) list of states.

## 3. Slice plan (dependency order)

Each slice is one session. Write the named tests first, run them red, then code.

| # | Component | Files | Tests first | Closing check |
|---|---|---|---|---|
| S1 | backend db | new `backend/db/migrations/0008_order_process.sql` | `Admin/OrderMigrationTests`: old rows map, new CHECK, new columns, event types | `cd backend && DATABASE_MIGRATION_URL=<throwaway> swift test --filter OrderMigrationTests` |
| S2 | backend | `OrderStatus.swift` (6 cases, `canMove`, `isOpen`, `allowedActions`), `OrderWindow.swift`, `OrderListQuery.swift` | `OrderStatusRulesTests` rewritten as a matrix (every from/to pair; cancel only before DeliveryDateScheduled) | `swift test --filter OrderStatusRulesTests` |
| S3 | backend | `AdminOrderQueries/Rows/Views`, `StatusRequest`, `AdminOrderService`, `AdminOrderStore.move` | `OrderStatusTests`, `OrderStatusRaceTests`, `CancelDayLoadTests` (fee required and 0 allowed at start, date required at schedule) | `swift test --filter Admin` |
| S4 | backend | date-move endpoint, `order_event` write, route under `adminGroup()` | new `OrderDateMoveTests`; `RoleCoverageTests` must stay green | `swift test --filter "OrderDateMove|RoleCoverage"` |
| S5 | backend | create-order contract: estimate, `OrderPricing`, request hash, `PostgresOrderRepository+Insert` | `OrderPlacementServiceTests`, `OrderPlacementWriteTests` | `swift test --filter OrderPlacement` |
| S6 | backend | remaining 20 or so test files, demo seed (`ReviewAccountStore`, `ReviewAccountCommand`), push text | `ReviewAccountDataTests`, `OrderFixtureTests` | `cd backend && swift test` (full) |
| S7 | contracts | admin fixtures (5), `BanhContracts` order types, README | `OrderContractsTests`, fixture decode tests | `cd contracts/swift && swift test` |
| S8 | iOS customer | `OrderPricing`, review, recipient, stub | `OrderPricingTests`, `OrderSubmitterRulesTests` | xcodebuild `-only-testing:BanhAppTests test` (CLAUDE.md command) |
| S9 | iOS admin A | models, API, view model, `BanhDesign` badges, strings | `OrderDetailViewModelTests`, `ContractFixtureTests` | xcodebuild `-scheme BanhAdmin -only-testing:BanhAdminTests test` |
| S10 | iOS admin B | detail view, row, filter, fee and date inputs, stubs, UI tests | `StatusUITests` | xcodebuild with `BanhAdminUITests` |
| S11 | Android core and customer | `core/model`, `core/design`, `app` order screens, strings | `OrderSubmitErrorsTest`, `ShopDatesTest` | `./gradlew :core:common:testDebugUnitTest :app:testDebugUnitTest` |
| S12 | Android admin | `OrdersApi`, `OrderDetailViewModel`, `OrderTexts`, `FilterBar`, `strings.xml`, stub | `OrderDetailReducerTest` | `./gradlew :admin:testDebugUnitTest` |

S3 and S4 may each exceed one session if the fee, date and compare-and-set work is not split; split further by endpoint. Each file stays at most 200 lines (several tests files are already large: split when edited).

## 4. Migration order

1. Take `pg_dump` of the database first (owner rule; the dump command and storage location are not yet in `dev-guide.md`: add them there in S1, with a restore rehearsal on a throwaway database).
2. Apply `0008_order_process.sql`, forward-only, in one transaction:
   a. drop the status CHECK, the partial index `customer_order_open_idx` and any trigger that names old values;
   b. `UPDATE customer_order SET status` New->Received, Confirmed->Processing, Completed->Finished; same for `order_event.from_status/to_status`;
   c. add the new CHECK (6 values), new columns (`expected_delivery_date`, `real_fee_vnd`, `fee_entered_by`, `fee_entered_at`), the event-type values, relax the sum CHECK per the architect's decision;
   d. recreate the partial index over the 4 open states; `CREATE OR REPLACE` the immutable trigger so the new columns may change and the old fee snapshot stays frozen; capacity trigger is unchanged in logic.
3. Deploy order: migration, then the backend that understands both nothing else (there is no mixed period if the backend ships right after). Old app builds read status words they do not know: the admin apps must ship before or with the backend, or the API must tolerate (architect decision; the admin apps have no forced-update rule I have seen).
4. Down migration: none (forward-only); the rollback is the dump.

## 5. What cannot be built as written

- Q-35 and Q-36 are assumptions, not owner answers: building on them risks rework (requested date holds capacity; unfinished = all open steps).
- The PRD says the "cancel reasons list (four)" stays; an order moved to Delivery date scheduled loses cancel, but the PRD does not say what staff do when the customer refuses at the door (no transition exists). Needs an owner answer.
- "Date may move 1 to 2 days": the PRD gives no limit for the move; I would not enforce a limit without a rule.
- Real fee entry at "Start delivery" with "0 allowed" gives no way to correct a mistyped fee after the status changes: needs a rule (BR for editing) or the fee is final.
- Estimated fee on the customer side while `customer_order_total_is_sum` demands total = cakes + fee: cannot be built without the migration decision in section 2.

## 6. Checklist

Read: the PRD change file `09-order-process-and-delivery-fee.md`, `OrderStatus.swift`, `OrderWindow.swift`, `AdminOrderStore.swift`, `0003_admin_orders.sql` (lines 25-125), `0001_init.sql` (grep only), the dev-guide (grep only).
Verified by grep: the file lists and counts above, migration list (0001-0007), CHECK and trigger text in 0001/0003, the transition table and actions.
Not verified: no build or test was run (early mode, no code); iOS and Android per-file counts were not opened one by one (some matches may be other meanings, for example "Confirmed" in auth and cakes files); where the push text is composed (grep found only `FcmPushSender`); `docs/system/order-lifecycle.md` and the api documents were not read; the exact `pg_dump` procedure; whether other triggers after 0003 name old statuses (0004-0007 not read); no check that old app versions tolerate unknown status words.
