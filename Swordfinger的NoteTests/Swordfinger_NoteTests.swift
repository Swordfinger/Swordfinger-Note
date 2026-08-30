//
//  Swordfinger_NoteTests.swift
//  Swordfinger的NoteTests
//
//  Created by Kevin Tao on 2026-08-29.
//

import Testing
import Foundation
import SwiftData
@testable import Swordfinger的Note

struct Swordfinger_NoteTests {

    @Test func example() async throws {
        let course = Course(name: "CS 101")
        let page = NotePage(title: "Lecture 1", order: 0, course: course)
        let heading = NoteBlock(page: page, order: 0, blockType: .heading, textContent: "Intro")
        let paragraph = NoteBlock(page: page, order: 1, blockType: .paragraph, textContent: "Hello")
        let code = NoteBlock(page: page, order: 2, blockType: .code, textContent: "print(\"Hello\")", codeLanguage: .python)
        let drawing = NoteBlock(page: page, order: 3, blockType: .drawing, drawingData: Data([0x01, 0x02]))

        course.pages = [page]
        page.blocks = [heading, paragraph, code, drawing]

        #expect(course.id != page.id)
        #expect(course.name == "CS 101")
        #expect(course.pages.map(\.order) == [0])
        #expect(page.course === course)
        #expect(page.blocks.map(\.order) == [0, 1, 2, 3])
        #expect(heading.blockType == .heading)
        #expect(heading.textContent == "Intro")
        #expect(paragraph.blockType == .paragraph)
        #expect(paragraph.textContent == "Hello")
        #expect(code.blockType == .code)
        #expect(code.textContent == "print(\"Hello\")")
        #expect(code.codeLanguage == .python)
        #expect(drawing.blockType == .drawing)
        #expect(drawing.drawingData == Data([0x01, 0x02]))
    }

    @Test func modelsPersistInMemory() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Algorithms")
        let page = NotePage(title: "Sorting", order: 0, course: course)
        let block = NoteBlock(page: page, order: 0, blockType: .code, textContent: "func sort() {}")

        course.pages = [page]
        page.blocks = [block]
        context.insert(course)
        try context.save()

        let descriptor = FetchDescriptor<Course>()
        let courses = try context.fetch(descriptor)

