import SwiftUI
import UIKit

/**
 `DrillDurationConfigurationView` is a SwiftUI component for configuring drill duration.

 This view provides:
 - A wheel picker for selecting drill duration in seconds
 - Visual feedback with a clock icon
 - Clean visual design matching app style
 */

struct DrillRepeatsPauseConfView: View {
    @Binding var drillDuration: Double
    var disabled: Bool = false

    // Duration options from 5 to 30 seconds in 1-second increments
    private let durationOptions: [Double] = Array(stride(from: 5, through: 30, by: 1))

    // State for sheet presentation
    @State private var showDurationPicker: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundColor(.red)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.08)))

            Text(NSLocalizedString("drill_pause_seconds_label", comment: "Drill pause in seconds label"))
                .foregroundColor(.white)
                .font(.headline)

            Spacer()

            Button(action: {
                if !disabled {
                    showDurationPicker = true
                }
            }) {
                HStack(spacing: 6) {
                    Text("\(Int(drillDuration))")
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
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerView(
                durationOptions: durationOptions,
                selectedDuration: $drillDuration,
                onDone: { showDurationPicker = false }
            )
        }
    }
}

// Custom wheel picker with red text using UIViewRepresentable
struct CustomWheelPicker: UIViewRepresentable {
    @Binding var selection: Double
    let options: [Double]

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator

        // Set initial selection
        if let index = options.firstIndex(of: selection) {
            picker.selectRow(index, inComponent: 0, animated: false)
        }

        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        // Update selection if it changed externally
        if let index = options.firstIndex(of: selection) {
            uiView.selectRow(index, inComponent: 0, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: CustomWheelPicker

        init(_ parent: CustomWheelPicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 1
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            return parent.options.count
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = view as? UILabel ?? UILabel()
            label.text = "\(Int(parent.options[row]))s"
            label.textColor = .red // Set text color to red
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            parent.selection = parent.options[row]
        }
    }
}

struct DurationPickerView: View {
    let durationOptions: [Double]
    @Binding var selectedDuration: Double
    var onDone: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(durationOptions, id: \.self) { duration in
                        Button(action: {
                            // set selection and dismiss
                            selectedDuration = duration
                            onDone?()
                        }) {
                            HStack {
                                Text("\(Int(duration))s")
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedDuration == duration {
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
                .scrollContentBackgroundHidden()
            }
            .navigationTitle(NSLocalizedString("select_duration", comment: "Select Duration navigation title"))
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
        }
    }
}

struct DrillDurationConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                DrillRepeatsPauseConfView(
                    drillDuration: .constant(15)
                )
            }
            .padding()
        }
    }
}
