//
//  Course.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import Foundation
import SwiftData

@Model
final class Course {
    var id: UUID
    var name: String
    var createdAt: Date
    var trashedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \NotePage.course)
    var pages: [NotePage]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        trashedAt: Date? = nil,
        pages: [NotePage] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.trashedAt = trashedAt
        self.pages = pages
    }
}
