# Admin Orders Test Plan: Traceability and Questions for PRD v1.10 (part 16)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.1). Holds: the map of every changed id to its new tests, tests of the old plan that are superseded, ids with no test, and questions found in the documents (new in v2.1 [v2.1 | 2026-11-02]). Early mode: `Not run`.

## 4.26 Changed ids to tests

| Id | Tests |
| -- | ----- |
| BR-2 | TC-B201 to TC-B207, TC-B221 to TC-B233, TC-B431 to TC-B438 |
| BR-8 | TC-B226, TC-B227, TC-B230 |
| BR-9 | TC-B403 to TC-B412, TC-B418 to TC-B424, TC-B436 |
| BR-11 | TC-B301 to TC-B316, TC-B454, TC-B456 |
| BR-15 | TC-B331 to TC-B351, TC-B361 to TC-B365, TC-B435 |
| FR-9 | TC-B401, TC-B407, TC-B422, TC-B423, TC-C401, TC-C406 |
| FR-10 | TC-B415 to TC-B417, TC-B425, TC-C404 |
| FR-13 | TC-B402, TC-B413, TC-B414, TC-C403, TC-C405 |
| FR-14 | TC-B248, TC-B318 to TC-B320, TC-B325, TC-B351, TC-C313 |
| FR-16 | TC-B202, TC-B209, TC-C201 |
| FR-17 | TC-B203, TC-B212, TC-C202 |
| FR-18 | TC-B221 to TC-B232, TC-C203 |
| FR-19 | TC-B208 to TC-B215, TC-B312, TC-B341, TC-C204, TC-C205, TC-C311 |
| FR-23 | TC-B246, TC-B451 to TC-B458, TC-C411 to TC-C416 |
| FR-28 | TC-B331 to TC-B351, TC-B342 to TC-B346, TC-C301 to TC-C303, TC-C312 |
| FR-29 | TC-B301 to TC-B317, TC-C304 to TC-C309, TC-C311 |
| AC-26 | TC-B202, TC-B215, TC-C201 |
| AC-27 | TC-B203, TC-C202 |
| AC-28 | TC-B221 to TC-B228, TC-B232, TC-B233, TC-C203 |
| AC-29 | TC-B208 to TC-B210, TC-B228, TC-B341, TC-C204 |
| AC-37 | TC-B451 to TC-B453, TC-B458, TC-C411, TC-C413, TC-C416 |
| AC-40 | TC-B454, TC-B455, TC-C412 |
| AC-41 | TC-B321, TC-B322, TC-B434, TC-C415 |
| AC-49 | TC-B331 to TC-B333, TC-B347, TC-B361, TC-C301 to TC-C303 |
| AC-50 | TC-B301 to TC-B311, TC-B324, TC-C304 to TC-C308 |
| AC-51 | TC-B318 to TC-B320, TC-B323, TC-C309 |
| AC-52 | TC-B401 to TC-B406, TC-C401, TC-C402 |

Superseded old cases (kept in their parts, result "Superseded 2026-11-02", replaced as shown): TC-B75 by TC-B202; TC-B76 by TC-B203, TC-B205; TC-B77 to TC-B79 by TC-B221 to TC-B225; TC-B80 to TC-B84 by TC-B208 to TC-B212, TC-B232; TC-B82 (16 pairs, 4 allowed) by TC-B201 (matrix, 6 allowed plus repeats); TC-B49, TC-B52 (New and Confirmed seeds) by TC-B401, TC-B407; TC-B132, TC-B139, TC-B144 by TC-B451, TC-B454, TC-B321; TC-C21 to TC-C23, TC-C35, TC-C38 by TC-C201 to TC-C205, TC-C311. Backend QA files that use `new`, `confirmed`, `completed` stay red until forge-dev migrates; Probe rewrites them in execute mode. [v2.1 | 2026-11-02]

## 4.27 Ids with no test and developer needs

No test: none for the ids in the task list. Not testable as written: "Processing about 1 day" and "date may move about 1 to 2 days" (BR-2, BR-15) are descriptions, tested only as "not enforced" (TC-B339, TC-B340); the customer-pays-at-handover statement (BR-15) has no system behaviour to test beyond display. Needs from developers (E-15 to E-18): a way to set orders to any status in the seed loader (including migration fixtures with old statuses); the controlled clock for the shop's today at 23:59 and 00:00 (E-1, exists); a contract fixture per status with and without expected date and fee for iOS and Android decode tests (TC-F02, TC-F03 extended); an api document that names the actions, error codes and the view field.

## 4.28 Questions and document findings (for the orchestrator to route)

| ID | To | Question or finding |
| -- | -- | ------------------- |
| Q-P1 | atlas, requirements | "Repeat" (FR-19) is defined by target status equal to current. What when A2 (first date, from the P view) arrives after another device already moved P to S? Treat as a move or refuse as stale (TC-B343)? |
| Q-P2 | requirements | Can a wrong real fee be corrected after Start delivery? AC-50 says no fee at any other step, so a typo (250 000 for 25 000) cannot be fixed by anyone. Intended? What does a different fee on a D order answer (TC-B313)? |
| Q-P3 | requirements | Expected date has a lower bound (today) but no upper bound; a date years ahead is accepted. Owner wants a limit (TC-B338)? |
| Q-P4 | atlas | Is the client's view (expected status) required on every action, and what if absent (TC-B214)? |
| Q-P5 | requirements, atlas | Does the customer see the order, expected date or real fee anywhere (confirmation, history)? PO AC-14 only covers review; no AC covers the customer after ordering (TC-B247). |
| Q-P6 | requirements | Which slot belongs to an order with an expected date (list tie-break, row text), and does the date filter (FR-10) use the expected date? BR-9 names the list date for marks, badge, order only. |
| Q-P7 | atlas, requirements | Migration of the fee: old orders hold a stored district fee and total (AC-41 old wording). Keep as real fee, or mark as estimate? Old Finished orders never passed "started delivery": what does the detail show for the fee? |
| Q-P8 | requirements | 09 impact table lists PO AC-35 and AC-36 and the push ACs (AC-42 to AC-44) for rewrite or check but v1.10 changed neither; do new-order notifications still say "new order", and does Finish or date move send any? Q-35 says no customer message. |
| DOC-1 | requirements | 09 section 16.1 is titled "five steps" (OD-2) and BR-2 lists six statuses with Cancelled; wording only. 09 table 16.2 still holds old text as history (stated), fine. |
| DOC-2 | requirements | BR-2 says cancel returns cakes "to the requested date at once", while Q-38 (open) asks to move capacity to the expected date. Tests follow BR-15; a "yes" to Q-38 would invalidate TC-B233, TC-B361 to TC-B365. |
| DOC-3 | requirements | AC-29 carries three version labels ([v1.10], [v1.5]) in one cell; the "second cancel with another reason" sentence is v1.5 text. Harmless. |
| DOC-4 | atlas | docs/system (order-lifecycle.md, admin-order-handling.md, api) still describe New, Confirmed, Completed with "Completed at any time after Confirmed"; they must be updated before execute mode. |
| DOC-5 | canvas-ui | Design copy for the six status labels, the "told at delivery" text, the fee and date forms is needed to fix the expected strings of TC-C201 to TC-C207, TC-C304 to TC-C309. |
