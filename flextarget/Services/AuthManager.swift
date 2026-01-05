import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "currentUser"
    
    private init() {
        loadUser()
    }
    
    func login(user: User) {
        currentUser = user
        isAuthenticated = true
        saveUser()
    }
    
    func logout() async {
        if let accessToken = currentUser?.accessToken {
            do {
                try await UserAPIService.shared.logout(accessToken: accessToken)
            } catch {
                print("Logout API call failed: \(error)")
            }
        }
        
        currentUser = nil
        isAuthenticated = false
        userDefaults.removeObject(forKey: userKey)
        
        // Clear device authentication on logout
        DeviceAuthManager.shared.clearDeviceAuth()
    }
    
    func updateTokens(accessToken: String, refreshToken: String) {
        guard var user = currentUser else { return }
        user.accessToken = accessToken
        user.refreshToken = refreshToken
        currentUser = user
        saveUser()
    }
    
    func updateUserInfo(username: String) {
        guard var user = currentUser else { return }
        user.username = username
        currentUser = user
        saveUser()
    }
    
    private func saveUser() {
        if let user = currentUser {
            do {
                let data = try JSONEncoder().encode(user)
                userDefaults.set(data, forKey: userKey)
            } catch {
                print("Failed to save user: \(error)")
            }
        }
    }
    
    private func loadUser() {
        if let data = userDefaults.data(forKey: userKey) {
            do {
                let user = try JSONDecoder().decode(User.self, from: data)
                currentUser = user
                isAuthenticated = true
            } catch {
                print("Failed to load user: \(error)")
                userDefaults.removeObject(forKey: userKey)
            }
        }
    }
}
