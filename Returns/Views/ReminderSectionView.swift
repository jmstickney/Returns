//
//  ReminderSectionView.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//

import SwiftUI

struct ReminderSectionView: View {
    @ObservedObject var viewModel: ReturnsViewModel
    var itemID: UUID
    
    @State private var showingAddReminder = false
    @State private var reminderDate = Date()
    @State private var reminderMessage = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        GroupBox(label: Label("Reminders", systemImage: "bell")) {
            VStack(alignment: .leading, spacing: 12) {
                // List existing reminders
                ForEach(viewModel.getRemindersForItem(id: itemID)) { reminder in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.message)
                                .font(.headline)
                            Text(dateFormatter.string(from: reminder.reminderDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Show active/past indicator
                        if reminder.reminderDate < Date() {
                            Text("Past")
                                .font(.caption)
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        } else {
                            Text("Active")
                                .font(.caption)
                                .padding(4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        // Delete button
                        Button(action: {
                            viewModel.deleteReminderWithNotifications(itemID: itemID, reminderID: reminder.id)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if viewModel.getRemindersForItem(id: itemID).last?.id != reminder.id {
                        Divider()
                    }
                }
                
                if viewModel.getRemindersForItem(id: itemID).isEmpty {
                    Text("No reminders set")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                
                // Add reminder button
                Button(action: {
                    reminderDate = Date().addingTimeInterval(24 * 60 * 60) // Default to tomorrow
                    reminderMessage = "Check if refund has been processed"
                    showingAddReminder = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Reminder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingAddReminder) {
            NavigationView {
                Form {
                    DatePicker(
                        "Reminder Date",
                        selection: $reminderDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    
                    TextField("Reminder Message", text: $reminderMessage)
                    
                    Button("Save Reminder") {
                        if !reminderMessage.isEmpty {
                            _ = viewModel.addReminderWithNotifications(
                                for: itemID,
                                date: reminderDate,
                                message: reminderMessage
                            )
                            showingAddReminder = false
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
                .navigationTitle("New Reminder")
                .navigationBarItems(trailing: Button("Cancel") {
                    showingAddReminder = false
                })
            }
        }
    }
}

#Preview {
    let viewModel = ReturnsViewModel()
    let sampleItemID = UUID()
    
    return ReminderSectionView(viewModel: viewModel, itemID: sampleItemID)
        .previewLayout(.sizeThatFits)
        .padding()
}
