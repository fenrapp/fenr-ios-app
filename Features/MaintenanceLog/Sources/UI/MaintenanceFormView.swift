import Foundation
import SwiftUI

public struct MaintenanceFormView: View {
    @ObservedObject private var viewModel: MaintenanceViewModel
    private let entryID: UUID?
    private let onNavigation: (MaintenanceNavigationEvent) -> Void
    @State private var draft: MaintenanceFormDraft
    @State private var presentedSelection: Selection?
    @FocusState private var focusedField: Field?

    public init(
        viewModel: MaintenanceViewModel,
        entryID: UUID?,
        onNavigation: @escaping (MaintenanceNavigationEvent) -> Void
    ) {
        self.viewModel = viewModel
        self.entryID = entryID
        self.onNavigation = onNavigation
        _draft = State(initialValue: viewModel.makeDraft(id: entryID))
    }

    public var body: some View {
        Form {
            Section(.maintenanceWorkSection) {
                Button {
                    focusedField = nil
                    presentedSelection = .maintenanceType
                } label: {
                    HStack(spacing: Constants.typeRowSpacing) {
                        Text(.maintenanceFieldType)
                            .foregroundStyle(.primary)
                        Spacer(minLength: Constants.typeRowSpacing)
                        if let selectedOption {
                            Label(selectedOption.title, systemImage: selectedOption.symbolName)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                if draft.kindID == Constants.customKindID {
                    TextField(String(localized: .maintenanceCustomName), text: $draft.customName)
                        .focused($focusedField, equals: .customName)
                }
                DatePicker(
                    .maintenanceFieldDate,
                    selection: $draft.performedAt,
                    in: ...draft.maximumPerformedAt,
                    displayedComponents: .date
                )
                LabeledContent {
                    TextField(String(), text: $draft.odometerText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .odometer)
                } label: {
                    Text(.maintenanceOdometerPrompt(viewModel.formState.distanceUnit))
                }
                LabeledContent {
                    TextField(String(), text: $draft.ridingHoursText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .ridingHours)
                } label: {
                    Text(.maintenanceRidingHoursPrompt)
                }
            }

            Section(.maintenanceAdditionalSection) {
                TextField(String(localized: .maintenanceFieldWorkshop), text: $draft.workshop)
                    .focused($focusedField, equals: .workshop)
                LabeledContent {
                    TextField(String(), text: $draft.costText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .cost)
                } label: {
                    Text(.maintenanceFieldCost)
                }
                Button {
                    focusedField = nil
                    presentedSelection = .currency
                } label: {
                    HStack(spacing: Constants.typeRowSpacing) {
                        Text(.maintenanceFieldCurrency)
                            .foregroundStyle(.primary)
                        Spacer(minLength: Constants.typeRowSpacing)
                        Text(verbatim: draft.currencyCode)
                            .foregroundStyle(.tint)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                TextField(String(localized: .maintenanceFieldNotes), text: $draft.notes, axis: .vertical)
                    .lineLimit(Constants.notesLineRange)
                    .focused($focusedField, equals: .notes)
            }

            Section {
                if let guidance = viewModel.officialGuidance(kindID: draft.kindID) {
                    Label(guidance, systemImage: "book.closed.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if viewModel.hasOfficialSchedule(kindID: draft.kindID) {
                    Button(.maintenanceApplyOfficialSchedule) {
                        viewModel.applyOfficialRecommendation(to: &draft)
                    }
                }
                Toggle(.maintenanceDateReminder, isOn: $draft.hasDateReminder)
                if draft.hasDateReminder {
                    DatePicker(
                        .maintenanceDueDate,
                        selection: $draft.dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Toggle(.maintenanceHoursReminder, isOn: $draft.hasHoursReminder)
                if draft.hasHoursReminder {
                    TextField(String(localized: .maintenanceDueHours), text: $draft.dueHoursText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .dueHours)
                }
                Toggle(.maintenanceOdometerReminder, isOn: $draft.hasOdometerReminder)
                if draft.hasOdometerReminder {
                    TextField(
                        String(localized: .maintenanceDueOdometerPrompt(viewModel.formState.distanceUnit)),
                        text: $draft.dueOdometerText
                    )
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .dueOdometer)
                }
            } header: {
                Text(.maintenanceNextSection)
            } footer: {
                Text(.maintenanceReminderFooter)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded { focusedField = nil },
            including: .gesture
        )
        .navigationTitle(entryID == nil ? Text(.maintenanceNewTitle) : Text(.maintenanceEditTitle))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedSelection) { selection in
            NavigationStack {
                switch selection {
                case .maintenanceType:
                    MaintenanceTypeSelectionView(
                        options: viewModel.formState.options,
                        selection: $draft.kindID
                    )
                case .currency:
                    MaintenanceCurrencySelectionView(
                        options: viewModel.formState.currencyOptions,
                        selection: $draft.currencyCode
                    )
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    viewModel.save(draft) {
                        onNavigation(.close(.form(id: entryID)))
                    }
                } label: {
                    if viewModel.isMutating {
                        ProgressView()
                            .accessibilityLabel(Text(.maintenanceSaving))
                    } else {
                        Text(.maintenanceSave)
                    }
                }
                .disabled(viewModel.isMutating)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(.maintenanceDone) { focusedField = nil }
            }
        }
    }

    private var selectedOption: MaintenanceFormViewState.Option? {
        viewModel.formState.options.first { $0.id == draft.kindID }
    }

    private enum Field: Hashable {
        case customName
        case odometer
        case ridingHours
        case workshop
        case cost
        case notes
        case dueHours
        case dueOdometer
    }

    private enum Selection: Hashable, Identifiable {
        case maintenanceType
        case currency

        var id: Self { self }
    }

    private enum Constants {
        static let customKindID = "custom"
        static let notesLineRange = 3 ... 7
        static let typeRowSpacing: CGFloat = 8
    }
}
