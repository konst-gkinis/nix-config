import CryptoKit
import Foundation
import Network

/// What `meeting-daemon google-auth` stores; the daemon reads Google only when
/// this file exists.
struct GoogleCredentials: Codable {
    var client_id: String
    var client_secret: String
    var refresh_token: String

    static var fileURL: URL {
        let config = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
            .map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        return config.appendingPathComponent("meeting-daemon/google.json")
    }

    static func load() -> GoogleCredentials? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(GoogleCredentials.self, from: data)
    }
}

private let scope = "https://www.googleapis.com/auth/calendar.events.readonly"
private let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

/// The primary calendar of the Google account you authorised, read directly
/// through the Calendar API (complements Calendar.app, merged by title+start).
final class GoogleCalendarSource: MeetingSource {
    let name = "Google Calendar API"
    private let credentials: GoogleCredentials
    private var accessToken: String?
    private var tokenExpiry = Date.distantPast
    private var cache: (fetched: Date, meetings: [Meeting])?

    init(credentials: GoogleCredentials) {
        self.credentials = credentials
    }

    func meetings(from: Date, to: Date) throws -> [Meeting] {
        // The daemon polls every 15 s; Google only needs asking once a minute.
        if let cache, Date().timeIntervalSince(cache.fetched) < 60 { return cache.meetings }

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        let iso = ISO8601DateFormatter()
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: iso.string(from: from)),
            URLQueryItem(name: "timeMax", value: iso.string(from: to)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "maxResults", value: "50"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        let meetings = try parseGoogleEvents(try fetch(request), source: name)
        cache = (Date(), meetings)
        return meetings
    }

    private func token() throws -> String {
        if let accessToken, Date() < tokenExpiry { return accessToken }
        let body = try fetch(formRequest(tokenURL, [
            "client_id": credentials.client_id,
            "client_secret": credentials.client_secret,
            "refresh_token": credentials.refresh_token,
            "grant_type": "refresh_token",
        ]))
        let response = try JSONDecoder().decode(TokenResponse.self, from: body)
        accessToken = response.access_token
        tokenExpiry = Date() + TimeInterval(response.expires_in - 60)
        return response.access_token
    }
}

private struct TokenResponse: Decodable {
    var access_token: String
    var expires_in: Int
    var refresh_token: String?
}

private func formRequest(_ url: URL, _ fields: [String: String]) -> URLRequest {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    let body = fields
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)" }
        .joined(separator: "&")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(body.utf8)
    return request
}

/// Synchronous HTTP; the daemon's polling is sequential anyway.
private func fetch(_ request: URLRequest) throws -> Data {
    var request = request
    request.timeoutInterval = 20
    var result: Result<Data, Error> = .failure(SourceError(description: "no response"))
    let done = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
            result = .failure(error)
        } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(decoding: data ?? Data(), as: UTF8.self)
            result = .failure(SourceError(description: "HTTP \(http.statusCode): \(body.prefix(300))"))
        } else {
            result = .success(data ?? Data())
        }
        done.signal()
    }.resume()
    done.wait()
    return try result.get()
}

// MARK: - One-time authorisation (`meeting-daemon google-auth <client_secret.json>`)

/// OAuth for an installed app: a loopback redirect to a one-shot local HTTP
/// listener, with PKCE. Stores the refresh token (mode 600).
func googleAuth(clientSecretPath: String) throws {
    let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: clientSecretPath)))
    let client = ((raw as? [String: Any])?["installed"] ?? (raw as? [String: Any])?["web"]) as? [String: Any]
    guard let clientID = client?["client_id"] as? String,
          let clientSecret = client?["client_secret"] as? String
    else { throw SourceError(description: "\(clientSecretPath) isn't a Google OAuth client JSON (Desktop app)") }

    let verifier = base64URL(Data((0..<48).map { _ in UInt8.random(in: 0...255) }))
    let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))

    let listener = try LoopbackListener()
    let redirect = "http://127.0.0.1:\(listener.port)"
    var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    auth.queryItems = [
        URLQueryItem(name: "client_id", value: clientID),
        URLQueryItem(name: "redirect_uri", value: redirect),
        URLQueryItem(name: "response_type", value: "code"),
        URLQueryItem(name: "scope", value: scope),
        URLQueryItem(name: "access_type", value: "offline"),
        URLQueryItem(name: "prompt", value: "consent"),
        URLQueryItem(name: "code_challenge", value: challenge),
        URLQueryItem(name: "code_challenge_method", value: "S256"),
    ]
    print("Opening the Google consent page. If nothing opens, visit:\n\(auth.url!)\n")
    runProcess("/usr/bin/open", [auth.url!.absoluteString])

    let code = try listener.waitForCode()
    let body = try fetch(formRequest(tokenURL, [
        "client_id": clientID,
        "client_secret": clientSecret,
        "code": code,
        "code_verifier": verifier,
        "redirect_uri": redirect,
        "grant_type": "authorization_code",
    ]))
    guard let refresh = try JSONDecoder().decode(TokenResponse.self, from: body).refresh_token else {
        throw SourceError(description: "Google returned no refresh token")
    }

    let file = GoogleCredentials.fileURL
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let creds = GoogleCredentials(client_id: clientID, client_secret: clientSecret, refresh_token: refresh)
    FileManager.default.createFile(atPath: file.path, contents: try JSONEncoder().encode(creds),
                                   attributes: [.posixPermissions: 0o600])
    print("Saved \(file.path)")
}

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

/// Accepts connections on 127.0.0.1 until one carries `?code=` (or `?error=`).
private final class LoopbackListener {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "oauth-listener")
    private var result: Result<String, Error>?
    private let finished = DispatchSemaphore(value: 0)
    let port: UInt16

    init() throws {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: params)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
            if case .failed = state { ready.signal() }
        }
        listener.start(queue: queue)
        ready.wait()
        guard let port = listener.port?.rawValue else { throw SourceError(description: "couldn't open a local port") }
        self.port = port
        // Nobody can connect before the consent page is opened, so attaching late is fine.
        listener.newConnectionHandler = { [unowned self] in handle($0) }
    }

    func waitForCode() throws -> String {
        finished.wait()
        listener.cancel()
        return try result!.get()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [unowned self] data, _, _, _ in
            let requestLine = String(decoding: data ?? Data(), as: UTF8.self).split(separator: "\r\n").first ?? ""
            let path = requestLine.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
            let query = URLComponents(string: "http://localhost\(path)")?.queryItems ?? []
            let code = query.first { $0.name == "code" }?.value
            let error = query.first { $0.name == "error" }?.value

            let message = code != nil ? "meeting-daemon is authorised. You can close this tab."
                : error.map { "Authorisation failed: \($0)" } ?? "Waiting for Google…"
            let page = "<html><body style=\"font: 16px -apple-system; padding: 2em\">\(message)</body></html>"
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(page.utf8.count)\r\nConnection: close\r\n\r\n\(page)"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })

            guard result == nil else { return }
            if let code {
                result = .success(code)
                finished.signal()
            } else if let error {
                result = .failure(SourceError(description: "Google refused: \(error)"))
                finished.signal()
            }
        }
    }
}
