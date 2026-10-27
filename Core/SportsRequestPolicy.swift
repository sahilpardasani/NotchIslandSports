import Foundation

public enum SportsRequestPolicy {
    public static func isSelectedDetail(_ url: URL, fresh: Bool = false) -> Bool {
        fresh || url.lastPathComponent == "summary"
    }
    public static func request(_ url: URL, fresh: Bool = false) -> URLRequest {
        var request = URLRequest(url: url)
        if isSelectedDetail(url, fresh: fresh) {
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        }
        return request
    }
}
