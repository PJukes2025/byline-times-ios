import SwiftUI

// MARK: - App entry

@main
struct BylineTimesApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .preferredColorScheme(.light)
                .tint(Theme.red)
        }
    }
}

// MARK: - Look

/// Colours read from bylinetimes.com. Headlines use the system condensed face as a
/// stand-in for Trade Gothic Next Condensed; body uses the system serif as a stand-in
/// for Source Serif 4. Swap in the real fonts once they are licensed and bundled.
enum Theme {
    static let ink = Color(red: 35 / 255, green: 31 / 255, blue: 30 / 255)
    static let red = Color(red: 194 / 255, green: 51 / 255, blue: 48 / 255)
    static let muted = Color(red: 119 / 255, green: 116 / 255, blue: 117 / 255)
    static let rule = Color(red: 228 / 255, green: 224 / 255, blue: 223 / 255)
    static let wash = Color(red: 245 / 255, green: 242 / 255, blue: 241 / 255)

    static func headline(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .heavy).width(.condensed)
    }

    static func label(_ size: CGFloat = 13) -> Font {
        Font.system(size: size, weight: .semibold).width(.condensed)
    }

    static func serif(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .regular, design: .serif)
    }
}

// MARK: - Model

struct Story: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let standfirst: String
    let author: String
    let date: Date?
    let link: String
    let imageURL: String?
    let kicker: String

    var dateText: String {
        guard let date else { return "" }
        return date.formatted(.dateTime.day().month(.wide))
    }
}

/// The parts of a WordPress post the app uses. Every field except `id` is optional,
/// so one odd post cannot break the whole list.
struct WPPost: Decodable {
    struct Rendered: Decodable {
        let rendered: String?
    }

    struct Media: Decodable {
        let source_url: String?
    }

    struct Embedded: Decodable {
        let media: [Media]?

        enum CodingKeys: String, CodingKey {
            case media = "wp:featuredmedia"
        }
    }

    let id: Int
    let date: String?
    let link: String?
    let title: Rendered?
    let excerpt: Rendered?
    let content: Rendered?
    let authorName: String?
    let embedded: Embedded?

    enum CodingKeys: String, CodingKey {
        case id, date, link, title, excerpt, content
        case authorName = "author_name"
        case embedded = "_embedded"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = (try? c.decodeIfPresent(String.self, forKey: .date)) ?? nil
        link = (try? c.decodeIfPresent(String.self, forKey: .link)) ?? nil
        title = (try? c.decodeIfPresent(Rendered.self, forKey: .title)) ?? nil
        excerpt = (try? c.decodeIfPresent(Rendered.self, forKey: .excerpt)) ?? nil
        content = (try? c.decodeIfPresent(Rendered.self, forKey: .content)) ?? nil
        authorName = (try? c.decodeIfPresent(String.self, forKey: .authorName)) ?? nil
        embedded = (try? c.decodeIfPresent(Embedded.self, forKey: .embedded)) ?? nil
    }

