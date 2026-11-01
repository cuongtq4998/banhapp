import BanhCore
import BanhDesign
import PhotosUI
import SwiftUI

/// S-A8 Cake form (add and edit).
struct CakeFormView: View {
    @Bindable var model: CakeFormViewModel
    let baseURL: URL
    let onBack: () -> Void
    @FocusState private var focus: String?

    var body: some View {
        SettingsScaffold(title: title, screen: AdminOwnerID.cakeForm, onBack: back, showsBar: showsBar) {
            if model.isGone {
                StateView(
                    symbol: "questionmark.folder", message: AStrings.cakeGone, actionTitle: AStrings.backToList,
                    actionIdentifier: AdminOwnerID.cakeBackToList, action: onBack
                )
                .accessibilityElement(children: .contain).accessibilityIdentifier(AdminOwnerID.cakeGone)
            } else {
                LoadStateView(load: model.load, screen: AdminOwnerID.cakeForm, retry: { Task { await model.retryLoad() } }) { _ in form }
            }
        } bar: { bar }
        .task { await model.loadCake() }
        .onChange(of: model.focusRequest) { _, id in focus = id }
        .discardDialog(isPresented: $model.showsDiscard, discard: onBack)
        .background {
            Color.clear.alert(AStrings.removeTitle(name: model.cake?.name ?? ""), isPresented: $model.showsRemoveDialog) {
                Button(String(localized: AStrings.back), role: .cancel) {}
                Button(String(localized: AStrings.removeYes), role: .destructive) { Task { await model.confirmRemove() } }
                    .accessibilityIdentifier(AdminOwnerID.cakeRemoveYes)
            } message: { Text(AStrings.removeBody) }
        }
    }

    private var title: String {
        model.isAdd ? String(localized: AStrings.addCakeTitle) : (model.cake?.name ?? "")
    }

    private var showsBar: Bool { !model.isGone && model.load.value != nil }

    private func back() {
        if model.isDirty { model.showsDiscard = true } else { onBack() }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let text = model.banner {
                InlineMessage(kind: .error, text: text).accessibilityIdentifier(AdminOwnerID.saveError)
            }
            if model.isAdd { CakePictureField(model: model) } else { editPicture }
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    FormTextField(
                        label: AStrings.fCakeName, text: $model.name, identifier: AdminOwnerID.cakeName, error: model.errors["name"],
                        errorIdentifier: AdminOwnerID.fieldError(AdminOwnerID.cakeForm, "name"), focus: $focus
                    )
                    FormTextField(
                        label: AStrings.fCakeDesc, text: $model.description, identifier: AdminOwnerID.cakeDesc,
                        error: model.errors["description"], errorIdentifier: AdminOwnerID.fieldError(AdminOwnerID.cakeForm, "description"),
                        multiline: true, limit: 300, focus: $focus
                    )
                    NumberField(
                        label: AStrings.fPrice, text: $model.price, identifier: AdminOwnerID.cakePrice, error: model.errors["price_vnd"],
                        errorIdentifier: AdminOwnerID.fieldError(AdminOwnerID.cakeForm, "price_vnd"), suffix: "đ", focus: $focus
                    )
                }
            }
            .disabled(model.phase == .saving)
            if model.isAdd {
                Text(AStrings.newCakeActive).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
            } else {
                editExtras
            }
        }
    }

    private var editPicture: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            CakeThumbnail(path: model.cake?.imageUrl ?? "", baseURL: baseURL)
                .frame(maxWidth: .infinity).frame(height: 160)
                .accessibilityIdentifier(AdminOwnerID.cakeImage)
            Text(AStrings.imgNotEditable).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
        }
    }

    @ViewBuilder
    private var editExtras: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle(isOn: Binding(get: { model.isActive }, set: { model.setActive($0) })) {
                    Text(AStrings.cakeActiveToggle).textStyle(Typography.bodyStrong)
                }
                .tint(Palette.primary)
                .accessibilityIdentifier(AdminOwnerID.cakeActive)
                Text(AStrings.cakeHiddenHelp).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
        }
        Text(AStrings.newOrdersOnly).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
        ActionButton(title: AStrings.removeCake, emphasis: .destructive, showsProgress: model.phase == .removing) {
            model.requestRemove()
        }
        .disabled(model.isBusy)
        .accessibilityIdentifier(AdminOwnerID.cakeRemove)
    }

    @ViewBuilder
    private var bar: some View {
        VStack(spacing: Spacing.sm) {
            if model.phase == .saving && model.isAdd {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text(verbatim: AStrings.uploading).textStyle(Typography.bodyStrong)
                }
                .accessibilityElement(children: .combine).accessibilityIdentifier(AdminOwnerID.cakeProgress)
                ActionButton(title: AStrings.cancelUpload, emphasis: .secondary) { model.cancelUpload() }
                    .accessibilityIdentifier(AdminOwnerID.cakeCancel)
            } else {
                ActionButton(title: model.isAdd ? AStrings.addCakeSave : AStrings.save, showsProgress: model.phase == .saving) {
                    focus = nil
                    model.startSave()
                }
                .disabled(!model.canSave)
                .accessibilityIdentifier(AdminOwnerID.cakeSave)
            }
        }
    }
}

/// Add mode: the native photo picker (no permission prompt), the preview and the two text buttons.
struct CakePictureField: View {
    @Bindable var model: CakeFormViewModel
    @State private var item: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let data = model.pickedJPEG, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .accessibilityIdentifier(AdminOwnerID.cakeImagePreview)
                HStack {
                    picker(AStrings.imgChange, id: AdminOwnerID.cakeImageChange)
                    Spacer()
                    TextLinkButton(AStrings.imgRemovePick) { model.removePicture() }
                }
            } else {
                picker(AStrings.imgPick, id: AdminOwnerID.cakeImage, boxed: true)
            }
            if let error = model.errors["image"] {
                FieldError(text: error, identifier: AdminOwnerID.fieldError(AdminOwnerID.cakeForm, "image"))
            }
            #if DEBUG
            if UserDefaults.standard.string(forKey: AdminLaunch.stub) != nil { DebugPickButton(model: model) }
            #endif
        }
        .disabled(model.phase == .saving)
        .onChange(of: item) { _, new in
            guard let new else { return }
            Task {
                await model.pick(try? await new.loadTransferable(type: Data.self))
                item = nil
            }
        }
    }

    private func picker(_ title: LocalizedStringResource, id: String, boxed: Bool = false) -> some View {
        PhotosPicker(selection: $item, matching: .images) {
            if boxed {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "photo.badge.plus").font(.largeTitle)
                    Text(title).textStyle(Typography.bodyStrong)
                }
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(Palette.surfaceSolid, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            } else {
                Text(title).textStyle(Typography.smallButton).foregroundStyle(Palette.primary).frame(minHeight: Size.touchTarget)
            }
        }
        .accessibilityIdentifier(id)
    }
}
