import Foundation

class CompetitionAPIService {
    static let shared = CompetitionAPIService()
    
    private let baseURL = "https://etarget.topoint-archery.cn"
    private let session = URLSession.shared
    
    // MARK: - Response Models
    
    struct APIResponse<T: Codable>: Codable {
        let code: Int
        let msg: String
        let data: T?
    }
    
    struct GamePlayResponse: Codable {
        let device_uuid: String
        let play_uuid: String
    }
    
    // MARK: - API Methods
    
    /// Submit competition/game play data to the server
    /// - Parameters:
    ///   - gameType: Game type (required)
    ///   - gameVer: Game version (required)
    ///   - score: Game score (required)
    ///   - detail: Game details as JSON
    ///   - playTime: Time of play in format "2025-12-12 12:23:35" (required)
    ///   - playerMobile: Player's mobile number
    ///   - playerNickname: Player's nickname
    ///   - userAccessToken: User's access token
    ///   - isPublic: Whether the competition is public (default: true)
    ///   - namespace: Namespace (default: "default")
    func addGamePlay(
        gameType: String,
        gameVer: String,
        score: Float,
        detail: [String: Any],
        playTime: String,
        playerMobile: String?,
        playerNickname: String?,
        userAccessToken: String,
        isPublic: Bool = true,
        namespace: String = "default"
    ) async throws -> GamePlayResponse {
        let url = URL(string: "\(baseURL)/game/play/add")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get authorization header with device token if available
        let authHeader = DeviceAuthManager.shared.getAuthorizationHeaderValue(userAccessToken: userAccessToken)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "game_type": gameType,
            "game_ver": gameVer,
            "score": score,
            "detail": detail,
            "play_time": playTime,
            "is_public": isPublic,
            "namespace": namespace
        ]
        
        if let mobile = playerMobile {
            body["player_mobile"] = mobile
        }
        
        if let nickname = playerNickname {
            body["player_nickname"] = nickname
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, _) = try await session.data(for: request)
        let response: APIResponse<GamePlayResponse> = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "CompetitionAPI", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.msg])
        }
        
        guard let gameData = response.data else {
            throw NSError(domain: "CompetitionAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }
        
        return gameData
    }
}
