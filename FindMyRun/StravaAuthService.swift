//
//  StravaAuthService.swift
//  FindMyRun
//

import Foundation
import AuthenticationServices

@Observable
final class StravaAuthService {
    private(set) var athlete: AthleteProfile?
    private(set) var stats: AthleteStats?
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let clientId = "220687"
    private let redirectURI = "findmyrun://auth/callback"
    private let supabaseURL = "https://fznbkrpgfhfeahkdehps.supabase.co"

    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt: Int = 0

    private enum Keys {
        static let accessToken = "strava_access_token"
        static let refreshToken = "strava_refresh_token"
        static let expiresAt = "strava_expires_at"
        static let athleteProfile = "strava_athlete_profile"
    }

    init() {
        loadStoredTokens()
    }

    // MARK: - OAuth Flow

    /// Start the Strava OAuth flow via ASWebAuthenticationSession
    @MainActor
    func authorize() async {
        let scope = "read,activity:read"
        let authURL = "https://www.strava.com/oauth/mobile/authorize?client_id=\(clientId)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scope)&approval_prompt=auto"

        guard let url = URL(string: authURL) else { return }

        do {
            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(url: url, callback: .customScheme("findmyrun")) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    }
                }
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }

            // Extract the authorization code
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                errorMessage = "No authorization code received"
                return
            }

            await exchangeCode(code)
        } catch {
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                // User cancelled — not an error
                return
            }
            errorMessage = "Auth error: \(error.localizedDescription) (code: \((error as NSError).code))"
            print("Strava auth error: \(error)")
        }
    }

    /// Exchange auth code for tokens via Supabase Edge Function
    private func exchangeCode(_ code: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(supabaseURL)/functions/v1/strava-token-exchange") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "code": code,
            "grant_type": "authorization_code"
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Token exchange failed"
                return
            }

            let tokenResponse = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
            saveTokens(tokenResponse)

            isAuthenticated = true
            athlete = tokenResponse.athlete

            // Fetch full stats
            if let athleteId = tokenResponse.athlete?.id {
                await fetchStats(athleteId: athleteId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch Athlete Stats

    func fetchStats(athleteId: Int) async {
        guard let accessToken, !accessToken.isEmpty else { return }

        // Refresh token if expired
        if Int(Date().timeIntervalSince1970) >= expiresAt {
            await refreshAccessToken()
        }

        guard let currentToken = self.accessToken,
              let url = URL(string: "https://www.strava.com/api/v3/athletes/\(athleteId)/stats") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            stats = try JSONDecoder().decode(AthleteStats.self, from: data)
        } catch {
            // Stats fetch failed silently
        }
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async {
        guard let refreshToken,
              let url = URL(string: "\(supabaseURL)/functions/v1/strava-token-exchange") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let tokenResponse = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
            saveTokens(tokenResponse)
        } catch {
            // Refresh failed — user will need to re-auth
        }
    }

    // MARK: - Logout

    func logout() {
        accessToken = nil
        refreshToken = nil
        expiresAt = 0
        athlete = nil
        stats = nil
        isAuthenticated = false

        KeychainHelper.delete(for: Keys.accessToken)
        KeychainHelper.delete(for: Keys.refreshToken)
        KeychainHelper.delete(for: Keys.expiresAt)
        KeychainHelper.delete(for: Keys.athleteProfile)
    }

    // MARK: - Token Storage

    private func saveTokens(_ response: StravaTokenResponse) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        expiresAt = response.expiresAt

        KeychainHelper.save(Data(response.accessToken.utf8), for: Keys.accessToken)
        KeychainHelper.save(Data(response.refreshToken.utf8), for: Keys.refreshToken)
        KeychainHelper.save(Data("\(response.expiresAt)".utf8), for: Keys.expiresAt)

        if let athlete = response.athlete,
           let data = try? JSONEncoder().encode(athlete) {
            KeychainHelper.save(data, for: Keys.athleteProfile)
        }
    }

    private func loadStoredTokens() {
        if let tokenData = KeychainHelper.load(for: Keys.accessToken) {
            accessToken = String(data: tokenData, encoding: .utf8)
        }
        if let refreshData = KeychainHelper.load(for: Keys.refreshToken) {
            refreshToken = String(data: refreshData, encoding: .utf8)
        }
        if let expiresData = KeychainHelper.load(for: Keys.expiresAt),
           let expiresString = String(data: expiresData, encoding: .utf8) {
            expiresAt = Int(expiresString) ?? 0
        }
        if let profileData = KeychainHelper.load(for: Keys.athleteProfile) {
            athlete = try? JSONDecoder().decode(AthleteProfile.self, from: profileData)
        }

        isAuthenticated = accessToken != nil && !accessToken!.isEmpty
    }
}