        #expect(courses.count == 1)
        #expect(courses.first?.name == "Algorithms")
        #expect(courses.first?.pages.first?.title == "Sorting")
        #expect(courses.first?.pages.first?.blocks.first?.blockType == .code)
        #expect(courses.first?.pages.first?.blocks.first?.codeLanguage == .plainText)
    }

    @Test func deletingTextAndDrawingBlocksPreservesPageAndNormalizesOrder() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Computer Systems")
        let page = NotePage(title: "Memory", order: 0, course: course)
        let heading = NoteBlock(page: page, order: 0, blockType: .heading, textContent: "Pointers")
        let paragraph = NoteBlock(page: page, order: 1, blockType: .paragraph, textContent: "Stack and heap")
        let drawing = NoteBlock(page: page, order: 2, blockType: .drawing, drawingData: Data([0x03]))
        let code = NoteBlock(page: page, order: 3, blockType: .code, textContent: "int *p;")

        course.pages = [page]
        page.blocks = [heading, paragraph, drawing, code]
        context.insert(course)
        try context.save()

        page.removeBlock(paragraph)
        context.delete(paragraph)
        page.removeBlock(drawing)
        context.delete(drawing)
        try context.save()

        let pages = try context.fetch(FetchDescriptor<NotePage>())
        let blocks = page.blocks.sorted { $0.order < $1.order }

        #expect(pages.count == 1)
        #expect(pages.first?.title == "Memory")
        #expect(blocks.map(\.blockType) == [.heading, .code])
        #expect(blocks.map(\.order) == [0, 1])
    }

    @Test func movingBlocksPreservesIdentityContentAndNormalizesOrder() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Data Structures")
        let page = NotePage(title: "Lecture", order: 0, course: course)
        let heading = NoteBlock(page: page, order: 0, blockType: .heading, textContent: "Trees")
        let paragraph = NoteBlock(page: page, order: 1, blockType: .paragraph, textContent: "Binary search tree")
        let drawingData = Data([0x04, 0x05, 0x06])
        let drawing = NoteBlock(page: page, order: 2, blockType: .drawing, drawingData: drawingData)
        let code = NoteBlock(page: page, order: 3, blockType: .code, textContent: "func insert() {}", codeLanguage: .swift)

        course.pages = [page]
        page.blocks = [heading, paragraph, drawing, code]
        context.insert(course)
        try context.save()

        let headingID = heading.id
        let drawingID = drawing.id
        let previousModificationDate = page.modifiedAt

        page.moveBlocks(from: IndexSet(integer: 2), to: 0)
        try context.save()

        let fetchedPages = try context.fetch(FetchDescriptor<NotePage>())
        let blocks = try #require(fetchedPages.first).blocks.sorted { $0.order < $1.order }

        #expect(blocks.map(\.blockType) == [.drawing, .heading, .paragraph, .code])
        #expect(blocks.map(\.order) == [0, 1, 2, 3])
        #expect(blocks[0].id == drawingID)
        #expect(blocks[0].drawingData == drawingData)
        #expect(blocks[1].id == headingID)
        #expect(blocks[3].textContent == "func insert() {}")
        #expect(blocks[3].codeLanguage == .swift)
        #expect(page.modifiedAt >= previousModificationDate)
    }

    @Test func restoringCourseDoesNotRestoreIndividuallyTrashedPages() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Algorithms")
        let visiblePage = NotePage(title: "Dijkstra", order: 0, course: course)
        let individuallyTrashedPage = NotePage(title: "MST", order: 1, course: course)

        course.pages = [visiblePage, individuallyTrashedPage]
        individuallyTrashedPage.trashedAt = Date()
        course.trashedAt = Date()
        context.insert(course)
        try context.save()

        let courseID = course.id
        let visiblePageID = visiblePage.id
        let individuallyTrashedPageID = individuallyTrashedPage.id

        course.trashedAt = nil
        try context.save()

        let fetchedCourse = try #require(try context.fetch(FetchDescriptor<Course>()).first)
        let fetchedPages = fetchedCourse.pages.sorted { $0.order < $1.order }

        #expect(fetchedCourse.id == courseID)
        #expect(fetchedCourse.trashedAt == nil)
        #expect(fetchedPages.map(\.id) == [visiblePageID, individuallyTrashedPageID])
        #expect(fetchedPages[0].trashedAt == nil)
        #expect(fetchedPages[1].trashedAt != nil)
    }

    @Test func restoringPagePreservesIdentityBlocksDrawingAndCode() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Computer Systems")
        let page = NotePage(title: "Processes", order: 0, course: course)
        let drawingData = Data([0x07, 0x08, 0x09])
        let drawing = NoteBlock(page: page, order: 0, blockType: .drawing, drawingData: drawingData)
        let code = NoteBlock(page: page, order: 1, blockType: .code, textContent: "printf(\"hi\\n\");", codeLanguage: .c)

        course.pages = [page]
        page.blocks = [drawing, code]
        page.trashedAt = Date()
        context.insert(course)
        try context.save()

        let pageID = page.id
        let drawingID = drawing.id
        let codeID = code.id

        page.trashedAt = nil
        try context.save()

        let fetchedPage = try #require(try context.fetch(FetchDescriptor<NotePage>()).first)
        let fetchedBlocks = fetchedPage.blocks.sorted { $0.order < $1.order }

        #expect(fetchedPage.id == pageID)
        #expect(fetchedPage.trashedAt == nil)
        #expect(fetchedBlocks.map(\.id) == [drawingID, codeID])
        #expect(fetchedBlocks[0].drawingData == drawingData)
        #expect(fetchedBlocks[1].textContent == "printf(\"hi\\n\");")
        #expect(fetchedBlocks[1].codeLanguage == .c)
    }

}
