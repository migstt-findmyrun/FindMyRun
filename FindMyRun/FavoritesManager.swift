//
//  FavoritesManager.swift
//  FindMyRun
//

import Foundation

@Observable
final class FavoritesManager {
    private static let key = "favoriteClubIds"

    private(set) var favoriteClubIds: Set<String> {
        didSet { save() }
    }

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        favoriteClubIds = Set(stored)
    }

    func isFavorite(_ clubId: String) -> Bool {
        favoriteClubIds.contains(clubId)
    }

    func toggle(_ clubId: String) {
        if favoriteClubIds.contains(clubId) {
            favoriteClubIds.remove(clubId)
        } else {
            favoriteClubIds.insert(clubId)
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(favoriteClubIds), forKey: Self.key)
    }
}
