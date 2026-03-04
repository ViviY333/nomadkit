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
    
    var isAllSelected: Bool {
        return !items.isEmpty && selectedIDs.count == items.count
    }
    
    func toggle(_ item: PackingItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }
    
    func isSelected(_ item: PackingItem) -> Bool {
        selectedIDs.contains(item.id)
    }
}

