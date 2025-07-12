import SwiftUI

struct OrientationView: View {
    @State var steps: [OrientationStep] = []
    @State var selectedStep: Int = 0
    @State private var navigateToConnect = false
    @StateObject var bleManager = BLEManager()

    var body: some View {
        NavigationStack {
            VStack {
                if !steps.isEmpty && selectedStep < steps.count {
                    OrientationStepView(step: $steps[selectedStep], onNext: {
                        if selectedStep < steps.count - 1 {
                            selectedStep += 1
                        } else {
                            navigateToConnect = true
                        }
                    }, onStepCompleted: {
                        saveStepsToLocal()
                    })
                }
            }
            .onAppear {
                loadStepsFromLocal()
                if let firstIncomplete = steps.firstIndex(where: { !$0.isCompleted }) {
                    selectedStep = firstIncomplete
                } else {
                    // All steps complete, go to next screen
                    navigateToConnect = true
                }
            }
            .navigationDestination(isPresented: $navigateToConnect) {
                ConnectSmartTargetView(bleManager: bleManager)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    private func loadStepsFromLocal() {
        if let data = UserDefaults.standard.data(forKey: "orientationSteps"),
           let savedSteps = try? JSONDecoder().decode([OrientationStep].self, from: data) {
            steps = savedSteps
        } else {
            guard let localVideoURL = Bundle.main.url(forResource: "Orientation", withExtension: "mp4") else {
                print("Orientation.mp4 not found in bundle")
                return
            }
            steps = [
                OrientationStep(step: "Step 1", title: "Setup My Target", videoURL: localVideoURL,
                                subTitle: "Power It Up, Wait Patiently Until You See the Main Menu Screen", thumbNail: "test", isCompleted: false),
                OrientationStep(step: "Step 2", title: "Stage the App", videoURL: localVideoURL,
                                subTitle: "Power It Up, Wait Patiently Until You See the Main Menu Screen", thumbNail: "", isCompleted: false),
                OrientationStep(step: "Step 3", title: "Choose your Drill", videoURL: localVideoURL,
                                subTitle: "Power It Up, Wait Patiently Until You See the Main Menu Screen", thumbNail: "", isCompleted: false),
                OrientationStep(step: "Step 4", title: "Finish the Drill", videoURL: localVideoURL,
                                subTitle: "Power It Up, Wait Patiently Until You See the Main Menu Screen", thumbNail: "", isCompleted: false)
            ]
        }
    }

    private func saveStepsToLocal() {
        if let data = try? JSONEncoder().encode(steps) {
            UserDefaults.standard.set(data, forKey: "orientationSteps")
        }
    }
}
