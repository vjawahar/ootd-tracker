//
//  ContentView.swift
//  Ootd-Tracker
//
//  Created by Varsha on 1/12/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
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
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
