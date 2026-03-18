//
//  ContentView.swift
//  Ootd-Tracker
//
//  Created by Varsha on 1/12/26.
//

import SwiftUI
import PhotosUI
import UIKit
import Combine

// MARK: - Shared Photo Store

class PhotoStore: ObservableObject {
    @Published var photos: [String: Data] = [:]

    init() {
        load()
    }

    func key(for date: Date) -> String {
        date.ISO8601Format()
    }

    func photo(for date: Date) -> UIImage? {
        guard let data = photos[key(for: date)] else { return nil }
        return UIImage(data: data)
    }

    func save(_ data: Data, for date: Date) {
        photos[key(for: date)] = data
        persist()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "ootdPhotos"),
           let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            photos = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(photos) {
            UserDefaults.standard.set(data, forKey: "ootdPhotos")
        }
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject private var store = PhotoStore()

    var body: some View {
        TabView {
            WeekView(store: store)
                .tabItem {
                    Label("This Week", systemImage: "calendar")
                }
            TimelineView(store: store)
                .tabItem {
                    Label("Timeline", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
        }
    }
}

// MARK: - Week View

struct WeekView: View {
    @ObservedObject var store: PhotoStore
    @State private var selectedDate: Date?
    @State private var showActionSheet = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedImageData: Data?

    let calendar = Calendar.current
    var startOfWeek: Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Outfit of the Day Tracker")
                .font(.title)
                .padding(.top)

            HStack(spacing: 10) {
                ForEach(0..<7) { index in
                    let date = calendar.date(byAdding: .day, value: index, to: startOfWeek)!
                    VStack {
                        Text(calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1])
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.title2)
                            .bold()
                    }
                    .frame(width: 45, height: 65)
                    .background(selectedDate == date ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .onTapGesture {
                        selectedDate = date
                        if store.photo(for: date) == nil {
                            showActionSheet = true
                        }
                    }
                }
            }
            .padding(.horizontal)

            if let selectedDate = selectedDate, let uiImage = store.photo(for: selectedDate) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .animation(.easeInOut, value: selectedDate)

                Button("Upload New Photo") {
                    showActionSheet = true
                }
                .foregroundColor(.blue)
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .confirmationDialog("Add Photo", isPresented: $showActionSheet, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedImageData: $selectedImageData)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImageData: $selectedImageData)
        }
        .onChange(of: selectedImageData) { newData in
            if let data = newData, let selectedDate = selectedDate {
                store.save(data, for: selectedDate)
                selectedImageData = nil
            }
        }
    }
}

// MARK: - Timeline View (Google Maps-style)

struct TimelineView: View {
    @ObservedObject var store: PhotoStore
    @State private var selectedDate: Date?
    @State private var showActionSheet = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedImageData: Data?
    @State private var showDetailFor: Date?

    let calendar = Calendar.current

    /// Generate all months from the earliest stored photo up to current month
    var months: [Date] {
        let now = Date()
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        // Parse stored dates and find earliest
        let storedDates = store.photos.keys.compactMap { ISO8601DateFormatter().date(from: $0) }
        let earliest: Date
        if let min = storedDates.min() {
            earliest = calendar.date(from: calendar.dateComponents([.year, .month], from: min))!
        } else {
            earliest = currentMonthStart
        }

        var months: [Date] = []
        var cursor = currentMonthStart
        while cursor >= earliest {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: -1, to: cursor)!
        }
        return months
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(months, id: \.self) { monthStart in
                        Section(header: MonthHeaderView(date: monthStart)) {
                            let days = daysInMonth(monthStart)
                            ForEach(days, id: \.self) { day in
                                DayRowView(
                                    date: day,
                                    image: store.photo(for: day),
                                    onTap: {
                                        selectedDate = day
                                        if store.photo(for: day) == nil {
                                            showActionSheet = true
                                        } else {
                                            showDetailFor = day
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
        }
        .confirmationDialog("Add Photo", isPresented: $showActionSheet, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedImageData: $selectedImageData)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImageData: $selectedImageData)
        }
        .sheet(item: $showDetailFor) { date in
            PhotoDetailView(date: date, store: store)
        }
        .onChange(of: selectedImageData) { newData in
            if let data = newData, let selectedDate = selectedDate {
                store.save(data, for: selectedDate)
                selectedImageData = nil
            }
        }
    }

    func daysInMonth(_ monthStart: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

// MARK: - Month Header

struct MonthHeaderView: View {
    let date: Date
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        Text(MonthHeaderView.formatter.string(from: date))
            .font(.title2)
            .bold()
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
    }
}

// MARK: - Day Row

struct DayRowView: View {
    let date: Date
    let image: UIImage?
    let onTap: () -> Void

    let calendar = Calendar.current
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    var isToday: Bool {
        calendar.isDateInToday(date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Date column
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.title3)
                        .bold()
                        .foregroundColor(isToday ? .blue : .primary)
                    Text(DayRowView.dayFormatter.string(from: date).prefix(3))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 44)

                // Timeline line + dot
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                    Circle()
                        .fill(image != nil ? Color.blue : Color.gray.opacity(0.4))
                        .frame(width: 10, height: 10)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 16)

                // Content
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Outfit logged")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                } else {
                    Text("No outfit logged")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    let date: Date
    @ObservedObject var store: PhotoStore
    @Environment(\.dismiss) var dismiss
    @State private var showActionSheet = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedImageData: Data?

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let uiImage = store.photo(for: date) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding()

                    Button("Change Photo") {
                        showActionSheet = true
                    }
                    .foregroundColor(.blue)
                }
                Spacer()
            }
            .navigationTitle(PhotoDetailView.formatter.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showActionSheet, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedImageData: $selectedImageData)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImageData: $selectedImageData)
        }
        .onChange(of: selectedImageData) { newData in
            if let data = newData {
                store.save(data, for: date)
                selectedImageData = nil
            }
        }
    }
}

// MARK: - Photo Library Picker

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImageData: Data?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { return }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let uiImage = image as? UIImage, let data = uiImage.jpegData(compressionQuality: 1.0) {
                        DispatchQueue.main.async { self.parent.selectedImageData = data }
                    }
                }
            }
        }
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImageData: Data?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let uiImage = info[.originalImage] as? UIImage,
               let data = uiImage.jpegData(compressionQuality: 1.0) {
                DispatchQueue.main.async { self.parent.selectedImageData = data }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ContentView()
}
