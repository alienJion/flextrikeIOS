import SwiftUI
import CoreData

struct AdminTabView: View {
    @Environment(\.managedObjectContext) var managedObjectContext

    var body: some View {
        AdminContentView()
            .environment(\.managedObjectContext, managedObjectContext)
    }
}

// MARK: - Admin route (push navigation)

private enum AdminRoute: Hashable {
    case deviceMgmt
    case userProfile
    case qrScanner
}

struct AdminContentView: View {
    @Environment(\.managedObjectContext) var managedObjectContext

    @State private var path = NavigationPath()
    @State private var scannedPeripheralName: String? = nil
    @State private var showConnectView = false
    @State private var showLoginModal = false

    @ObservedObject var bleManager = BLEManager.shared
    @ObservedObject var authManager = AuthManager.shared

    let persistenceController = PersistenceController.shared

    var isDeviceConnected: Bool {
        bleManager.isConnected && bleManager.connectedPeripheral != nil
    }

    private func popToRoot() {
        path = NavigationPath()
    }

    var body: some View {
        NavigationStack(path: $path) {
            mainMenuView
                .navigationTitle(NSLocalizedString("admin", comment: "Admin tab title"))
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: AdminRoute.self) { route in
                    switch route {
                    case .deviceMgmt:
                        AdminDeviceManagementView(
                            bleManager: bleManager,
                            isDeviceConnected: isDeviceConnected
                        )
                    case .userProfile:
                        UserProfileView(
                            onDismiss: { if !path.isEmpty { path.removeLast() } },
                            useSystemBackButton: true
                        )
                    case .qrScanner:
                        QRScannerView(
                            onQRScanned: { code in
                                popToRoot()
                                scannedPeripheralName = code
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    showConnectView = true
                                }
                            },
                            hideBackButton: false
                        )
                    }
                }
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: authManager.isAuthenticated) { newValue in
            if !newValue {
                popToRoot()
                showLoginModal = true
            }
        }
        .fullScreenCover(isPresented: $showLoginModal) {
            LoginView(onDismiss: { showLoginModal = false }, showCancelButton: true)
        }
        .sheet(isPresented: $showConnectView) {
            ConnectSmartTargetView(
                bleManager: bleManager,
                navigateToMain: .constant(false),
                targetPeripheralName: scannedPeripheralName,
                isAlreadyConnected: bleManager.isConnected,
                onConnected: { showConnectView = false }
            )
        }
    }

    // MARK: - Main menu (beautified)

    private var mainMenuView: some View {
        ScrollView {
            VStack(spacing: 16) {
                adminMenuRow(
                    icon: "iphone.and.arrow.forward",
                    title: NSLocalizedString("device_management", comment: "Device Management"),
                    description: isDeviceConnected
                        ? NSLocalizedString("device_connected", comment: "Device is connected")
                        : NSLocalizedString("connect_device", comment: "Connect to a device"),
                    isActive: isDeviceConnected
                ) {
                    path.append(AdminRoute.deviceMgmt)
                }

                if authManager.isAuthenticated {
                    adminMenuRow(
                        icon: "person.circle.fill",
                        title: authManager.currentUser?.username ?? NSLocalizedString("user_profile", comment: "User Profile"),
                        description: NSLocalizedString("manage_profile", comment: "Manage user profile"),
                        isActive: false
                    ) {
                        path.append(AdminRoute.userProfile)
                    }
                } else {
                    adminMenuRow(
                        icon: "person.circle.fill",
                        title: NSLocalizedString("login", comment: "Login"),
                        description: NSLocalizedString("user_login", comment: "User login"),
                        isActive: false
                    ) {
                        showLoginModal = true
                    }
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }

    private func adminMenuRow(
        icon: String,
        title: String,
        description: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().stroke(Color.red.opacity(0.4), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device management (push destination, beautified)

private struct AdminDeviceManagementView: View {
    let bleManager: BLEManager
    let isDeviceConnected: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isDeviceConnected {
                    NavigationLink(destination: ConnectSmartTargetView(
                        bleManager: bleManager,
                        navigateToMain: .constant(false),
                        isAlreadyConnected: true,
                        hideCloseButton: true
                    )) {
                        deviceRow(
                            icon: "antenna.radiowaves.left.and.right",
                            title: NSLocalizedString("connected_device", comment: "Connected device"),
                            subtitle: bleManager.connectedPeripheral?.name ?? NSLocalizedString("manage_connection", comment: "Manage connection")
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: OTAUpdateView()) {
                        deviceRow(
                            icon: "arrow.triangle.2.circlepath.circle",
                            title: NSLocalizedString("ota_update_title", comment: "OTA Update"),
                            subtitle: NSLocalizedString("ota_update_description", comment: "Check for and install system updates")
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(destination: ManualDeviceSelectionView(bleManager: bleManager)) {
                        deviceRow(
                            icon: "list.bullet.rectangle.portrait",
                            title: NSLocalizedString("manual_select_title", comment: "Manual Select"),
                            subtitle: NSLocalizedString("manual_select_description", comment: "Browse and select available devices")
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: AdminRoute.qrScanner) {
                        deviceRow(
                            icon: "qrcode.viewfinder",
                            title: NSLocalizedString("scan_qr_code", comment: "Scan QR Code"),
                            subtitle: NSLocalizedString("scan_device_qr", comment: "Scan device QR code")
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle(NSLocalizedString("device_management", comment: "Device Management"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deviceRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.red)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().stroke(Color.red.opacity(0.4), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        AdminTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
