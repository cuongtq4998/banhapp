import BanhContracts
import SwiftUI

/// Navigation of the order flow, S-5 to S-8 (MVVM-C). It owns the `OrderFlow`, builds each step's
/// screen with closures for moving on, and never holds business logic: rules live in the flow and the
/// step view models. The root view owns the path itself and passes it in.
@MainActor
final class OrderCoordinator {
    private let environment: AppEnvironment
    private let now: () -> Date
    private var flow: OrderFlow?
    private var submitter: OrderSubmitter?
    /// Set by the screen that owns the path, so a send that finishes can replace the stack.
    private var showConfirmation: ((String) -> Void)?

    init(environment: AppEnvironment, now: @escaping () -> Date = { Date() }) {
        self.environment = environment
        self.now = now
    }

    /// Starts the flow and returns the route of its first screen. From a cake detail (`cake` given) a
    /// new draft starts with that cake at 1; otherwise the saved draft is restored, with no prompt
    /// (ADR-0011, FR-4, AC-5).
    func start(startingWith cake: ResourceID? = nil) -> Route {
        showConfirmation = nil
        let store = environment.draftStore
        let draft: OrderDraft
        if let cake {
            draft = newDraft(startingWith: cake)
            store.save(draft)
        } else {
            draft = store.load(now: now()) ?? OrderDraft(savedAt: now())
        }
        let flow = OrderFlow(draft: draft, repository: environment.catalogRepository, store: store, now: now)
        self.flow = flow
        // The path is the root view's, so the submitter reaches it through `showConfirmation`.
        submitter = OrderSubmitter(flow: flow, api: environment.orderAPI) { [weak self] placed in
            self?.showConfirmation?(placed.code)
        }
        return .orderStep(.cakes)
    }

    private func newDraft(startingWith cake: ResourceID) -> OrderDraft {
        var draft = OrderDraft(savedAt: now())
        if case .ready(let catalog) = environment.catalogRepository.catalog,
           let product = catalog.products.first(where: { $0.productID == cake }) {
            draft.setQuantity(1, of: product.productID, name: product.name)
        }
        return draft
    }

    /// Pushes the step after `step`.
    func advance(from step: OrderStep, path: inout [Route]) {
        guard let next = OrderStep(rawValue: step.rawValue + 1) else { return }
        path.append(.orderStep(next))
    }

    /// Goes back to `step`, which is already on the stack: the data of the steps in between is kept in
    /// the flow (FR-15, AC-18).
    func edit(_ step: OrderStep, path: inout [Route]) {
        if let index = path.lastIndex(of: .orderStep(step)) {
            path.removeSubrange((index + 1)...)
        } else {
            path.append(.orderStep(step))
        }
    }

    @ViewBuilder
    func screen(for step: OrderStep, path: Binding<[Route]>) -> some View {
        let flow = currentFlow()
        switch step {
        case .cakes:
            CakesStepView(
                model: CakesViewModel(flow: flow, assetBaseURL: environment.assetBaseURL),
                onNext: { self.advance(from: .cakes, path: &path.wrappedValue) }
            )
        case .date:
            DateStepView(
                model: DateViewModel(flow: flow, api: environment.availabilityAPI),
                onNext: { self.advance(from: .date, path: &path.wrappedValue) },
                onEditCakes: { self.edit(.cakes, path: &path.wrappedValue) }
            )
        case .recipient:
            RecipientStepView(
                model: RecipientViewModel(flow: flow),
                onNext: { self.advance(from: .recipient, path: &path.wrappedValue) }
            )
        case .review:
            ReviewStepView(
                model: ReviewViewModel(flow: flow, submitter: submitter),
                onEdit: { self.edit($0, path: &path.wrappedValue) }
            )
            .onAppear { self.showConfirmation = { path.wrappedValue = [.orderConfirmed(code: $0)] } }
        }
    }

    /// S-9. Back and the home button both end at S-2; the draft was already cleared when the order was received.
    func confirmation(code: String, path: Binding<[Route]>) -> some View {
        ConfirmationView(
            model: ConfirmationViewModel(
                code: code, repository: environment.catalogRepository,
                contact: ContactActions(opener: environment.urlOpener)
            ),
            onHome: { path.wrappedValue = [] }
        )
    }

    /// The flow of the running order; a screen asked for without `start` (a restored stack) restores the draft.
    private func currentFlow() -> OrderFlow {
        if let flow { return flow }
        _ = start()
        return flow!
    }
}
