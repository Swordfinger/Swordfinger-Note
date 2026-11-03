//
//  Swordfinger_NoteTests.swift
//  Swordfinger的NoteTests
//
//  Created by Kevin Tao on 2026-08-29.
//

import Testing
import Foundation
import CoreGraphics
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

    @Test func drawingCanvasPresetFallbacksAreMigrationSafe() async throws {
        let drawingData = Data([0x20, 0x21, 0x22])
        let block = NoteBlock(order: 0, blockType: .drawing, drawingData: drawingData)

        #expect(block.drawingCanvasPresetRawValue == nil)
        #expect(block.drawingCanvasPreset == .legacySquare)
        #expect(block.drawingData == drawingData)

        block.drawingCanvasPresetRawValue = "unknown-preset"

        #expect(block.drawingCanvasPreset == .legacySquare)
        #expect(block.drawingData == drawingData)
    }

    @Test func drawingCanvasPresetRawValuesRoundTrip() async throws {
        let sketch = NoteBlock(order: 0, blockType: .drawing, drawingCanvasPreset: .sketch)
        let sideNote = NoteBlock(order: 1, blockType: .drawing, drawingCanvasPreset: .sideNote)
        let fullNote = NoteBlock(order: 2, blockType: .drawing, drawingCanvasPreset: .fullNote)

        #expect(sketch.drawingCanvasPresetRawValue == DrawingCanvasPreset.sketch.rawValue)
        #expect(sketch.drawingCanvasPreset == .sketch)
        #expect(sideNote.drawingCanvasPresetRawValue == DrawingCanvasPreset.sideNote.rawValue)
        #expect(sideNote.drawingCanvasPreset == .sideNote)
        #expect(fullNote.drawingCanvasPresetRawValue == DrawingCanvasPreset.fullNote.rawValue)
        #expect(fullNote.drawingCanvasPreset == .fullNote)
    }

    @Test func drawingCanvasPresetGeometryIsStable() async throws {
        #expect(DrawingCanvasPreset.legacySquare.logicalSize == CGSize(width: 1600, height: 1600))
        #expect(DrawingCanvasPreset.sketch.logicalSize == CGSize(width: 1000, height: 700))
        #expect(DrawingCanvasPreset.sideNote.logicalSize == CGSize(width: 1200, height: 1200))
        #expect(DrawingCanvasPreset.fullNote.logicalSize == CGSize(width: 1600, height: 2200))

        #expect(DrawingCanvasPreset.legacySquare.logicalPageRect == CGRect(x: 0, y: 0, width: 1600, height: 1600))
        #expect(DrawingCanvasPreset.sketch.logicalPageRect == CGRect(x: 0, y: 0, width: 1000, height: 700))
        #expect(DrawingCanvasPreset.sideNote.logicalPageRect == CGRect(x: 0, y: 0, width: 1200, height: 1200))
        #expect(DrawingCanvasPreset.fullNote.logicalPageRect == CGRect(x: 0, y: 0, width: 1600, height: 2200))
    }

    @Test func drawingCanvasPresetAspectRatiosAndEmbeddedHeightsAreDerivedFromLogicalSize() async throws {
        #expect(DrawingCanvasPreset.legacySquare.aspectRatio == 1)
        #expect(DrawingCanvasPreset.sideNote.aspectRatio == 1)
        #expect(abs(DrawingCanvasPreset.sketch.aspectRatio - (1000.0 / 700.0)) < 0.0001)
        #expect(abs(DrawingCanvasPreset.fullNote.aspectRatio - (1600.0 / 2200.0)) < 0.0001)

        #expect(DrawingCanvasPreset.legacySquare.embeddedHeight(forWidth: 320) == 320)
        #expect(DrawingCanvasPreset.sideNote.embeddedHeight(forWidth: 360) == 360)
        #expect(abs(DrawingCanvasPreset.sketch.embeddedHeight(forWidth: 1000) - 700) < 0.0001)
        #expect(abs(DrawingCanvasPreset.fullNote.embeddedHeight(forWidth: 1600) - 2200) < 0.0001)
    }

    @Test func drawingPaperStyleFallbacksAreMigrationSafe() async throws {
        let drawingData = Data([0x30, 0x31, 0x32])
        let block = NoteBlock(order: 0, blockType: .drawing, drawingData: drawingData)

        #expect(block.drawingPaperStyleRawValue == nil)
        #expect(block.drawingPaperStyle == .blank)
        #expect(block.drawingData == drawingData)

        block.drawingPaperStyleRawValue = "unknown-paper"

        #expect(block.drawingPaperStyle == .blank)
        #expect(block.drawingData == drawingData)
    }

    @Test func drawingPaperStyleRawValuesRoundTrip() async throws {
        let blank = NoteBlock(order: 0, blockType: .drawing, drawingPaperStyle: .blank)
        let lined = NoteBlock(order: 1, blockType: .drawing, drawingPaperStyle: .lined)
        let grid = NoteBlock(order: 2, blockType: .drawing, drawingPaperStyle: .grid)
        let dotted = NoteBlock(order: 3, blockType: .drawing, drawingPaperStyle: .dotted)

        #expect(blank.drawingPaperStyleRawValue == DrawingPaperStyle.blank.rawValue)
        #expect(blank.drawingPaperStyle == .blank)
        #expect(lined.drawingPaperStyleRawValue == DrawingPaperStyle.lined.rawValue)
        #expect(lined.drawingPaperStyle == .lined)
        #expect(grid.drawingPaperStyleRawValue == DrawingPaperStyle.grid.rawValue)
        #expect(grid.drawingPaperStyle == .grid)
        #expect(dotted.drawingPaperStyleRawValue == DrawingPaperStyle.dotted.rawValue)
        #expect(dotted.drawingPaperStyle == .dotted)
    }

    @Test func changingDrawingPaperStyleDoesNotModifyDrawingData() async throws {
        let drawingData = Data([0x40, 0x41, 0x42])
        let block = NoteBlock(order: 0, blockType: .drawing, drawingData: drawingData)

        block.drawingPaperStyle = .lined
        #expect(block.drawingData == drawingData)

        block.drawingPaperStyle = .grid
        #expect(block.drawingData == drawingData)

        block.drawingPaperStyle = .dotted
        #expect(block.drawingData == drawingData)

        block.drawingPaperStyle = .blank
        #expect(block.drawingData == drawingData)
    }

    @Test func configuredDrawingBlockCreationPreservesOrderAndMetadata() async throws {
        let page = NotePage(title: "Lecture", order: 0)
        let paragraph = NoteBlock(page: page, order: 0, blockType: .paragraph, textContent: "Before drawing")
        let code = NoteBlock(page: page, order: 1, blockType: .code, textContent: "print(1)", codeLanguage: .python)
        let drawing = NoteBlock(
            page: page,
            order: 2,
            blockType: .drawing,
            drawingCanvasPreset: .fullNote,
            drawingPaperStyle: .lined
        )

        page.blocks = [paragraph, code]
        page.blocks.append(drawing)

        let blocks = page.blocks.sorted { $0.order < $1.order }

        #expect(DrawingCanvasPreset.newDrawingChoices == [.sketch, .sideNote, .fullNote])
        #expect(!DrawingCanvasPreset.newDrawingChoices.contains(.legacySquare))
        #expect(blocks.map(\.blockType) == [.paragraph, .code, .drawing])
        #expect(blocks.map(\.order) == [0, 1, 2])
        #expect(blocks[0].textContent == "Before drawing")
        #expect(blocks[1].textContent == "print(1)")
        #expect(blocks[1].codeLanguage == .python)
        #expect(blocks[2].drawingCanvasPreset == .fullNote)
        #expect(blocks[2].drawingPaperStyle == .lined)
        #expect(blocks[2].drawingData == nil)
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

    @Test func trashFilteringAndRestoreSemanticsMatchActiveNavigation() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Course A")
        let page1 = NotePage(title: "Page 1", order: 0, course: course)
        let page2 = NotePage(title: "Page 2", order: 1, course: course)
        let page1Block = NoteBlock(page: page1, order: 0, blockType: .paragraph, textContent: "Page 1 block")
        let page2Block = NoteBlock(page: page2, order: 0, blockType: .paragraph, textContent: "Page 2 block")

        course.pages = [page1, page2]
        page1.blocks = [page1Block]
        page2.blocks = [page2Block]
        context.insert(course)
        try context.save()

        let courseID = course.id
        let page1ID = page1.id
        let page2ID = page2.id
        let page1BlockID = page1Block.id

        page1.trashedAt = Date()
        try context.save()

        var courses = try context.fetch(FetchDescriptor<Course>())
        var activeCourses = courses.filter { $0.trashedAt == nil }
        var activePages = activeCourses.flatMap(\.pages).filter { $0.trashedAt == nil && $0.course?.trashedAt == nil }
        var individuallyTrashedPages = activeCourses.flatMap(\.pages).filter { $0.trashedAt != nil }

        #expect(activeCourses.map(\.id) == [courseID])
        #expect(activePages.map(\.id) == [page2ID])
        #expect(individuallyTrashedPages.map(\.id) == [page1ID])

        page1.trashedAt = nil
        try context.save()

        courses = try context.fetch(FetchDescriptor<Course>())
        activeCourses = courses.filter { $0.trashedAt == nil }
        activePages = activeCourses.flatMap(\.pages).filter { $0.trashedAt == nil && $0.course?.trashedAt == nil }

        #expect(activePages.map(\.id).sorted { $0.uuidString < $1.uuidString } == [page1ID, page2ID].sorted { $0.uuidString < $1.uuidString })
        #expect(page1.id == page1ID)
        #expect(page1.blocks.map(\.id) == [page1BlockID])

        course.trashedAt = Date()
        try context.save()

        courses = try context.fetch(FetchDescriptor<Course>())
        activeCourses = courses.filter { $0.trashedAt == nil }
        activePages = activeCourses.flatMap(\.pages).filter { $0.trashedAt == nil && $0.course?.trashedAt == nil }
        let trashedCourses = courses.filter { $0.trashedAt != nil }

        #expect(activeCourses.isEmpty)
        #expect(activePages.isEmpty)
        #expect(trashedCourses.map(\.id) == [courseID])
        #expect(page1.trashedAt == nil)
        #expect(page2.trashedAt == nil)

        course.trashedAt = nil
        try context.save()

        courses = try context.fetch(FetchDescriptor<Course>())
        activeCourses = courses.filter { $0.trashedAt == nil }
        activePages = activeCourses.flatMap(\.pages).filter { $0.trashedAt == nil && $0.course?.trashedAt == nil }

        #expect(activeCourses.map(\.id) == [courseID])
        #expect(activePages.map(\.id).sorted { $0.uuidString < $1.uuidString } == [page1ID, page2ID].sorted { $0.uuidString < $1.uuidString })

        page2.trashedAt = Date()
        course.trashedAt = Date()
        try context.save()

        course.trashedAt = nil
        try context.save()

        courses = try context.fetch(FetchDescriptor<Course>())
        activeCourses = courses.filter { $0.trashedAt == nil }
        activePages = activeCourses.flatMap(\.pages).filter { $0.trashedAt == nil && $0.course?.trashedAt == nil }
        individuallyTrashedPages = activeCourses.flatMap(\.pages).filter { $0.trashedAt != nil }

        #expect(activeCourses.map(\.id) == [courseID])
        #expect(activePages.map(\.id) == [page1ID])
        #expect(individuallyTrashedPages.map(\.id) == [page2ID])
    }

    @Test func trashRestorePreservesDrawingCodeAndBlockOrder() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Course A")
        let page = NotePage(title: "Page 1", order: 0, course: course)
        let drawingData = Data([0x10, 0x11, 0x12])
        let paragraph = NoteBlock(page: page, order: 0, blockType: .paragraph, textContent: "Intro")
        let drawing = NoteBlock(page: page, order: 1, blockType: .drawing, drawingData: drawingData)
        let code = NoteBlock(page: page, order: 2, blockType: .code, textContent: "for i in range(3):\n    print(i)", codeLanguage: .python)

        course.pages = [page]
        page.blocks = [paragraph, drawing, code]
        context.insert(course)
        try context.save()

        page.moveBlocks(from: IndexSet(integer: 2), to: 0)
        try context.save()

        let expectedBlockIDs = [code.id, paragraph.id, drawing.id]
        let expectedOrders = [0, 1, 2]

        page.trashedAt = Date()
        try context.save()

        page.trashedAt = nil
        try context.save()

        var fetchedPage = try #require(try context.fetch(FetchDescriptor<NotePage>()).first)
        var blocks = fetchedPage.blocks.sorted { $0.order < $1.order }

        #expect(blocks.map(\.id) == expectedBlockIDs)
        #expect(blocks.map(\.order) == expectedOrders)
        #expect(blocks[0].textContent == "for i in range(3):\n    print(i)")
        #expect(blocks[0].codeLanguage == .python)
        #expect(blocks[2].drawingData == drawingData)

        course.trashedAt = Date()
        try context.save()

        course.trashedAt = nil
        try context.save()

        fetchedPage = try #require(try context.fetch(FetchDescriptor<NotePage>()).first)
        blocks = fetchedPage.blocks.sorted { $0.order < $1.order }

        #expect(fetchedPage.trashedAt == nil)
        #expect(blocks.map(\.id) == expectedBlockIDs)
        #expect(blocks.map(\.order) == expectedOrders)
        #expect(blocks[0].textContent == "for i in range(3):\n    print(i)")
        #expect(blocks[0].codeLanguage == .python)
        #expect(blocks[2].drawingData == drawingData)
    }

    @Test func renamingCoursePreservesIdentityPagesAndRelationships() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Old Name")
        let page = NotePage(title: "Lecture", order: 0, course: course)

        course.pages = [page]
        context.insert(course)
        try context.save()

        let courseID = course.id
        let pageID = page.id

        course.name = "New Name"
        try context.save()

        let fetchedCourse = try #require(try context.fetch(FetchDescriptor<Course>()).first)
        let fetchedPage = try #require(fetchedCourse.pages.first)

        #expect(fetchedCourse.id == courseID)
        #expect(fetchedCourse.name == "New Name")
        #expect(fetchedPage.id == pageID)
        #expect(fetchedPage.course === fetchedCourse)
    }

    @Test func renamingPagePreservesIdentityBlocksDrawingCodeAndOrder() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Systems")
        let page = NotePage(title: "Old Page", order: 0, course: course)
        let drawingData = Data([0x0B, 0x0C])
        let drawing = NoteBlock(page: page, order: 0, blockType: .drawing, drawingData: drawingData)
        let code = NoteBlock(page: page, order: 1, blockType: .code, textContent: "let x = 1", codeLanguage: .swift)

        course.pages = [page]
        page.blocks = [drawing, code]
        context.insert(course)
        try context.save()

        let pageID = page.id
        let previousModifiedAt = page.modifiedAt

        page.title = "New Page"
        page.modifiedAt = Date()
        try context.save()

        let fetchedPage = try #require(try context.fetch(FetchDescriptor<NotePage>()).first)
        let fetchedBlocks = fetchedPage.blocks.sorted { $0.order < $1.order }

        #expect(fetchedPage.id == pageID)
        #expect(fetchedPage.title == "New Page")
        #expect(fetchedPage.modifiedAt >= previousModifiedAt)
        #expect(fetchedBlocks.map(\.order) == [0, 1])
        #expect(fetchedBlocks[0].drawingData == drawingData)
        #expect(fetchedBlocks[1].textContent == "let x = 1")
        #expect(fetchedBlocks[1].codeLanguage == .swift)
    }

    @Test func permanentlyDeletingTrashedCourseCascadesPagesAndBlocksOnlyForThatCourse() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let trashedCourse = Course(name: "Algorithms", trashedAt: Date())
        let trashedCoursePage = NotePage(title: "Graphs", order: 0, course: trashedCourse)
        let drawing = NoteBlock(page: trashedCoursePage, order: 0, blockType: .drawing, drawingData: Data([0x01]))
        let code = NoteBlock(page: trashedCoursePage, order: 1, blockType: .code, textContent: "print(\"graph\")", codeLanguage: .python)

        let otherCourse = Course(name: "Systems")
        let otherPage = NotePage(title: "Processes", order: 0, course: otherCourse)
        let otherBlock = NoteBlock(page: otherPage, order: 0, blockType: .paragraph, textContent: "fork")

        trashedCourse.pages = [trashedCoursePage]
        trashedCoursePage.blocks = [drawing, code]
        otherCourse.pages = [otherPage]
        otherPage.blocks = [otherBlock]
        context.insert(trashedCourse)
        context.insert(otherCourse)
        try context.save()

        context.delete(trashedCourse)
        try context.save()

        let courses = try context.fetch(FetchDescriptor<Course>())
        let pages = try context.fetch(FetchDescriptor<NotePage>())
        let blocks = try context.fetch(FetchDescriptor<NoteBlock>())

        #expect(courses.map(\.id) == [otherCourse.id])
        #expect(pages.map(\.id) == [otherPage.id])
        #expect(blocks.map(\.id) == [otherBlock.id])
        #expect(blocks.first?.textContent == "fork")
    }

    @Test func permanentlyDeletingTrashedPageCascadesBlocksAndPreservesCourseAndOtherPages() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let course = Course(name: "Computer Systems")
        let trashedPage = NotePage(title: "Memory", trashedAt: Date(), order: 0, course: course)
        let drawing = NoteBlock(page: trashedPage, order: 0, blockType: .drawing, drawingData: Data([0x02]))
        let code = NoteBlock(page: trashedPage, order: 1, blockType: .code, textContent: "int *p;", codeLanguage: .c)
        let otherPage = NotePage(title: "Processes", order: 1, course: course)
        let otherBlock = NoteBlock(page: otherPage, order: 0, blockType: .heading, textContent: "Scheduling")

        course.pages = [trashedPage, otherPage]
        trashedPage.blocks = [drawing, code]
        otherPage.blocks = [otherBlock]
        context.insert(course)
        try context.save()

        context.delete(trashedPage)
        try context.save()

        let courses = try context.fetch(FetchDescriptor<Course>())
        let pages = try context.fetch(FetchDescriptor<NotePage>())
        let blocks = try context.fetch(FetchDescriptor<NoteBlock>())

        #expect(courses.map(\.id) == [course.id])
        #expect(pages.map(\.id) == [otherPage.id])
        #expect(blocks.map(\.id) == [otherBlock.id])
        #expect(blocks.first?.textContent == "Scheduling")
    }

    @Test func emptyTrashDeletesTopLevelTrashWithoutDoubleDeletingChildPages() async throws {
        let schema = Schema([
            Course.self,
            NotePage.self,
            NoteBlock.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let trashedCourse = Course(name: "Algorithms", trashedAt: Date())
        let pageInsideTrashedCourse = NotePage(title: "Shortest Paths", trashedAt: Date(), order: 0, course: trashedCourse)
        let blockInsideTrashedCourse = NoteBlock(page: pageInsideTrashedCourse, order: 0, blockType: .code, textContent: "dijkstra()", codeLanguage: .python)

        let activeCourse = Course(name: "Systems")
        let activePage = NotePage(title: "Processes", order: 0, course: activeCourse)
        let activeBlock = NoteBlock(page: activePage, order: 0, blockType: .paragraph, textContent: "scheduler")
        let individuallyTrashedPage = NotePage(title: "Memory", trashedAt: Date(), order: 1, course: activeCourse)
        let individuallyTrashedDrawing = NoteBlock(page: individuallyTrashedPage, order: 0, blockType: .drawing, drawingData: Data([0x0A]))

        let untouchedCourse = Course(name: "Databases")
        let untouchedPage = NotePage(title: "Indexes", order: 0, course: untouchedCourse)
        let untouchedBlock = NoteBlock(page: untouchedPage, order: 0, blockType: .code, textContent: "CREATE INDEX", codeLanguage: .plainText)

        trashedCourse.pages = [pageInsideTrashedCourse]
        pageInsideTrashedCourse.blocks = [blockInsideTrashedCourse]
        activeCourse.pages = [activePage, individuallyTrashedPage]
        activePage.blocks = [activeBlock]
        individuallyTrashedPage.blocks = [individuallyTrashedDrawing]
        untouchedCourse.pages = [untouchedPage]
        untouchedPage.blocks = [untouchedBlock]

        context.insert(trashedCourse)
        context.insert(activeCourse)
        context.insert(untouchedCourse)
        try context.save()

        let allCourses = try context.fetch(FetchDescriptor<Course>())
        let coursesToDelete = allCourses.filter { $0.trashedAt != nil }
        let pagesToDelete = allCourses
            .filter { $0.trashedAt == nil }
            .flatMap(\.pages)
            .filter { $0.trashedAt != nil }

        #expect(coursesToDelete.map(\.id) == [trashedCourse.id])
        #expect(pagesToDelete.map(\.id) == [individuallyTrashedPage.id])
        #expect(!pagesToDelete.map(\.id).contains(pageInsideTrashedCourse.id))

        for course in coursesToDelete {
            context.delete(course)
        }

        for page in pagesToDelete {
            context.delete(page)
        }

        try context.save()

        let remainingCourses = try context.fetch(FetchDescriptor<Course>())
        let remainingPages = try context.fetch(FetchDescriptor<NotePage>())
        let remainingBlocks = try context.fetch(FetchDescriptor<NoteBlock>())

        let remainingCourseIDs = remainingCourses.map(\.id).sorted { $0.uuidString < $1.uuidString }
        let expectedCourseIDs = [activeCourse.id, untouchedCourse.id].sorted { $0.uuidString < $1.uuidString }
        let remainingPageIDs = remainingPages.map(\.id).sorted { $0.uuidString < $1.uuidString }
        let expectedPageIDs = [activePage.id, untouchedPage.id].sorted { $0.uuidString < $1.uuidString }
        let remainingBlockIDs = remainingBlocks.map(\.id).sorted { $0.uuidString < $1.uuidString }
        let expectedBlockIDs = [activeBlock.id, untouchedBlock.id].sorted { $0.uuidString < $1.uuidString }

        #expect(remainingCourseIDs == expectedCourseIDs)
        #expect(remainingPageIDs == expectedPageIDs)
        #expect(remainingBlockIDs == expectedBlockIDs)
        #expect(remainingBlocks.contains { $0.textContent == "scheduler" })
        #expect(remainingBlocks.contains { $0.textContent == "CREATE INDEX" })
    }

}
