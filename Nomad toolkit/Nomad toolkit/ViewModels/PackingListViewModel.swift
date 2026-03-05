//
//  PackingListViewModel.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation
import SwiftUI
import Combine

struct PackingItem: Identifiable, Equatable {
    var id: String { imageName }
    let imageName: String
    let title: String
}

class PackingListViewModel: ObservableObject {
    @Published var items: [PackingItem] = [
        PackingItem(imageName: "packing_laptop", title: "Laptop"),
        PackingItem(imageName: "packing_powerbank", title: "Power Bank"),
        PackingItem(imageName: "packing_headphones", title: "Headphones"),
        PackingItem(imageName: "packing_wallet", title: "Wallet"),
        PackingItem(imageName: "packing_sim", title: "Sim Card"),
        PackingItem(imageName: "packing_shoes", title: "Shoes")
    ]

    @Published var selectedIDs: Set<String> = []

    private let storageKey = "packingSelectedIDs"

    var isAllSelected: Bool {
        return !items.isEmpty && selectedIDs.count == items.count
    }

    init() {
        loadFromStorage()
    }

    func toggle(_ item: PackingItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        saveToStorage()
    }

    func isSelected(_ item: PackingItem) -> Bool {
        selectedIDs.contains(item.id)
    }

    private func loadFromStorage() {
        if let savedIDs = SharedDefaults.store.array(forKey: storageKey) as? [String] {
            selectedIDs = Set(savedIDs)
        }
    }

    private func saveToStorage() {
        SharedDefaults.store.set(Array(selectedIDs), forKey: storageKey)
    }
}

