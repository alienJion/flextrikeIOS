import SwiftUI

struct LoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var authManager = AuthManager.shared

    let onDismiss: () -> Void
    /// 为 true 时显示取消按钮（如模态弹出时），点击调用 onDismiss
    var showCancelButton: Bool = false

    @State private var mobile = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case mobile
        case password
    }

    private var isFormValid: Bool {
        !mobile.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Image("GrwolfLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 270, maxHeight: 108)

                        Text(NSLocalizedString("user_login", comment: "User login title"))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text(NSLocalizedString("login_subtitle", comment: "Login subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                .padding(.top, showCancelButton ? 52 : 32)
                .padding(.bottom, 40)

                // Form card
                VStack(alignment: .leading, spacing: 20) {
                    // Mobile
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("mobile_number", comment: "Mobile number placeholder"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)

                        TextField(NSLocalizedString("mobile_number", comment: ""), text: $mobile, prompt: Text(NSLocalizedString("mobile_number", comment: "")).foregroundColor(.gray.opacity(0.7)))
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .mobile)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(focusedField == .mobile ? 0.25 : 0.12), lineWidth: 1)
                            )
                            .foregroundColor(.white)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("password", comment: "Password placeholder"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)

                        SecureField(NSLocalizedString("password", comment: ""), text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { if isFormValid { login() } }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(focusedField == .password ? 0.25 : 0.12), lineWidth: 1)
                            )
                            .foregroundColor(.white)
                    }

                    // Error
                    if showError {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(10)
                    }

                    // Login button
                    Button(action: login) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.1)
                            } else {
                                Text(NSLocalizedString("login", comment: "Login button"))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isLoading || !isFormValid ? Color.gray.opacity(0.4) : Color.red)
                    )
                    .disabled(isLoading || !isFormValid)
                    .animation(.easeInOut(duration: 0.2), value: isFormValid)
                }
                .padding(24)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            if showCancelButton {
                Button(action: onDismiss) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.red)
                        .frame(width: 60, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.top, 8)
                .padding(.leading, 8)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            showError = false
            errorMessage = ""
        }
    }

    private func login() {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = ""
        showError = false
        focusedField = nil

        Task {
            do {
                let m = mobile.trimmingCharacters(in: .whitespaces)
                let loginData = try await UserAPIService.shared.login(mobile: m, password: password)
                let user = User(
                    userUUID: loginData.user_uuid,
                    mobile: m,
                    accessToken: loginData.access_token,
                    refreshToken: loginData.refresh_token
                )
                authManager.login(user: user)
                await MainActor.run { onDismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run { isLoading = false }
        }
    }
}
