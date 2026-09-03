//
//  ContentView.swift
//  Swordfinger的Note
//
//  Created by Kevin Tao on 2026-08-29.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Course.createdAt) private var courses: [Course]

    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selectedMainSelection: MainNavigationSelection?
    @State private var selectedPageID: PersistentIdentifier?
    @State private var renameTarget: RenameTarget?
    @State private var renameText = ""
    @State private var isRenamePresented = false
    @State private var trashTarget: TrashTarget?
    @State private var isTrashConfirmationPresented = false
    @State private var permanentDeleteTarget: PermanentDeleteTarget?
    @State private var isPermanentDeleteConfirmationPresented = false
    @State private var isEmptyTrashConfirmationPresented = false

    private var selectedCourseID: PersistentIdentifier? {
        guard case .course(let courseID) = selectedMainSelection else {
            return nil
        }

        return courseID
    }

    private var selectedCourse: Course? {
        activeCourses.first { $0.persistentModelID == selectedCourseID }
    }

    private var activeCourses: [Course] {
        courses.filter { $0.trashedAt == nil }
    }

    private var trashedCourses: [Course] {
        courses
            .filter { $0.trashedAt != nil }
            .sorted { firstCourse, secondCourse in
                if firstCourse.name == secondCourse.name {
                    return firstCourse.createdAt < secondCourse.createdAt
                }

                return firstCourse.name < secondCourse.name
            }
    }

    private var individuallyTrashedPages: [NotePage] {
        activeCourses
            .flatMap(\.pages)
            .filter { $0.trashedAt != nil }
            .sorted { firstPage, secondPage in
                if firstPage.order == secondPage.order {
                    return firstPage.createdAt < secondPage.createdAt
                }

                return firstPage.order < secondPage.order
            }
    }

    private var sortedPages: [NotePage] {
        selectedCourse.map(activePages(for:)) ?? []
    }

    private var activeCourseIDs: [PersistentIdentifier] {
        activeCourses.map(\.persistentModelID)
    }

    private var activePageIDs: [PersistentIdentifier] {
        sortedPages.map(\.persistentModelID)
    }

    private func activePages(for course: Course) -> [NotePage] {
        course.pages.filter { page in
            page.trashedAt == nil && page.course?.trashedAt == nil
        }
        .sorted { firstPage, secondPage in
            if firstPage.order == secondPage.order {
                return firstPage.createdAt < secondPage.createdAt
            }

            return firstPage.order < secondPage.order
        }
    }

    private var selectedPage: NotePage? {
        sortedPages.first { $0.persistentModelID == selectedPageID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedMainSelection) {
                Section("Courses") {
                    ForEach(activeCourses) { course in
                        Text(course.name)
                            .tag(MainNavigationSelection.course(course.persistentModelID))
                            .contextMenu {
                                Button {
                                    beginRenamingCourse(course)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    beginMovingCourseToTrash(course)
                                } label: {
                                    Label("Move to Trash", systemImage: "trash")
                                }
                            }
                    }
                }

                Section {
                    Label("Trash", systemImage: "trash")
                        .tag(MainNavigationSelection.trash)
                }
            }
            .navigationTitle("Courses")
            .navigationSplitViewColumnWidth(
                min: columnMetrics.sidebar.minimum,
                ideal: columnMetrics.sidebar.ideal,
                max: columnMetrics.sidebar.maximum
            )
            .toolbar {
                ToolbarItem {
                    Button(action: addCourse) {
                        Label("New Course", systemImage: "plus")
                    }
                }
            }
        } content: {
            if selectedMainSelection == .trash {
                if horizontalSizeClass == .compact {
                    trashView
                        .navigationTitle("Trash")
                } else {
                    ContentUnavailableView("Trash", systemImage: "trash")
                        .navigationTitle("Trash")
                }
            } else {
                List(selection: $selectedPageID) {
                    ForEach(sortedPages) { page in
                        Text(page.title)
                            .tag(page.persistentModelID)
                            .contextMenu {
                                Button {
                                    beginRenamingPage(page)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    beginMovingPageToTrash(page)
                                } label: {
                                    Label("Move to Trash", systemImage: "trash")
                                }
                            }
                    }
                }
                .navigationTitle(selectedCourse?.name ?? "Pages")
                .navigationSplitViewColumnWidth(
                    min: columnMetrics.content.minimum,
                    ideal: columnMetrics.content.ideal,
                    max: columnMetrics.content.maximum
                )
                .toolbar {
                    ToolbarItem {
                        Button(action: addPage) {
                            Label("New Page", systemImage: "plus")
                        }
                        .disabled(selectedCourse == nil)
                    }
                }
            }
        } detail: {
            if selectedMainSelection == .trash {
                if horizontalSizeClass == .compact {
                    ContentUnavailableView("Trash", systemImage: "trash")
                } else {
                    trashView
                        .navigationTitle("Trash")
                        .navigationSplitViewColumnWidth(
                            min: columnMetrics.detail.minimum,
                            ideal: columnMetrics.detail.ideal,
                            max: columnMetrics.detail.maximum
                        )
                }
            } else if let selectedPage {
                GeometryReader { geometry in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedPage.title)
                            .font(.largeTitle)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created \(selectedPage.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                                .foregroundStyle(.secondary)

                            Text("Modified \(selectedPage.modifiedAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))")
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        BlockEditorView(page: selectedPage)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(detailPadding(for: geometry.size.width))
                }
                .navigationTitle(selectedPage.title)
                .navigationSplitViewColumnWidth(
                    min: columnMetrics.detail.minimum,
                    ideal: columnMetrics.detail.ideal,
                    max: columnMetrics.detail.maximum
                )
            } else {
                ContentUnavailableView("Select a Page", systemImage: "doc.text")
            }
        }
        .onChange(of: selectedMainSelection) { _, newSelection in
            if case .course = newSelection {
                reconcileSelection()
            } else {
                selectedPageID = nil
            }
        }
        .onChange(of: activeCourseIDs) { _, _ in
            reconcileSelection()
        }
        .onChange(of: activePageIDs) { _, _ in
            reconcileSelection()
        }
        .alert(renameDialogTitle, isPresented: $isRenamePresented) {
            TextField(renameTextFieldTitle, text: $renameText)

            Button("Cancel", role: .cancel) {
                resetRenameState()
            }

            Button("Rename") {
                commitRename()
            }
        }
        .confirmationDialog(
            trashDialogTitle,
            isPresented: $isTrashConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                commitMoveToTrash()
            }

            Button("Cancel", role: .cancel) {
                resetTrashState()
            }
        } message: {
            Text(trashDialogMessage)
        }
        .confirmationDialog(
            permanentDeleteDialogTitle,
            isPresented: $isPermanentDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                commitPermanentDelete()
            }

            Button("Cancel", role: .cancel) {
                resetPermanentDeleteState()
            }
        } message: {
            Text(permanentDeleteDialogMessage)
        }
        .confirmationDialog(
            "Permanently delete everything in Trash?",
            isPresented: $isEmptyTrashConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Empty Trash", role: .destructive) {
                emptyTrash()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all trashed Courses, Pages, Blocks, drawings, and code. This action cannot be undone.")
        }
    }

    private var trashView: some View {
        TrashView(
            trashedCourses: trashedCourses,
            individuallyTrashedPages: individuallyTrashedPages,
            restoreCourse: restoreCourse,
            restorePage: restorePage,
            beginDeletingCoursePermanently: beginDeletingCoursePermanently,
            beginDeletingPagePermanently: beginDeletingPagePermanently
        )
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    isEmptyTrashConfirmationPresented = true
                } label: {
                    Label("Empty Trash", systemImage: "trash")
                }
                .disabled(isTrashEmpty)
            }
        }
    }

    private var columnMetrics: SplitViewColumnMetrics {
        if horizontalSizeClass == .compact {
            return SplitViewColumnMetrics(
                sidebar: ColumnWidth(minimum: 180, ideal: 220, maximum: 280),
                content: ColumnWidth(minimum: 200, ideal: 240, maximum: 320),
                detail: ColumnWidth(minimum: 320, ideal: 640, maximum: 1200)
            )
        }

        return SplitViewColumnMetrics(
            sidebar: ColumnWidth(minimum: 220, ideal: 260, maximum: 320),
            content: ColumnWidth(minimum: 240, ideal: 300, maximum: 380),
            detail: ColumnWidth(minimum: 420, ideal: 840, maximum: 1600)
        )
    }

    private func detailPadding(for width: CGFloat) -> CGFloat {
        if width < 500 {
            return 12
        }

        if width < 900 {
            return 16
        }

        return 24
    }

    private var renameDialogTitle: String {
        switch renameTarget {
        case .course:
            return "Rename Course"
        case .page:
            return "Rename Page"
        case nil:
            return "Rename"
        }
    }

    private var renameTextFieldTitle: String {
        switch renameTarget {
        case .course:
            return "Course Name"
        case .page:
            return "Page Title"
        case nil:
            return "Name"
        }
    }

    private var trashDialogTitle: String {
        switch trashTarget {
        case .course(let courseID):
            let name = course(with: courseID)?.name ?? "Course"
            return "Move \"\(name)\" to Trash?"
        case .page(let pageID):
            let title = page(with: pageID)?.title ?? "Page"
            return "Move \"\(title)\" to Trash?"
        case nil:
            return "Move to Trash?"
        }
    }

    private var trashDialogMessage: String {
        switch trashTarget {
        case .course:
            return "The course and its pages will be removed from your notes list but can be restored from Trash."
        case .page:
            return "The page and all of its blocks can be restored from Trash."
        case nil:
            return ""
        }
    }

    private var permanentDeleteDialogTitle: String {
        switch permanentDeleteTarget {
        case .course(let courseID):
            let name = course(with: courseID)?.name ?? "Course"
            return "Delete \"\(name)\" Permanently?"
        case .page(let pageID):
            let title = page(with: pageID)?.title ?? "Page"
            return "Delete \"\(title)\" Permanently?"
        case nil:
            return "Delete Permanently?"
        }
    }

    private var permanentDeleteDialogMessage: String {
        switch permanentDeleteTarget {
        case .course:
            return "Deleting this Course permanently will delete all Pages and all Blocks inside the Course, including drawings and code. This action cannot be undone."
        case .page:
            return "Deleting this Page permanently will delete all Blocks inside it. This action cannot be undone."
        case nil:
            return ""
        }
    }

    private var isTrashEmpty: Bool {
        trashedCourses.isEmpty && individuallyTrashedPages.isEmpty
    }

    private func addCourse() {
        withAnimation {
            let courseNumber = activeCourses.count + 1
            let course = Course(name: "Course \(courseNumber)")

            modelContext.insert(course)
            selectedMainSelection = .course(course.persistentModelID)
            selectedPageID = nil
        }
    }

    private func addPage() {
        guard let selectedCourse else {
            return
        }

        withAnimation {
            let pageNumber = sortedPages.count + 1
            let page = NotePage(
                title: "Page \(pageNumber)",
                order: sortedPages.count,
                course: selectedCourse
            )

            selectedCourse.pages.append(page)
            selectedMainSelection = .course(selectedCourse.persistentModelID)
            selectedPageID = page.persistentModelID
        }
    }

    private func beginRenamingCourse(_ course: Course) {
        renameTarget = .course(course.persistentModelID)
        renameText = course.name
        isRenamePresented = true
    }

    private func beginRenamingPage(_ page: NotePage) {
        renameTarget = .page(page.persistentModelID)
        renameText = page.title
        isRenamePresented = true
    }

    private func beginMovingCourseToTrash(_ course: Course) {
        trashTarget = .course(course.persistentModelID)
        isTrashConfirmationPresented = true
    }

    private func beginMovingPageToTrash(_ page: NotePage) {
        trashTarget = .page(page.persistentModelID)
        isTrashConfirmationPresented = true
    }

    private func beginDeletingCoursePermanently(_ course: Course) {
        permanentDeleteTarget = .course(course.persistentModelID)
        isPermanentDeleteConfirmationPresented = true
    }

    private func beginDeletingPagePermanently(_ page: NotePage) {
        permanentDeleteTarget = .page(page.persistentModelID)
        isPermanentDeleteConfirmationPresented = true
    }

    private func commitRename() {
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !newName.isEmpty, let renameTarget else {
            resetRenameState()
            return
        }

        switch renameTarget {
        case .course(let courseID):
            course(with: courseID)?.name = newName
        case .page(let pageID):
            if let page = page(with: pageID) {
                page.title = newName
                page.modifiedAt = Date()
            }
        }

        saveRename()
        resetRenameState()
    }

    private func commitMoveToTrash() {
        guard let trashTarget else {
            resetTrashState()
            return
        }

        switch trashTarget {
        case .course(let courseID):
            moveCourseToTrash(courseID)
        case .page(let pageID):
            movePageToTrash(pageID)
        }

        saveTrash()
        resetTrashState()
        reconcileSelection()
    }

    private func commitPermanentDelete() {
        guard let permanentDeleteTarget else {
            resetPermanentDeleteState()
            return
        }

        switch permanentDeleteTarget {
        case .course(let courseID):
            deleteCoursePermanently(courseID)
        case .page(let pageID):
            deletePagePermanently(pageID)
        }

        savePermanentDelete()
        resetPermanentDeleteState()
        reconcileSelection()
    }

    private func moveCourseToTrash(_ courseID: PersistentIdentifier) {
        guard let course = course(with: courseID) else {
            return
        }

        course.trashedAt = Date()

        if selectedCourseID == courseID {
            selectedMainSelection = nil
            selectedPageID = nil
        }
    }

    private func movePageToTrash(_ pageID: PersistentIdentifier) {
        guard let page = page(with: pageID) else {
            return
        }

        page.trashedAt = Date()
        page.modifiedAt = Date()

        if selectedPageID == pageID {
            selectedPageID = nil
        }
    }

    private func deleteCoursePermanently(_ courseID: PersistentIdentifier) {
        guard let course = course(with: courseID), course.trashedAt != nil else {
            return
        }

        modelContext.delete(course)

        if selectedCourseID == courseID {
            selectedMainSelection = nil
            selectedPageID = nil
        }
    }

    private func deletePagePermanently(_ pageID: PersistentIdentifier) {
        guard let page = page(with: pageID), page.trashedAt != nil else {
            return
        }

        modelContext.delete(page)

        if selectedPageID == pageID {
            selectedPageID = nil
        }
    }

    private func emptyTrash() {
        let coursesToDelete = trashedCourses
        let pagesToDelete = individuallyTrashedPages

        for course in coursesToDelete {
            modelContext.delete(course)
        }

        for page in pagesToDelete {
            modelContext.delete(page)
        }

        savePermanentDelete()
        reconcileSelection()
    }

    private func course(with courseID: PersistentIdentifier) -> Course? {
        courses.first { $0.persistentModelID == courseID }
    }

    private func page(with pageID: PersistentIdentifier) -> NotePage? {
        courses
            .lazy
            .flatMap(\.pages)
            .first { $0.persistentModelID == pageID }
    }

    private func restoreCourse(_ course: Course) {
        course.trashedAt = nil
        saveTrash()
        selectedMainSelection = .course(course.persistentModelID)
        reconcileSelection()
    }

    private func restorePage(_ page: NotePage) {
        page.trashedAt = nil
        page.modifiedAt = Date()
        saveTrash()

        if let course = page.course, course.trashedAt == nil {
            selectedMainSelection = .course(course.persistentModelID)
            selectedPageID = page.persistentModelID
        } else {
            reconcileSelection()
        }
    }

    private func saveRename() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not save rename: \(error)")
        }
    }

    private func saveTrash() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not save move to trash: \(error)")
        }
    }

    private func savePermanentDelete() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Could not save permanent delete: \(error)")
        }
    }

    private func resetRenameState() {
        renameTarget = nil
        renameText = ""
    }

    private func resetTrashState() {
        trashTarget = nil
    }

    private func resetPermanentDeleteState() {
        permanentDeleteTarget = nil
    }

    private func reconcileSelection() {
        if let selectedCourseID, !activeCourseIDs.contains(selectedCourseID) {
            selectedMainSelection = nil
            selectedPageID = nil
            return
        }

        if let selectedPageID, !activePageIDs.contains(selectedPageID) {
            self.selectedPageID = nil
        }
    }
}

