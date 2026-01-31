import SwiftUI

/*
 */

struct TargetsSectionView: View {
    @Binding var isTargetListReceived: Bool
    let bleManager: BLEManager
    @Binding var targetConfigs: [DrillTargetsConfigData]
    let onTargetConfigDone: () -> Void
    var disabled: Bool = false
    var onDisabledTap: (() -> Void)? = nil
    var drillMode: String = "ipsc"

    var body: some View {
        Group {
            if disabled, let onDisabledTap = onDisabledTap {
                Button(action: onDisabledTap) {
                    targetsRowContent
                }
            } else {
                ZStack(alignment: .leading) {
                    targetsRowContent
                        .allowsHitTesting(false)

                    NavigationLink(destination: TargetConfigListView(deviceList: bleManager.networkDevices, targetConfigs: $targetConfigs, onDone: onTargetConfigDone, drillMode: drillMode)) {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .opacity(0)
                    .disabled(!isTargetListReceived)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .navigationTitle(NSLocalizedString("drill_setup", comment: "Navigation title for Drill Setup"))
            }
        }
    }

    private var targetsRowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 16))
                .foregroundColor(.red)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.08)))

            Text(NSLocalizedString("targets", comment: "Targets label"))
                .foregroundColor(.white)
                .font(.headline)

            Spacer()

            Text(String(format: NSLocalizedString("targets_count_label", comment: "Number of targets"), targetConfigs.count))
                .foregroundColor(.gray)
                .font(.subheadline)

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(targetConfigs.count > 0 ? 0.08 : 0.06))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .opacity(isTargetListReceived ? 1.0 : 0.6)
    }
}

struct DrillSetupSectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                TargetsSectionView(
                    isTargetListReceived: .constant(true),
                    bleManager: BLEManager.shared,
                    targetConfigs: .constant([
                        DrillTargetsConfigData(seqNo: 1, targetName: "Target A", targetType: "Standard", timeout: 30, countedShots: 5),
                        DrillTargetsConfigData(seqNo: 2, targetName: "Target B", targetType: "Paper", timeout: 25, countedShots: 3),
                        DrillTargetsConfigData(seqNo: 3, targetName: "Target C", targetType: "Electronic", timeout: 20, countedShots: 10)
                    ]),
                    onTargetConfigDone: {}
                )
            }
            .padding()
        }
        .environmentObject(BLEManager.shared)
    }
}
