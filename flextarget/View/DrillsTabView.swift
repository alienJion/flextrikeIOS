import SwiftUI
import CoreData

struct DrillsTabView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State private var selectedDrillSetup: DrillSetup? = nil
    @State private var selectedDrillShots: [ShotData]? = nil
    @State private var selectedDrillSummaries: [DrillRepeatSummary]? = nil
    @State private var showConnectView = false
    @State private var showQRScanner = false
    @State private var scannedPeripheralName: String? = nil
    @State private var showConnectionAlert = false
    
    let persistenceController = PersistenceController.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            DrillListView(bleManager: bleManager, showDrillList: .constant(true), onDrillSelected: { drill in
                selectedDrillSetup = drill
            })
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .navigationTitle(NSLocalizedString("drills", comment: "Drills tab title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if bleManager.isConnected {
                            showConnectView = true
                        } else {
                            showQRScanner = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(bleManager.isConnected ? "BleConnect" : "BleDisconnect")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                            Text(bleManager.isConnected ? NSLocalizedString("target_connected", comment: "") : NSLocalizedString("target_disconnected", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(bleManager.isConnected ? .red : .gray)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(bleManager.isConnected ? 0.12 : 0.08))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(bleManager.isConnected ? Color.red.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bleManager.isConnected {
                        NavigationLink(destination: AddDrillView(bleManager: bleManager)) {
                            Image(systemName: "plus")
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: {
                            showConnectionAlert = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // Navigation Link for drill editing
            NavigationLink(isActive: Binding<Bool>(
                get: { selectedDrillSetup != nil },
                set: { newValue in
                    if !newValue {
                        selectedDrillSetup = nil
                    }
                }
            )) {
                if let drill = selectedDrillSetup {
                    EditDrillView(drillSetup: drill, bleManager: bleManager, onCreateNewDrillSetup: { /* handle if needed */ })
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    EmptyView()
                }
            } label: {
                EmptyView()
            }
        }
        .alert(isPresented: $showConnectionAlert) {
            Alert(title: Text(NSLocalizedString("connection_required", comment: "Alert title for connection required")), message: Text(NSLocalizedString("connect_target_first", comment: "Alert message for connecting target first")), dismissButton: .default(Text(NSLocalizedString("ok", comment: "OK button"))))
        }
        .sheet(isPresented: $showConnectView) {
            ConnectSmartTargetView(bleManager: bleManager, navigateToMain: .constant(false), targetPeripheralName: scannedPeripheralName, isAlreadyConnected: bleManager.isConnected, onConnected: { showConnectView = false })
                .id(scannedPeripheralName)
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { scannedText in
                scannedPeripheralName = scannedText
                showQRScanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showConnectView = true
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        DrillsTabView()
            .environmentObject(BLEManager.shared)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
