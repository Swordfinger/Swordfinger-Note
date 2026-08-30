//
//  NotePage.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import Foundation
import SwiftData

@Model
final class NotePage {
    var id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var trashedAt: Date?
    var order: Int
    var course: Course?

    @Relationship(deleteRule: .cascade, inverse: \NoteBlock.page)
    var blocks: [NoteBlock]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        trashedAt: Date? = nil,
        order: Int,
        course: Course? = nil,
        blocks: [NoteBlock] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.trashedAt = trashedAt
        self.order = order
        self.course = course
        self.blocks = blocks
    }

    func removeBlock(_ block: NoteBlock) {
        blocks.removeAll { $0.id == block.id }
        normalizeBlockOrder()
        modifiedAt = Date()
    }

    func moveBlocks(from sourceIndexes: IndexSet, to destinationIndex: Int) {
        let orderedBlocks = sortedBlocks
        let movedBlocks = sourceIndexes
            .sorted()
            .compactMap { index in
                orderedBlocks.indices.contains(index) ? orderedBlocks[index] : nil
            }

        guard !movedBlocks.isEmpty else {
            return
        }

        var remainingBlocks = orderedBlocks
        for index in sourceIndexes.sorted(by: >) where remainingBlocks.indices.contains(index) {
            remainingBlocks.remove(at: index)
        }

        let removedBeforeDestination = sourceIndexes.filter { $0 < destinationIndex }.count
        let adjustedDestinationIndex = destinationIndex - removedBeforeDestination
        let insertionIndex = min(max(adjustedDestinationIndex, 0), remainingBlocks.count)

        remainingBlocks.insert(contentsOf: movedBlocks, at: insertionIndex)

        for (index, block) in remainingBlocks.enumerated() {
            block.order = index
        }

        modifiedAt = Date()
    }

    func normalizeBlockOrder() {
        let orderedBlocks = sortedBlocks

        for (index, block) in orderedBlocks.enumerated() {
            block.order = index
        }
    }

    private var sortedBlocks: [NoteBlock] {
        blocks.sorted { firstBlock, secondBlock in
            if firstBlock.order == secondBlock.order {
                return firstBlock.id.uuidString < secondBlock.id.uuidString
            }

            return firstBlock.order < secondBlock.order
        }
    }
}
