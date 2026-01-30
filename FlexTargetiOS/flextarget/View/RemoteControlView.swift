import SwiftUI

struct RemoteControlView: View {
    @ObservedObject var bleManager = BLEManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showVolume = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        showVolume.toggle()
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "shape.rectangle.portrait")
                            .foregroundColor(.white)
                        Text(bleManager.connectedPeripheral?.name ?? NSLocalizedString("device", comment: "Device"))
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                
                // Instruction
                Text(NSLocalizedString("remote_control_instruction", comment: "Swipe to navigate • Tap to select"))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                Spacer()
                
                // Touch Pad
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 350, height: 350)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                    
                    // Gesture area
                    Color.clear
                        .frame(width: 350, height: 350)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    dragOffset = value.translation
                                    isDragging = true
                                }
                                .onEnded { value in
                                    let horizontal = value.translation.width
                                    let vertical = value.translation.height
                                    
                                    if abs(horizontal) > abs(vertical) {
                                        if horizontal > 50 {
                                            sendCommand("right")
                                        } else if horizontal < -50 {
                                            sendCommand("left")
                                        }
                                    } else {
                                        if vertical > 50 {
                                            sendCommand("down")
                                        } else if vertical < -50 {
                                            sendCommand("up")
                                        }
                                    }
                                    
                                    dragOffset = .zero
                                    isDragging = false
                                }
                        )
                        .gesture(
                            TapGesture()
                                .onEnded {
                                    sendCommand("enter")
                                }
                        )
                }
                
                Spacer()
                
                // Navigation Buttons
                VStack(spacing: 20) {
                    HStack(spacing: 60) {
                        Button(action: {
                            sendCommand("back")
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                                Image(systemName: "arrow.left")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: {
                            sendCommand("homepage")
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                                Image(systemName: "house")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    if showVolume {
                        HStack(spacing: 60) {
                            Button(action: {
                                sendCommand("volume_down")
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                        )
                                    Image(systemName: "minus")
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button(action: {
                                sendCommand("volume_up")
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                        )
                                    Image(systemName: "plus")
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func sendCommand(_ command: String) {
        let message: [String: Any] = [
            "action": "remote_control",
            "directive": command
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: message, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            bleManager.writeJSON(jsonString)
        }
    }
}