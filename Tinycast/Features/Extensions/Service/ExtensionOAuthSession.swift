import AppKit
import Foundation

struct ExtensionOAuthAuthorizeOptions: Sendable {
    let url: URL
    let state: String?
}

struct ExtensionOAuthAuthorizeResult: Sendable {
    let authorizationCode: String
    let accessToken: String?
    let state: String?
}

/// An OAuth 2.0 PKCE session: the browser authorizes and an `oauth` callback completes it.
@MainActor
final class ExtensionOAuthSession {
    private var continuation: CheckedContinuation<[String: String], Error>?
    private var expectedState: String?
    private var timeoutTask: Task<Void, Never>?
    private var operationID: UUID?
    private let openURL: (URL) -> Bool

    private static weak var activeSession: ExtensionOAuthSession?

    init(openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.openURL = openURL
    }

    /// True while this session is waiting for the browser to come back.
    var isAuthorizing: Bool {
        continuation != nil
    }

    enum OAuthError: LocalizedError {
        case canceled
        case failed(String)
        case stateMismatch

        var errorDescription: String? {
            switch self {
            case .canceled: return "Authentication was canceled."
            case .failed(let message): return message
            case .stateMismatch: return "OAuth state mismatch. Please try authenticating again."
            }
        }
    }

    /// What a deep link turned out to be, so the caller can tell "not ours" from "too late".
    enum Callback {
        case delivered
        case expired
        case ignored
    }

    /// Deep links from the app delegate, such as `raycast://oauth?code=…`.
    static func handleCallbackURL(_ url: URL) -> Callback {
        guard let scheme = url.scheme?.lowercased(),
            scheme == "raycast" || scheme == "tinycast" || scheme == "com.raycast"
        else { return .ignored }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        guard
            host == "oauth" || host == "redirect"
                || path == "/oauth" || path == "/redirect"
                || path.hasPrefix("/oauth/") || path.hasPrefix("/redirect/")
        else {
            return .ignored
        }

        // The browser can come back after the session is gone: quit, timed out, or torn down.
        guard let active = activeSession else { return .expired }
        active.receiveCallback(url: url)
        return .delivered
    }

    func authorize(options: ExtensionOAuthAuthorizeOptions) async throws -> ExtensionOAuthAuthorizeResult {
        let params = try await authorize(url: options.url, expectedState: options.state)
        let code = params["code"] ?? ""
        let token = params["access_token"]
        let state = params["state"]
        return ExtensionOAuthAuthorizeResult(authorizationCode: code, accessToken: token, state: state)
    }

    func authorize(
        url: URL,
        expectedState: String? = nil
    ) async throws -> [String: String] {
        try Task.checkCancellation()
        cancel()
        Self.activeSession?.cancel()

        let operationID = UUID()
        self.operationID = operationID
        self.expectedState = expectedState
        Self.activeSession = self

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                timeoutTask = Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(300))
                    } catch {
                        return
                    }
                    guard let self, self.operationID == operationID else { return }
                    self.finish(error: OAuthError.failed("Authentication timed out."))
                }
                if !openURL(url) {
                    finish(error: OAuthError.failed("Failed to open authorization URL in default browser."))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.operationID == operationID else { return }
                self.cancel()
            }
        }
    }

    private func receiveCallback(url: URL) {
        let params = Self.parseCallback(url: url)
        if let error = params["error"] {
            let desc = params["error_description"] ?? error
            finish(error: OAuthError.failed(desc))
            return
        }

        if let expected = expectedState, !expected.isEmpty {
            guard let received = params["state"], !received.isEmpty, received == expected else {
                finish(error: OAuthError.stateMismatch)
                return
            }
        }

        finish(result: params)
    }

    private func finish(result: [String: String]? = nil, error: Error? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil
        operationID = nil

        if Self.activeSession === self {
            Self.activeSession = nil
        }

        if let continuation = self.continuation {
            self.continuation = nil
            if let error {
                continuation.resume(throwing: error)
            } else if let result {
                continuation.resume(returning: result)
            } else {
                continuation.resume(throwing: OAuthError.canceled)
            }
        }
    }

    func cancel() {
        finish(error: OAuthError.canceled)
    }

    // MARK: - URL Parsing

    static func parseCallback(url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        var result: [String: String] = [:]
        if let queryItems = components.queryItems {
            for item in queryItems {
                result[item.name] = item.value ?? ""
            }
        }
        // Implicit and hash callbacks arrive as `raycast://oauth#code=…`.
        if let fragment = components.fragment, !fragment.isEmpty {
            let pairs = fragment.split(separator: "&")
            for pair in pairs {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0])
                    let val = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                    result[key] = val
                }
            }
        }
        return result
    }
}
