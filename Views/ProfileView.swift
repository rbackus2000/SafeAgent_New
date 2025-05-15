import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var agent = Agent(id: UUID(), firstName: "Jane", lastName: "Doe", email: "jane@example.com", phoneNumber: "(555) 123-4567", brokerName: "Acme Realty", emergencyContacts: [])
    @State private var isEditing = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var brokerName = ""
    @State private var phone = ""
    @State private var email = ""
    @AppStorage("agentLicenseNumber") private var licenseNumber: String = ""
    @AppStorage("agentState") private var agentState: String = ""
    @State private var editingLicense = false
    @State private var tempLicense: String = ""
    @State private var tempState: String = ""
    let states = ["", "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"]
    var body: some View {
        Form {
            Section(header: Text("Agent Info")) {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(agentFullName)
                            .font(.headline)
                        Text(agent.brokerName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Text("Phone: \(agent.phoneNumber)")
                Text("Email: \(agent.email)")
                HStack {
                    Text("State:")
                    Spacer()
                    if editingLicense {
                        Picker("Select State", selection: $tempState) {
                            ForEach(states, id: \.self) { state in
                                Text(state.isEmpty ? "Select" : state).tag(state)
                            }
                        }
                        .frame(width: 120)
                    } else {
                        Text(agentState.isEmpty ? "Not set" : agentState)
                            .foregroundColor(agentState.isEmpty ? .gray : .primary)
                    }
                }
                HStack {
                    Text("State License Number:")
                    Spacer()
                    if editingLicense {
                        TextField("Enter license number", text: $tempLicense)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 180)
                    } else {
                        Text(licenseNumber.isEmpty ? "Not set" : licenseNumber)
                            .foregroundColor(licenseNumber.isEmpty ? .gray : .primary)
                    }
                }
                if editingLicense {
                    if !isLicenseValid(tempLicense) {
                        Text("License number must be alphanumeric and not empty.")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                    if tempState.isEmpty {
                        Text("Please select a state.")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                    Button("Save") {
                        licenseNumber = tempLicense
                        agentState = tempState
                        editingLicense = false
                    }
                    .disabled(!isLicenseValid(tempLicense) || tempState.isEmpty)
                } else {
                    Button((licenseNumber.isEmpty || agentState.isEmpty) ? "Add License Info" : "Edit License Info") {
                        tempLicense = licenseNumber
                        tempState = agentState
                        editingLicense = true
                    }
                }
                Button(isEditing ? "Cancel" : "Edit") {
                    if isEditing {
                        isEditing = false
                    } else {
                        loadAgentFields()
                        isEditing = true
                    }
                }
            }
            if isEditing {
                Section(header: Text("Edit Agent Info")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Broker", text: $brokerName)
                    TextField("Phone", text: $phone)
                    TextField("Email", text: $email)
                    Button("Save") {
                        saveAgent()
                        isEditing = false
                    }
                }
            }
            Section(header: Text("Emergency Contacts")) {
                NavigationLink(destination: EmergencyContactsView(agent: agent)) {
                    Text("Manage Emergency Contacts")
                }
            }
        }
        .navigationTitle("Profile")
        .accessibilityElement(children: .contain)
        .safeAreaInset(edge: .bottom) {
            SignOutButton()
                .padding()
        }
    }
    private var agentFullName: String {
        "\(agent.firstName) \(agent.lastName)"
    }
    private func loadAgentFields() {
        firstName = agent.firstName
        lastName = agent.lastName
        brokerName = agent.brokerName
        phone = agent.phoneNumber
        email = agent.email
    }
    private func saveAgent() {
        agent.firstName = firstName
        agent.lastName = lastName
        agent.brokerName = brokerName
        agent.phoneNumber = phone
        agent.email = email
    }
    private func isLicenseValid(_ license: String) -> Bool {
        !license.isEmpty && license.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) != nil
    }
}

struct SignOutButton: View {
    @EnvironmentObject var authService: AuthenticationService
    var body: some View {
        Button(role: .destructive) {
            do {
                try Auth.auth().signOut()
                authService.isAuthenticated = false
            } catch {
                print("Sign out failed: \(error.localizedDescription)")
            }
        } label: {
            HStack {
                Image(systemName: "arrow.backward.square")
                Text("Sign Out")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ProfileView()
}
