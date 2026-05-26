import Foundation
import os

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse(Int)
    case decodingFailed(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "Invalid response with status code: \(statusCode)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .noData:
            return "No data received from server"
        }
    }
}

// MARK: - API Client

final class APIClient {

    static let shared = APIClient()

    private let session: URLSession
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "APIClient")

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true

        // Configure URL cache: 4 MB memory, 20 MB disk
        let cache = URLCache(
            memoryCapacity: 4 * 1024 * 1024,
            diskCapacity: 20 * 1024 * 1024,
            diskPath: "NotchIslandSportsCache"
        )
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy

        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic Fetch (Decodable)

    /// Fetches and decodes a `Decodable` type from the given URL.
    func fetch<T: Decodable>(from url: URL) async throws -> T {
        logger.info("🌐 Fetching: \(url.absoluteString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            logger.error("❌ Request failed: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ Invalid response type")
            throw NetworkError.invalidResponse(0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("❌ HTTP \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            logger.error("❌ Empty response body")
            throw NetworkError.noData
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(T.self, from: data)
            logger.info("✅ Successfully decoded \(String(describing: T.self))")
            return decoded
        } catch {
            logger.error("❌ Decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }

    // MARK: - Raw JSON Fetch

    /// Fetches raw JSON as `[String: Any]` for manual parsing of complex ESPN responses.
    func fetchRawJSON(from url: URL) async throws -> [String: Any] {
        logger.info("🌐 Fetching raw JSON: \(url.absoluteString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            logger.error("❌ Request failed: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("❌ HTTP \(httpResponse.statusCode)")
            throw NetworkError.invalidResponse(httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            throw NetworkError.noData
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("❌ Could not parse JSON as dictionary")
            throw NetworkError.decodingFailed(
                NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Root is not a JSON object"])
            )
        }

        logger.info("✅ Successfully fetched raw JSON from \(url.lastPathComponent)")
        return json
    }

    // MARK: - Raw Data Fetch

    /// Fetches raw data bytes from the given URL.
    func fetchData(from url: URL) async throws -> Data {
        logger.info("🌐 Fetching data: \(url.absoluteString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            logger.error("❌ Request failed: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NetworkError.invalidResponse(code)
        }

        return data
    }
}
