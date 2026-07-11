import Foundation

public extension Error {
    /// Every network-backed feature ViewModel should surface this instead of
    /// `String(describing: error)` — the raw description (e.g. an NSURLError's
    /// underlying transport failure text) is meaningless and unpolished to show
    /// a user, and can leak implementation details like hostnames.
    var userFacingMessage: String {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return NSLocalizedString("error.no_connection", comment: "")
            case .timedOut:
                return NSLocalizedString("error.timed_out", comment: "")
            default:
                return NSLocalizedString("error.generic", comment: "")
            }
        }
        return NSLocalizedString("error.generic", comment: "")
    }
}