    var story: Story {
        var standfirst = (excerpt?.rendered ?? "").plainText
        var kicker = ""
        let prefix = "Exclusive:"
        if standfirst.lowercased().hasPrefix(prefix.lowercased()) {
            kicker = "Exclusive"
            standfirst = String(standfirst.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return Story(
            id: id,
            title: (title?.rendered ?? "").plainText,
            standfirst: standfirst,
            author: (authorName ?? "").plainText,
            date: date.flatMap { WPDate.parse($0) },
            link: link ?? "https://bylinetimes.com",
            imageURL: embedded?.media?.first?.source_url,
            kicker: kicker
        )
    }
}

enum WPDate {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    static func parse(_ text: String) -> Date? {
        formatter.date(from: text)
    }
}

extension String {
    /// Strips HTML tags and turns entities such as &#8216; or &amp; into characters.
    var plainText: String {
        let stripped = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
            "&nbsp;": " ", "&hellip;": "…", "&ndash;": "–", "&mdash;": "—",
            "&lsquo;": "‘", "&rsquo;": "’", "&ldquo;": "“", "&rdquo;": "”", "&pound;": "£"
        ]
        var out = ""
        var i = stripped.startIndex
        while i < stripped.endIndex {
            if stripped[i] == "&",
               let semi = stripped[i...].firstIndex(of: ";"),
               stripped.distance(from: i, to: semi) <= 9 {
                let entity = String(stripped[i...semi])
                let next = stripped.index(after: semi)
                if let replacement = named[entity] {
                    out += replacement
                    i = next
                    continue
                }
                if entity.hasPrefix("&#") {
                    let body = entity.dropFirst(2).dropLast()
                    let code: UInt32?
                    if body.hasPrefix("x") || body.hasPrefix("X") {
                        code = UInt32(body.dropFirst(), radix: 16)
                    } else {
                        code = UInt32(body)
                    }
                    if let code, let scalar = Unicode.Scalar(code) {
                        out.unicodeScalars.append(scalar)
                        i = next
                        continue
                    }
                }
            }
            out.append(stripped[i])
            i = stripped.index(after: i)
        }
        return out
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

// MARK: - bylinetimes.com

enum API {
    static let base = "https://bylinetimes.com/wp-json/wp/v2"
    static let subscribeURL = URL(string: "https://subscribe.bylinetimes.com/")!

    enum Failure: Error {
        case badAddress
        case server(Int)
        case empty
    }

    private static func get(_ address: String) async throws -> Data {
        guard let url = URL(string: address) else { throw Failure.badAddress }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw Failure.server(http.statusCode)
        }
        return data
    }

    static func latest(count: Int = 20) async throws -> [Story] {
        let fields = "id,date,link,title,excerpt,author_name,_links,_embedded"
        let data = try await get("\(base)/posts?per_page=\(count)&_fields=\(fields)&_embed=wp:featuredmedia")
        let posts = try JSONDecoder().decode([WPPost].self, from: data)
        if posts.isEmpty { throw Failure.empty }
        return posts.map { $0.story }
    }

    static func body(of id: Int) async throws -> String {
        let data = try await get("\(base)/posts/\(id)?_fields=id,content")
        let post = try JSONDecoder().decode(WPPost.self, from: data)
        guard let html = post.content?.rendered, !html.isEmpty else { throw Failure.empty }
        return html
    }
}

// MARK: - App state

@MainActor
final class AppState: ObservableObject {
    static let freeLimit = 3

    @Published var stories: [Story] = []
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var lastUpdated: Date?

    /// Preview switch. Replaced by real sign-in once the shop plugin is installed.
    @Published var isSubscriber: Bool {
        didSet { defaults.set(isSubscriber, forKey: "isSubscriber") }
    }

    /// Stories opened free this calendar month.
    @Published var readIDs: [Int] {
        didSet { defaults.set(readIDs, forKey: "readIDs") }
    }

    @Published var saved: [Story] {
        didSet {
            if let data = try? JSONEncoder().encode(saved) {
                defaults.set(data, forKey: "saved")
            }
        }
    }

    @Published var textSize: Double {
        didSet { defaults.set(textSize, forKey: "textSize") }
    }

    private let defaults = UserDefaults.standard

    init() {
        let d = UserDefaults.standard
        let month = AppState.monthKey()
        isSubscriber = d.bool(forKey: "isSubscriber")
        if d.string(forKey: "readMonth") == month {
            readIDs = (d.array(forKey: "readIDs") as? [Int]) ?? []
        } else {
            readIDs = []
            d.set(month, forKey: "readMonth")
            d.set([Int](), forKey: "readIDs")
        }
        if let data = d.data(forKey: "saved"),
           let stored = try? JSONDecoder().decode([Story].self, from: data) {
            saved = stored
        } else {
            saved = []
        }
        let size = d.double(forKey: "textSize")
        textSize = size == 0 ? 19 : size
    }

    static func monthKey() -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    var freeLeft: Int {
        max(0, AppState.freeLimit - readIDs.count)
    }

    func canOpen(_ story: Story) -> Bool {
        isSubscriber || readIDs.contains(story.id) || readIDs.count < AppState.freeLimit
    }

    func markRead(_ story: Story) {
        guard !isSubscriber, !readIDs.contains(story.id), readIDs.count < AppState.freeLimit else { return }
        readIDs.append(story.id)
    }

    func isSaved(_ story: Story) -> Bool {
        saved.contains { $0.id == story.id }
    }

    func toggleSaved(_ story: Story) {
        if isSaved(story) {
            saved.removeAll { $0.id == story.id }
        } else {
            saved.insert(story, at: 0)
        }
    }

    func resetFreeCount() {
        readIDs = []
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stories = try await API.latest()
            lastUpdated = Date()
            loadError = nil
        } catch {
            loadError = "Byline Times could not be reached. Check the connection and pull down to try again."
        }
    }
}