private struct TrashView: View {
    let trashedCourses: [Course]
    let individuallyTrashedPages: [NotePage]
    let restoreCourse: (Course) -> Void
    let restorePage: (NotePage) -> Void
    let beginDeletingCoursePermanently: (Course) -> Void
    let beginDeletingPagePermanently: (NotePage) -> Void

    var body: some View {
        List {
            Section("Courses") {
                if trashedCourses.isEmpty {
                    Text("No trashed courses")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trashedCourses) { course in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(course.name)
                                .font(.headline)

                            let activeChildPageCount = course.pages.filter { $0.trashedAt == nil }.count
                            Text("\(activeChildPageCount) page\(activeChildPageCount == 1 ? "" : "s") will return with this course")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                restoreCourse(course)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                beginDeletingCoursePermanently(course)
                            } label: {
                                Label("Delete Permanently", systemImage: "trash.slash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Pages") {
                if individuallyTrashedPages.isEmpty {
                    Text("No individually trashed pages")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(individuallyTrashedPages) { page in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(page.title)
                                .font(.headline)

                            if let courseName = page.course?.name {
                                Text(courseName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                restorePage(page)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                beginDeletingPagePermanently(page)
                            } label: {
                                Label("Delete Permanently", systemImage: "trash.slash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private enum MainNavigationSelection: Hashable {
    case course(PersistentIdentifier)
    case trash
}

private enum RenameTarget {
    case course(PersistentIdentifier)
    case page(PersistentIdentifier)
}

private enum TrashTarget {
    case course(PersistentIdentifier)
    case page(PersistentIdentifier)
}

private enum PermanentDeleteTarget {
    case course(PersistentIdentifier)
    case page(PersistentIdentifier)
}

private struct SplitViewColumnMetrics {
    let sidebar: ColumnWidth
    let content: ColumnWidth
    let detail: ColumnWidth
}

private struct ColumnWidth {
    let minimum: CGFloat
    let ideal: CGFloat
    let maximum: CGFloat
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Course.self, NotePage.self, NoteBlock.self], inMemory: true)
}
