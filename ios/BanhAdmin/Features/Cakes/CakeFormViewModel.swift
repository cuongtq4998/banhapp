import BanhContracts
import BanhCore
import Foundation
import Observation

/// S-A8 Cake form, add and edit (FR-21, BR-12). One form, two modes; the picture is only chosen when adding.
@Observable
final class CakeFormViewModel {
    enum Mode: Equatable { case add, edit(String) }
    enum Phase { case idle, saving, removing }

    let mode: Mode
    var name = ""
    var description = ""
    var price = ""
    var isActive = true
    private(set) var pickedJPEG: Data?
    private(set) var load: Load<Cake> = .loading
    var isGone = false
    private(set) var phase = Phase.idle
    var errors: [String: String] = [:]
    var banner: String?
    var focusRequest: String?
    var showsRemoveDialog = false
    var showsDiscard = false
    /// The message of the last refused picture; Save shows it again while no valid picture replaced it.
    private var imageProblem: String?
    var original: Cake?
    private var activeCount = 0
    private var saveTask: Task<Void, Never>?
    private let api: any OwnerAPI
    let flash: (String) -> Void
    private let done: () -> Void

    init(mode: Mode, api: any OwnerAPI, flash: @escaping (String) -> Void, done: @escaping () -> Void) {
        self.mode = mode
        self.api = api
        self.flash = flash
        self.done = done
        if mode == .add { load = .ready(Cake(cakeId: "", name: "", description: "", priceVnd: 0, isActive: true, imageUrl: "")) }
    }

    var isAdd: Bool { mode == .add }
    var cake: Cake? { original }
    var isBusy: Bool { phase != .idle }

    // MARK: Loading (edit)

    func loadCake() async {
        guard case .edit(let id) = mode else { return }
        do {
            let settings = try await api.settings()
            activeCount = settings.activeCakes
            guard let cake = settings.cakes.first(where: { $0.cakeId == id }) else { isGone = true; return }
            original = cake
            name = cake.name
            description = cake.description
            price = FieldRules.grouped(String(cake.priceVnd))
            isActive = cake.isActive
            load = .ready(cake)
        } catch {
            if !(error is SessionEnded) { load = .failed(error.loadFailure) }
        }
    }

    func retryLoad() async {
        load = .loading
        await loadCake()
    }

    // MARK: Fields

    var isDirty: Bool {
        guard let original else {
            return isAdd && (!name.isEmpty || !description.isEmpty || !price.isEmpty || pickedJPEG != nil)
        }
        return FieldRules.trimmed(name) != original.name || FieldRules.trimmed(description) != original.description
            || FieldRules.number(price) != original.priceVnd || isActive != original.isActive
    }

    /// Add: enabled once anything is typed or a picture is chosen; tapping it lists every missing or
    /// invalid field (spec v1.3). Edit: enabled once something differs.
    var canSave: Bool { !isBusy && isDirty }

    /// Hiding the only active cake is refused at once: the switch stays on (AC-32).
    func setActive(_ on: Bool) {
        if !on, original?.isActive == true, activeCount <= 1 {
            flash(String(localized: AStrings.errLastCake))
            return
        }
        isActive = on
    }

    // MARK: Picture (add)

    /// Decodes and re-encodes the picked photo as JPEG (ADR-0025); a rejected picture is not kept.
    func pick(_ data: Data?) async {
        errors["image"] = nil
        imageProblem = nil
        guard let data else { return fail(image: AStrings.errImgRead) }
        switch await Task.detached(operation: { CakeImage.prepare(data) }).value {
        case .success(let jpeg): pickedJPEG = jpeg
        case .failure(.tooManyBytes): fail(image: AStrings.errImgSize)
        case .failure(.tooSmall): fail(image: AStrings.errImgDimSmall)
        case .failure(.tooLarge): fail(image: AStrings.errImgDimLarge)
        case .failure(.unreadable): fail(image: AStrings.errImgRead)
        }
    }

    private func fail(image text: LocalizedStringResource) {
        pickedJPEG = nil
        errors["image"] = String(localized: text)
        imageProblem = errors["image"]
    }

    func removePicture() {
        pickedJPEG = nil
        imageProblem = nil
    }

    // MARK: Validation

    @discardableResult
    func validate() -> Bool {
        var found: [String: String] = [:]
        if let text = FieldRules.text(name, AStrings.fCakeName, max: 100) { found["name"] = text }
        if let text = FieldRules.text(description, AStrings.fCakeDesc, max: 300) { found["description"] = text }
        if let text = FieldRules.integer(price, AStrings.fPrice, range: 1...100_000_000) { found["price_vnd"] = text }
        if isAdd, pickedJPEG == nil { found["image"] = imageProblem ?? String(localized: AStrings.errImgRequired) }
        errors = found
        let order = [("name", AdminOwnerID.cakeName), ("description", AdminOwnerID.cakeDesc), ("price_vnd", AdminOwnerID.cakePrice)]
        focusRequest = order.first { found[$0.0] != nil }?.1
        return found.isEmpty
    }

    // MARK: Save

    /// Starts the save so that `cancelUpload()` can stop it.
    func startSave() { saveTask = Task { await save() } }

    func cancelUpload() { saveTask?.cancel() }

    func save() async {
        banner = nil
        guard validate() else { return }
        phase = .saving
        defer { phase = .idle }
        do {
            if isAdd {
                guard let jpeg = pickedJPEG, let value = FieldRules.number(price) else { return }
                _ = try await api.addCake(
                    name: FieldRules.trimmed(name), description: FieldRules.trimmed(description), priceVnd: value, jpeg: jpeg
                )
            } else if case .edit(let id) = mode {
                _ = try await api.updateCake(id: id, changes: changes())
            }
            guard !Task.isCancelled else { return }
            flash(String(localized: isAdd ? AStrings.cakeAdded : AStrings.saved))
            done()
        } catch {
            guard !Task.isCancelled else { return }
            apply(error)
        }
    }

    private func changes() -> [String: JSONValue] {
        guard let original else { return [:] }
        var result: [String: JSONValue] = [:]
        if FieldRules.trimmed(name) != original.name { result["name"] = .string(FieldRules.trimmed(name)) }
        if FieldRules.trimmed(description) != original.description { result["description"] = .string(FieldRules.trimmed(description)) }
        if let value = FieldRules.number(price), value != original.priceVnd { result["price_vnd"] = .int(value) }
        if isActive != original.isActive { result["is_active"] = .bool(isActive) }
        return result
    }

    // MARK: Remove (edit)

    func requestRemove() {
        if original?.isActive == true, activeCount <= 1 {
            flash(String(localized: AStrings.errLastCake))
        } else {
            showsRemoveDialog = true
        }
    }

    func confirmRemove() async {
        guard case .edit(let id) = mode else { return }
        showsRemoveDialog = false
        phase = .removing
        defer { phase = .idle }
        do {
            try await api.removeCake(id: id)
            flash(String(localized: AStrings.cakeRemoved))
            done()
        } catch {
            apply(error)
        }
    }
}
