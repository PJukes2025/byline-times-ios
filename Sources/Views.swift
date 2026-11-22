import SwiftUI
import UIKit

// MARK: - Tabs

struct RootView: View {
    var body: some View {
        TabView {
            LatestView()
                .tabItem { Label("Latest", systemImage: "newspaper") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark") }
            AccountView()
                .tabItem { Label("Account", systemImage: "person") }
        }
    }
}

// MARK: - Shared pieces

struct Masthead: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                logo
                Spacer(minLength: 12)
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(Theme.label(12))
                    .kerning(0.6)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)
            Rectangle().fill(Theme.ink).frame(height: 4)
        }
        .background(Color.white)
    }

    @ViewBuilder
    private var logo: some View {
        if let image = MastheadArt.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 30)
                .accessibilityLabel("Byline Times")
        } else {
            HStack(spacing: 6) {
                Text("BYLINE").foregroundStyle(Theme.ink)
                Text("TIMES").foregroundStyle(Theme.red)
            }
            .font(Theme.headline(34))
        }
    }
}

struct Kicker: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(12))
            .kerning(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.red)
    }
}

struct MetaLine: View {
    let story: Story

    var body: some View {
        HStack(spacing: 6) {
            if !story.author.isEmpty {
                Text(story.author.uppercased()).foregroundStyle(Theme.ink)
                Text("·")
            }
            Text(story.dateText.uppercased())
        }
        .font(Theme.label(13))
        .kerning(0.5)
        .foregroundStyle(Theme.muted)
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text.uppercased())
                .font(Theme.label(14))
                .kerning(1.2)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 8)
            Rectangle().fill(Theme.ink).frame(height: 1)
        }
    }
}

struct StoryRow: View {
    @EnvironmentObject var state: AppState
    let story: Story
    var isLead = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLead, let address = story.imageURL, let url = URL(string: address) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Theme.wash
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
            }
            VStack(alignment: .leading, spacing: 8) {
                if !story.kicker.isEmpty {
                    Kicker(text: story.kicker)
                }
                Text(story.title)
                    .font(Theme.headline(isLead ? 34 : 24))
                    .foregroundStyle(seen ? Theme.muted : Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !story.standfirst.isEmpty {
                    Text(story.standfirst)
                        .font(Theme.serif(isLead ? 17 : 16))
                        .foregroundStyle(Theme.ink.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                MetaLine(story: story)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .contentShape(Rectangle())
    }

    private var seen: Bool {
        !isLead && state.readIDs.contains(story.id)
    }
}

struct StoryList: View {
    let stories: [Story]
    var leadFirst = false

    var body: some View {
        ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
            NavigationLink(value: story) {
                StoryRow(story: story, isLead: leadFirst && index == 0)
            }
            .buttonStyle(.plain)
            Rectangle().fill(Theme.rule).frame(height: 1)
        }
    }
}

// MARK: - Latest

struct LatestView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Masthead()
                    status
                    if state.stories.isEmpty {
                        emptyState
                    } else {
                        StoryList(stories: state.stories, leadFirst: true)
                    }
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color.white)
            .refreshable { await state.refresh() }
            .navigationDestination(for: Story.self) { story in
                ReaderView(story: story)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if state.stories.isEmpty {
                    await state.refresh()
                }
            }
        }
    }

    private var status: some View {
        HStack {
            if let updated = state.lastUpdated {
                Text("UPDATED \(updated.formatted(date: .omitted, time: .shortened))")
            } else if state.isLoading {
                Text("LOADING")
            } else {
                Text("NOT YET LOADED")
            }
            Spacer()
            if !state.isSubscriber {
                Text("\(state.freeLeft) OF \(AppState.freeLimit) FREE STORIES LEFT")
            }
        }
        .font(Theme.label(12))
        .kerning(0.5)
        .foregroundStyle(Theme.muted)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Theme.wash)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            if state.isLoading {
                ProgressView()
                Text("Loading the latest stories").font(Theme.serif(16)).foregroundStyle(Theme.muted)
            } else if let message = state.loadError {
                Text(message)
                    .font(Theme.serif(16))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    Task { await state.refresh() }
                }
                .buttonStyle(SolidButton())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Saved

