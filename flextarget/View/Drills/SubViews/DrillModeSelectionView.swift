import SwiftUI

fileprivate struct DrillModeOption: Identifiable {
    let id: String
    let title: String
}

struct DrillModeSelectionView: View {
    @Binding var drillMode: String
    var disabled: Bool = false

    private let modeOptions: [DrillModeOption] = [
        DrillModeOption(id: "ipsc", title: "IPSC"),
        DrillModeOption(id: "idpa", title: "IDPA"),
        DrillModeOption(id: "cqb", title: "CQB")
    ]

    @State private var showModePicker: Bool = false

    private var currentModeTitle: String {
        modeOptions.first(where: { $0.id == drillMode })?.title ?? drillMode.uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 16))
                .foregroundColor(.red)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.08)))

            Text(NSLocalizedString("drill_mode", comment: "Drill Mode label"))
                .foregroundColor(.white)
                .font(.headline)

            Spacer()

            Button(action: {
                if !disabled {
                    showModePicker = true
                }
            }) {
                HStack(spacing: 6) {
                    Text(currentModeTitle)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .sheet(isPresented: $showModePicker) {
            DrillModePickerView(
                modeOptions: modeOptions,
                selectedMode: $drillMode,
                onDone: { showModePicker = false }
            )
        }
    }
}

private struct DrillModePickerView: View {
    let modeOptions: [DrillModeOption]
    @Binding var selectedMode: String
    var onDone: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(modeOptions) { mode in
                        Button(action: {
                            selectedMode = mode.id
                            onDone?()
                        }) {
                            HStack {
                                Text(mode.title)
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedMode == mode.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(Color.gray.opacity(0.2))
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
            }
            .navigationTitle(NSLocalizedString("drill_mode", comment: "Drill Mode label"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        onDone?()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationViewStyle(.stack)
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        onDone?()
                    }
                    .foregroundColor(.red)
                }
            }
            #endif
        }
    }
}

struct DrillModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                DrillModeSelectionView(drillMode: .constant("ipsc"))
                DrillModeSelectionView(drillMode: .constant("idpa"))
                DrillModeSelectionView(drillMode: .constant("cqb"), disabled: true)
            }
            .padding()
        }
    }
}
