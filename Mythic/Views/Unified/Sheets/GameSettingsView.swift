//
//  GameSettingsView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/3/2024.
//

import SwiftUI
import CachedAsyncImage
import Shimmer
import SwordRPC

struct GameSettingsView: View {
    @Binding var game: Game
    @Binding var isPresented: Bool
    
    @State private var operation: GameOperation = .shared
    @State private var selectedBottleURL: URL?
    
    init(game: Binding<Game>, isPresented: Binding<Bool>) {
        _game = game
        _isPresented = isPresented
        _selectedBottleURL = State(initialValue: game.wrappedValue.bottleURL)
        _launchArguments = State(initialValue: game.launchArguments.wrappedValue)
    }
    
    @State private var moving: Bool = false
    @State private var movingError: Error?
    @State private var isMovingErrorPresented: Bool = false
    
    @State private var typingArgument: String = .init()
    @State private var launchArguments: [String] = .init()
    @State private var isHoveringOverArg: Bool = false
    
    @State private var isFileSectionExpanded: Bool = true
    @State private var isWineSectionExpanded: Bool = true
    @State private var isGameSectionExpanded: Bool = true
    
    @State private var isThumbnailURLChangeSheetPresented: Bool = false
    
    var body: some View {
        HStack {
            VStack {
                Text(game.title)
                    .font(.title)
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay { // MARK: Image
                        CachedAsyncImage(url: game.imageURL) { phase in
                            switch phase {
                            case .empty:
                                if case .local = game.type, game.imageURL == nil {
                                    let image = Image(nsImage: workspace.icon(forFile: game.path ?? .init()))
                                    
                                    image
                                        .resizable()
                                        .aspectRatio(3/4, contentMode: .fill)
                                        .blur(radius: 20.0)
                                    
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.windowBackground)
                                        .shimmering(
                                            animation: .easeInOut(duration: 1)
                                                .repeatForever(autoreverses: false),
                                            bandSize: 1
                                        )
                                }
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .clipShape(.rect(cornerRadius: 20))
                                    .blur(radius: 10.0)
                                
                                image
                                    .resizable()
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .clipShape(.rect(cornerRadius: 20))
                                    .modifier(FadeInModifier())
                            case .failure:
                                // fallthrough
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.windowBackground)
                                    .overlay {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                    }
                            @unknown default:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.windowBackground)
                                    .overlay {
                                        Image(systemName: "questionmark.circle.fill")
                                    }
                            }
                        }
                    }
            }
            .padding(.trailing)
            
            Divider()
            
            Form {
                Section("Options", isExpanded: $isGameSectionExpanded) {
                    HStack {
                        VStack {
                            HStack {
                                Text("Thumbnail URL")
                                
                                Spacer()
                            }
                            HStack {
                                Text(game.imageURL?.host ?? "Unknown")
                                    .foregroundStyle(.secondary)
                                    .truncationMode(.middle)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                        }
                        
                        Spacer()
                        
                        Button("Change...") {
                            isThumbnailURLChangeSheetPresented = true
                        }
                        .sheet(isPresented: $isThumbnailURLChangeSheetPresented) {
                            TextField( // TODO: better implementation
                                "Enter New Thumbnail URL here...",
                                text: Binding(
                                    get: { game.imageURL?.absoluteString.removingPercentEncoding ?? .init() },
                                    set: { game.imageURL = .init(string: $0) }
                                )
                            )
                            .truncationMode(.tail)
                            .padding()
                        }
                        .disabled(game.type != .local)
                    }
                    
                    HStack {
                        VStack {
                            HStack {
                                Text("Launch Arguments")
                                Spacer()
                            }
                            
                            if !launchArguments.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack {
                                        ForEach(launchArguments, id: \.self) { argument in
                                            ArgumentItem(launchArguments: $launchArguments, argument: argument)
                                        }
                                        .onChange(of: launchArguments, { game.launchArguments = $1 })
                                        
                                        Spacer()
                                    }
                                }
                                .scrollIndicators(.never)
                            }
                        }
                        
                        Spacer()
                        TextField("", text: $typingArgument)
                            .onSubmit {
                                if !typingArgument.trimmingCharacters(in: .illegalCharacters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    launchArguments.append(typingArgument)
                                    typingArgument = .init()
                                }
                            }
                    }
                    
                    HStack {
                        VStack {
                            HStack {
                                Text("Verify File Integrity")
                                Spacer()
                            }
                            
                            if operation.current?.game == game {
                                HStack {
                                    if operation.status.progress != nil {
                                        ProgressView(value: operation.status.progress?.percentage)
                                            .controlSize(.small)
                                            .progressViewStyle(.linear)
                                    } else {
                                        ProgressView()
                                            .controlSize(.small)
                                            .progressViewStyle(.linear)
                                    }
                                    Spacer()
                                }
                            }
                        }
                            
                        Spacer()
                        
                        Button("Verify...") {
                            operation.queue.append(
                                GameOperation.InstallArguments(
                                    game: game, platform: game.platform!, type: .repair
                                )
                            )
                        }
                        .disabled(operation.queue.contains(where: { $0.game == game }))
                        .disabled(operation.current?.game == game)
                    }
                }
                
                Section("File", isExpanded: $isFileSectionExpanded) {
                    HStack {
                        Text("Move \"\(game.title)\"")
                        
                        Spacer()
                        
                        if !moving {
                            Button("Move...") { // TODO: look into whether .fileMover is a suitable alternative
                                let openPanel = NSOpenPanel()
                                openPanel.prompt = "Move"
                                openPanel.canChooseDirectories = true
                                openPanel.allowsMultipleSelection = false
                                openPanel.canCreateDirectories = true
                                openPanel.directoryURL = .init(filePath: game.path ?? .init())
                                
                                if case .OK = openPanel.runModal(), let newLocation = openPanel.urls.first {
                                    Task {
                                        do {
                                            moving = true
                                            try await game.move(to: newLocation)
                                            moving = false
                                        } catch {
                                            movingError = error
                                            isMovingErrorPresented = true
                                        }
                                    }
                                }
                            }
                            .disabled(GameOperation.shared.runningGames.contains(game))
                            .alert(isPresented: $isMovingErrorPresented) {
                                Alert(
                                    title: .init("Unable to move \"\(game.title)\"."),
                                    message: .init(movingError?.localizedDescription ?? "Unknown Error.")
                                )
                            }
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    
                    HStack {
                        VStack {
                            HStack {
                                Text("Game Location:")
                                Spacer()
                            }
                            
                            HStack {
                                Text(URL(filePath: game.path ?? "Unknown").prettyPath())
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        
                        Spacer()
                        
                        Button("Show in Finder") {
                            workspace.activateFileViewerSelecting([URL(filePath: game.path!)])
                        }
                        .disabled(game.path == nil)
                    }
                }
                
                Section("Engine (Wine)", isExpanded: $isWineSectionExpanded) {
                    if selectedBottleURL != nil {
                        BottleSettingsView(selectedBottleURL: $selectedBottleURL, withPicker: true) // FIXME: Bottle Revamp
                    }
                }
                // TODO: DXVK
                .disabled(game.platform != .windows)
                .disabled(!Engine.exists)
                .onChange(of: selectedBottleURL) { game.bottleURL = $1 }
            }
            .formStyle(.grouped)
        }
        
        HStack {
            SubscriptedTextView(game.platform?.rawValue ?? "Unknown")
            
            SubscriptedTextView(game.type.rawValue)
            
            if (try? defaults.decodeAndGet(Game.self, forKey: "recentlyPlayed")) == game {
                SubscriptedTextView("Recent")
            }
            
            Spacer()
            
            Button {
                isPresented =  false
            } label: {
                Text("Close")
            }
            .buttonStyle(.borderedProminent)
        }
        .task(priority: .background) {
            discordRPC.setPresence({
                var presence: RichPresence = .init()
                presence.details = "Configuring \(game.platform?.rawValue ?? .init()) game \"\(game.title)\""
                presence.state = "Configuring \(game.title)"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                
                return presence
            }())
        }
    }
}

extension GameSettingsView {
    struct ArgumentItem: View {
        @Binding var launchArguments: [String]
        var argument: String
        
        @State private var isHoveringOverArg: Bool = false
        
        var body: some View {
            HStack {
                if isHoveringOverArg {
                    Image(systemName: "xmark.bin")
                        .imageScale(.small)
                }
                
                Text(argument)
                    .monospaced()
                    .foregroundStyle(isHoveringOverArg ? .red : .secondary)
            }
            .padding(3)
            .overlay(content: {
                RoundedRectangle(cornerRadius: 7)
                    .foregroundStyle(.tertiary)
                    .shadow(radius: 5)
            })
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isHoveringOverArg = hovering
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    launchArguments.removeAll(where: { $0 == argument })
                }
            }
        }
    }
}

#Preview {
    GameSettingsView(game: .constant(.init(type: .epic, title: .init())), isPresented: .constant(true))
}