struct SavedView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Masthead()
                    SectionTitle(text: "Saved stories")
                    if state.saved.isEmpty {
                        VStack(spacing: 6) {
                            Text("Nothing saved yet").font(Theme.headline(26)).foregroundStyle(Theme.ink)
                            Text("Open a story and tap the bookmark to keep it here.")
                                .font(Theme.serif(16))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        StoryList(stories: state.saved)
                    }
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color.white)
            .navigationDestination(for: Story.self) { story in
                ReaderView(story: story)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Library

/// The 2026 editions as listed in the shop on 20 November 2026. The live list, each
/// reader's entitlements and the PDF files will come from the Byline App Bridge plugin.
struct Edition: Identifiable {
    let month: String
    let price: String
    var id: String { month }
}

struct LibraryView: View {
    @EnvironmentObject var state: AppState
    @State private var notice: String?

    private let editions: [Edition] =
        [Edition(month: "December 2026", price: "£4.60")] +
        ["November", "October", "September", "August", "July", "June", "May", "April", "March", "February", "January"]
            .map { Edition(month: "\($0) 2026", price: "£2.50") }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Masthead()
                Text("Preview build. Editions will open and be sold here once the shop plugin is installed.")
                    .font(Theme.serif(15))
                    .foregroundStyle(Theme.ink.opacity(0.8))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.wash)
                SectionTitle(text: "Monthly editions")
                ForEach(editions) { edition in
                    HStack(spacing: 14) {
                        cover(edition)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(edition.month) Byline Times")
                                .font(Theme.headline(21))
                                .foregroundStyle(Theme.ink)
                            Text("PDF EDITION · \(edition.price)")
                                .font(Theme.label(13))
                                .kerning(0.5)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 8)
                        Button("Open") {
                            notice = "\(edition.month) Byline Times"
                        }
                        .buttonStyle(OutlineButton())
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    Rectangle().fill(Theme.rule).frame(height: 1)
                }
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.white)
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Editions are not connected in this preview build.")
        }
    }

    private func cover(_ edition: Edition) -> some View {
        let parts = edition.month.split(separator: " ")
        let short = parts.count == 2 ? "\(parts[0].prefix(3)) \(parts[1].suffix(2))" : edition.month
        return ZStack(alignment: .bottomLeading) {
            Theme.ink
            Circle().fill(Theme.red).frame(width: 38, height: 38).offset(x: 34, y: -52)
            Text(short.uppercased())
                .font(Theme.headline(15))
                .foregroundStyle(.white)
                .padding(6)
        }
        .frame(width: 54, height: 72)
        .clipped()
    }
}

// MARK: - Account

struct AccountView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Masthead()
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        if state.isSubscriber {
                            Kicker(text: "Subscriber")
                            Text("You have full access").font(Theme.headline(26)).foregroundStyle(Theme.ink)
                        } else {
                            Text("\(state.freeLeft) of \(AppState.freeLimit) free stories left this month")
                                .font(Theme.headline(26))
                                .foregroundStyle(Theme.ink)
                            HStack(spacing: 6) {
                                ForEach(0..<AppState.freeLimit, id: \.self) { index in
                                    Rectangle()
                                        .fill(index < state.readIDs.count ? Theme.red : Theme.rule)
                                        .frame(height: 10)
                                }
                            }
                            Text("Subscribers read everything, and fund the reporting.")
                                .font(Theme.serif(16))
                                .foregroundStyle(Theme.ink)
                            Link(destination: API.subscribeURL) {
                                Text("Subscribe on the website")
                            }
                            .buttonStyle(SolidButton())
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview controls").font(Theme.headline(22)).foregroundStyle(Theme.ink)
                        Toggle("Preview as a subscriber", isOn: $state.isSubscriber)
                            .font(Theme.serif(16))
                        Text("Stands in for sign-in until the shop plugin is installed. Access will come from a Byline Times newspaper subscription: Digital, Print, Supporter or Member.")
                            .font(Theme.serif(14))
                            .foregroundStyle(Theme.muted)
                        Button("Reset this month's free stories") {
                            state.resetFreeCount()
                        }
                        .buttonStyle(OutlineButton())
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.wash)
                }
                .padding(18)
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.white)
    }
}

// MARK: - Buttons

struct SolidButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline(18))
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(configuration.isPressed ? Theme.ink : Theme.red)
    }
}

struct OutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline(15))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(configuration.isPressed ? Color.white : Theme.ink)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(configuration.isPressed ? Theme.ink : Color.white)
            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
    }
}
