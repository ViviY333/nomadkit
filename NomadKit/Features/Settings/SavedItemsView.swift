import SwiftUI

struct SavedItemsView: View {
    @Environment(UserDataStore.self) private var userData
    @State private var cities: [CitySnapshot] = []

    private var workspaces: [SavedWorkspaceEntry] {
        cities.flatMap { city in
            city.workspaces.compactMap { workspace in
                guard userData.isWorkspaceFavorite(cityID: city.id, workspaceID: workspace.id) else { return nil }
                return SavedWorkspaceEntry(city: city, workspace: workspace)
            }
        }
    }

    private var channels: [SavedChannelEntry] {
        cities.flatMap { city in
            city.channels.compactMap { channel in
                guard userData.isChannelFavorite(cityID: city.id, channelID: channel.id) else { return nil }
                return SavedChannelEntry(city: city, channel: channel)
            }
        }
    }

    var body: some View {
        Group {
            if workspaces.isEmpty && channels.isEmpty {
                ContentUnavailableView(
                    "saved.empty.title",
                    systemImage: "bookmark",
                    description: Text("saved.empty.message")
                )
            } else {
                List {
                    if !workspaces.isEmpty {
                        Section("saved.workspaces") {
                            ForEach(workspaces) { entry in
                                NavigationLink {
                                    WorkspaceDetailView(cityID: entry.city.id, workspace: entry.workspace)
                                } label: {
                                    SavedRow(
                                        symbol: entry.workspace.symbol,
                                        title: entry.workspace.name,
                                        city: entry.city.name.value
                                    )
                                }
                                .swipeActions {
                                    Button("saved.remove", role: .destructive) {
                                        userData.toggleWorkspaceFavorite(
                                            cityID: entry.city.id,
                                            workspaceID: entry.workspace.id
                                        )
                                    }
                                }
                            }
                        }
                    }

                    if !channels.isEmpty {
                        Section("saved.channels") {
                            ForEach(channels) { entry in
                                NavigationLink {
                                    ChannelDetailView(cityID: entry.city.id, channel: entry.channel)
                                } label: {
                                    SavedRow(
                                        symbol: entry.channel.symbol,
                                        title: entry.channel.title.value,
                                        city: entry.city.name.value
                                    )
                                }
                                .swipeActions {
                                    Button("saved.remove", role: .destructive) {
                                        userData.toggleChannelFavorite(
                                            cityID: entry.city.id,
                                            channelID: entry.channel.id
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("saved.title")
        .task {
            cities = (try? MockDataService().loadCities()) ?? []
        }
    }
}

private struct SavedRow: View {
    let symbol: String
    let title: String
    let city: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: NomadSpacing.xSmall) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(city)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
        }
    }
}

private struct SavedWorkspaceEntry: Identifiable {
    let city: CitySnapshot
    let workspace: Workspace
    var id: String { UserDataStore.favoriteKey(cityID: city.id, itemID: workspace.id) }
}

private struct SavedChannelEntry: Identifiable {
    let city: CitySnapshot
    let channel: LocalChannel
    var id: String { UserDataStore.favoriteKey(cityID: city.id, itemID: channel.id) }
}

struct WorkspaceDetailView: View {
    @Environment(UserDataStore.self) private var userData
    let cityID: String
    let workspace: Workspace

    var body: some View {
        List {
            Section {
                Label(workspace.detail.value, systemImage: workspace.symbol)
            }
            Section {
                Button {
                    userData.toggleWorkspaceFavorite(cityID: cityID, workspaceID: workspace.id)
                } label: {
                    Label(
                        userData.isWorkspaceFavorite(cityID: cityID, workspaceID: workspace.id) ? "已收藏" : "收藏地点",
                        systemImage: userData.isWorkspaceFavorite(cityID: cityID, workspaceID: workspace.id) ? "bookmark.fill" : "bookmark"
                    )
                }
            }
        }
        .navigationTitle(workspace.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChannelDetailView: View {
    @Environment(UserDataStore.self) private var userData
    let cityID: String
    let channel: LocalChannel

    var body: some View {
        List {
            Section {
                Label(channel.detail.value, systemImage: channel.symbol)
            }
            Section {
                Button {
                    userData.toggleChannelFavorite(cityID: cityID, channelID: channel.id)
                } label: {
                    Label(
                        userData.isChannelFavorite(cityID: cityID, channelID: channel.id) ? "已收藏" : "收藏信息",
                        systemImage: userData.isChannelFavorite(cityID: cityID, channelID: channel.id) ? "bookmark.fill" : "bookmark"
                    )
                }
            }
        }
        .navigationTitle(channel.title.value)
        .navigationBarTitleDisplayMode(.inline)
    }
}
