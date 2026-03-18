//
//  ContentView.swift
//  Ootd-Tracker
//
//  Created by Varsha on 1/12/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var selectedDate: Date?
    @State private var photos: [String: Data] = [:]
    @State private var showPhotoPicker = false
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
                        if photos[date.ISO8601Format()] == nil {
                            showPhotoPicker = true
                        }
                    }
                }
            }
            .padding(.horizontal)

            if let selectedDate = selectedDate, let photoData = photos[selectedDate.ISO8601Format()], let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .animation(.easeInOut, value: selectedDate)

                Button("Upload New Photo") {
                    showPhotoPicker = true
                }
                .foregroundColor(.blue)
                .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            loadPhotos()
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedImageData: $selectedImageData)
        }
        .onChange(of: selectedImageData) { newData in
            if let data = newData, let selectedDate = selectedDate {
                photos[selectedDate.ISO8601Format()] = data
                savePhotos()
                selectedImageData = nil
            }
        }
    }

    private func loadPhotos() {
        if let data = UserDefaults.standard.data(forKey: "ootdPhotos"),
           let decodedPhotos = try? JSONDecoder().decode([String: Data].self, from: data) {
            photos = decodedPhotos
        }
    }

    private func savePhotos() {
        if let data = try? JSONEncoder().encode(photos) {
            UserDefaults.standard.set(data, forKey: "ootdPhotos")
        }
    }
}

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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { return }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let uiImage = image as? UIImage, let data = uiImage.jpegData(compressionQuality: 1.0) {
                        DispatchQueue.main.async {
                            self.parent.selectedImageData = data
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
