import SwiftUI
import UIKit
import WebKit

// MARK: - Reader

struct ReaderView: View {
    @EnvironmentObject var state: AppState
    let story: Story

    @State private var allowed: Bool?
    @State private var bodyHTML: String?
    @State private var failed = false

    var body: some View {
        Group {
            if allowed == false {
                PaywallView(story: story)
            } else if let bodyHTML {
                ArticleWebView(html: ArticlePage.build(story: story, body: bodyHTML, textSize: state.textSize))
            } else if failed {
                VStack(spacing: 14) {
                    Text("This story could not be loaded")
                        .font(Theme.headline(24))
                        .foregroundStyle(Theme.ink)
                    Button("Try again") {
                        Task { await load() }
                    }
                    .buttonStyle(SolidButton())
                    if let url = URL(string: story.link) {
                        Link("Read on bylinetimes.com", destination: url)
                            .font(Theme.serif(16))
                    }
                }
                .padding(32)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    state.textSize = max(16, state.textSize - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .accessibilityLabel("Smaller text")
                Button {
                    state.textSize = min(26, state.textSize + 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .accessibilityLabel("Larger text")
                Button {
                    state.toggleSaved(story)
                } label: {
                    Image(systemName: state.isSaved(story) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(state.isSaved(story) ? "Remove from saved" : "Save story")
            }
        }
        .task {
            if allowed == nil {
                let open = state.canOpen(story)
                if open {
                    state.markRead(story)
                }
                allowed = open
            }
            if allowed == true, bodyHTML == nil {
                await load()
            }
        }
        .onChange(of: state.isSubscriber) { _, isSubscriber in
            if isSubscriber, allowed == false {
                allowed = true
                Task { await load() }
            }
        }
    }

    private func load() async {
        failed = false
        do {
            bodyHTML = try await API.body(of: story.id)
        } catch {
            failed = true
        }
    }
}

// MARK: - Paywall

struct PaywallView: View {
    let story: Story

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !story.kicker.isEmpty {
                    Kicker(text: story.kicker)
                }
                Text(story.title)
                    .font(Theme.headline(38))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !story.standfirst.isEmpty {
                    Text(story.standfirst)
                        .font(Theme.serif(20))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                MetaLine(story: story)

                VStack(alignment: .leading, spacing: 12) {
                    Rectangle().fill(Theme.red).frame(width: 64, height: 8)
                    Text("You have read your \(AppState.freeLimit) free stories this month")
                        .font(Theme.headline(30))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Byline Times has no billionaire owner and no offshore backer. Readers pay for the reporting. Subscribe to keep reading.")
                        .font(Theme.serif(16))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Link(destination: API.subscribeURL) {
                        Text("Subscribe on the website")
                    }
                    .buttonStyle(SolidButton())
                    Text("Preview build. Subscribing inside the app and subscriber sign-in are not connected yet. To see subscriber access, use the switch on the Account tab.")
                        .font(Theme.serif(14))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
                .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Article page

/// Wraps a story's HTML from WordPress in the app's own styling. The site embeds
/// subscribe panels, newsletter boxes and related-story lists in the story body;
/// the stylesheet hides them so only the journalism shows.
enum ArticlePage {
    static func build(story: Story, body: String, textSize: Double) -> String {
        let kicker = story.kicker.isEmpty ? "" : "<span class=\"kicker\">\(story.kicker.htmlEscaped)</span>"
        let standfirst = story.standfirst.isEmpty ? "" : "<p class=\"stand\">\(story.standfirst.htmlEscaped)</p>"
        var meta = story.dateText.htmlEscaped
        if !story.author.isEmpty {
            meta = "<b>\(story.author.htmlEscaped)</b> &nbsp;·&nbsp; " + meta
        }
        return """
        <!DOCTYPE html>
        <html lang="en-GB">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { --ink:#231f1e; --red:#c23330; --muted:#777475; --rule:#e4e0df; color-scheme: light; }
        * { box-sizing: border-box; }
        body { margin:0; padding:20px 20px 60px; background:#fff; color:var(--ink);
               font-family: ui-serif, "New York", Georgia, serif; font-size:\(Int(textSize))px; line-height:1.55;
               -webkit-text-size-adjust:100%; }
        main { max-width:680px; margin:0 auto; }
        h1, h2, h3, h4, .kicker, .meta { font-family: system-ui, -apple-system, "Helvetica Neue", sans-serif; font-stretch: condensed; }
        h1 { font-size:2.1em; font-weight:800; line-height:1; margin:10px 0 12px; }
        h2, h3, h4 { font-size:1.4em; font-weight:800; line-height:1.05; margin:1.3em 0 .5em; }
        .kicker { display:inline-block; background:var(--red); color:#fff; font-size:.68em; font-weight:800;
                  letter-spacing:.1em; text-transform:uppercase; padding:2px 7px; }
        .stand { font-size:1.08em; line-height:1.35; margin:0 0 14px; }
        .meta { font-size:.75em; font-weight:600; letter-spacing:.05em; text-transform:uppercase; color:var(--muted);
                padding:10px 0; border-top:1px solid var(--ink); border-bottom:1px solid var(--rule); margin-bottom:18px; }
        .meta b { color:var(--ink); }
        p { margin:0 0 1em; }
        a { color:var(--red); }
        img, video, iframe { max-width:100%; height:auto; }
        figure { margin:1.2em 0; }
        figcaption { font-size:.75em; color:var(--muted); }
        blockquote { margin:1.2em 0; padding-left:14px; border-left:4px solid var(--red); font-style:italic; }
        hr { border:0; border-top:1px solid var(--rule); margin:1.4em 0; }
        .has-drop-cap:first-letter { float:left; font-family: system-ui, sans-serif; font-stretch: condensed; font-weight:800;
                                     font-size:3.4em; line-height:.8; padding:.08em .08em 0 0; color:var(--red); }
        .is-style-sell, .is-style-boxed, .wp-block-query, .wp-block-buttons { display:none !important; }
        </style>
        </head>
        <body>
        <main>
        \(kicker)
        <h1>\(story.title.htmlEscaped)</h1>
        \(standfirst)
        <div class="meta">\(meta)</div>
        \(body)
        </main>
        </body>
        </html>
        """
    }
}

struct ArticleWebView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.navigationDelegate = context.coordinator
        view.backgroundColor = .white
        view.scrollView.backgroundColor = .white
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if context.coordinator.loaded != html {
            context.coordinator.loaded = html
            view.loadHTMLString(html, baseURL: URL(string: "https://bylinetimes.com"))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded = ""

        /// Links in a story open in Safari, so the reader stays on the story.
        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                _ = await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
