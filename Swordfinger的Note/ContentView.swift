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
    @Query(sort: \Course.createdAt) private var courses: [Course]

    @State private var selectedCourseID: PersistentIdentifier?
    @State private var selectedPageID: PersistentIdentifier?

    private var selectedCourse: Course? {
        courses.first { $0.persistentModelID == selectedCourseID }
    }

    private var sortedPages: [NotePage] {
        selectedCourse?.pages.sorted { firstPage, secondPage in
            if firstPage.order == secondPage.order {
                return firstPage.createdAt < secondPage.createdAt
            }

            return firstPage.order < secondPage.order
        } ?? []
    }

    private var selectedPage: NotePage? {
        sortedPages.first { $0.persistentModelID == selectedPageID }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCourseID) {
                ForEach(courses) { course in
                    Text(course.name)
                        .tag(course.persistentModelID)
                }
            }
            .navigationTitle("Courses")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: addCourse) {
                        Label("New Course", systemImage: "plus")
                    }
                }
            }
        } content: {
            List(selection: $selectedPageID) {
                ForEach(sortedPages) { page in
                    Text(page.title)
                        .tag(page.persistentModelID)
                }
            }
            .navigationTitle(selectedCourse?.name ?? "Pages")
            .toolbar {
                ToolbarItem {
                    Button(action: addPage) {
                        Label("New Page", systemImage: "plus")
                    }
                    .disabled(selectedCourse == nil)
                }
            }
        } detail: {
            if let selectedPage {
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
                .padding()
                .navigationTitle(selectedPage.title)
            } else {
                ContentUnavailableView("Select a Page", systemImage: "doc.text")
            }
        }
        .onChange(of: selectedCourseID) { _, _ in
            selectedPageID = nil
        }
    }

    private func addCourse() {
        withAnimation {
            let courseNumber = courses.count + 1
            let course = Course(name: "Course \(courseNumber)")

            modelContext.insert(course)
            selectedCourseID = course.persistentModelID
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
            selectedCourseID = selectedCourse.persistentModelID
            selectedPageID = page.persistentModelID
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Course.self, NotePage.self, NoteBlock.self], inMemory: true)
}
