import SwiftUI

struct EmergencyContactsView: View {
    @State private var contacts: [EmergencyContact] = []
    @State private var showAddContact = false
    var agent: Agent? = nil

    var body: some View {
        List {
            ForEach(contacts, id: \.phoneNumber) { contact in
                VStack(alignment: .leading) {
                    Text(contact.name)
                        .font(.headline)
                    Text(contact.relationship)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(contact.phoneNumber)
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
            }
            .onDelete(perform: deleteContacts)
        }
        .navigationTitle("Emergency Contacts")
        .sheet(isPresented: $showAddContact) {
            AddEmergencyContactView(onSave: { contact in
                contacts.append(contact)
            })
        }
    }

    private func deleteContacts(offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
    }
}

struct AddEmergencyContactView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var relationship = ""
    @State private var phoneNumber = ""
    var onSave: (EmergencyContact) -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                TextField("Relationship", text: $relationship)
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
            }
            .navigationTitle("Add Contact")
        }
    }
}

#Preview {
    EmergencyContactsView(agent: nil)
}
