import SwiftUI
import FirebaseAuth
import ContactsUI
import PhotosUI
import FirebaseStorage

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
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
    @State private var showingContactPicker = false
    @State private var emergencyContacts: [CNContact] = []
    @State private var emergencyContactIDs: [String] = []
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage = false
    @State private var uploadProgress: Double = 0
    @StateObject private var imageViewModel = ProfileImageViewModel()
    let states = ["", "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"]
    var body: some View {
        Form {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if let image = imageViewModel.profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 140)
                            .foregroundColor(.blue)
                    }
                    Button(action: { showingImagePicker = true }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 36, height: 36)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            )
                            .shadow(radius: 2)
                    }
                    .accessibilityLabel("Change profile photo")
                    .contentShape(Circle())
                    .offset(x: 10, y: 10)
                }
                Text(agentFullName)
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                Text(agent.brokerName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            Section(header: Text("Agent Info")) {
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
                Button("Add Emergency Contact") {
                    showingContactPicker = true
                }
                ForEach(emergencyContacts, id: \.identifier) { contact in
                    HStack(spacing: 12) {
                        // Contact photo or placeholder
                        if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(contact.givenName) \(contact.familyName)")
                                .font(.headline)
                            if let phone = contact.phoneNumbers.first?.value.stringValue, !phone.isEmpty {
                                Text(phone)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let email = contact.emailAddresses.first?.value as String?, !email.isEmpty {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button(action: {
                            if let idx = emergencyContacts.firstIndex(where: { $0.identifier == contact.identifier }) {
                                emergencyContacts.remove(at: idx)
                                emergencyContactIDs.removeAll { $0 == contact.identifier }
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    do {
                        try Auth.auth().signOut()
                        authService.isAuthenticated = false
                    } catch {
                        print("Sign out failed: \(error.localizedDescription)")
                    }
                }) {
                    Text("Sign Out")
                        .foregroundColor(.blue)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker { contact in
                if !emergencyContacts.contains(where: { $0.identifier == contact.identifier }) {
                    emergencyContacts.append(contact)
                    emergencyContactIDs.append(contact.identifier)
                }
                showingContactPicker = false
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { image in
                if let image = image {
                    selectedImage = image
                    isUploadingImage = true
                    imageViewModel.uploadProfileImage(image: image) { progress in
                        uploadProgress = progress
                    } completion: { success in
                        isUploadingImage = false
                        uploadProgress = 0
                    }
                }
            }
        }
        .onAppear {
            // Listen for contact store changes
            NotificationCenter.default.addObserver(forName: .CNContactStoreDidChange, object: nil, queue: .main) { _ in
                refreshEmergencyContacts()
            }
            imageViewModel.loadProfileImage()
            // Load agent info from Firestore
            FirestoreService.shared.getCurrentUserProfile { result in
                switch result {
                case .success(let data):
                    if let data = data {
                        DispatchQueue.main.async {
                            agent.firstName = (data["name"] as? String)?.components(separatedBy: " ").first ?? agent.firstName
                            agent.lastName = (data["name"] as? String)?.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? agent.lastName
                            agent.email = data["email"] as? String ?? agent.email
                            agent.phoneNumber = data["phone"] as? String ?? agent.phoneNumber
                            agent.brokerName = data["brokerName"] as? String ?? agent.brokerName
                        }
                    }
                case .failure:
                    break
                }
            }
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
    // Helper to refresh contacts from identifiers
    private func refreshEmergencyContacts() {
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactImageDataKey] as [CNKeyDescriptor]
        let predicate = CNContact.predicateForContacts(withIdentifiers: emergencyContactIDs)
        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
            emergencyContacts = contacts
        } catch {
            print("Failed to refresh emergency contacts: \(error)")
        }
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

// ContactPicker wrapper for SwiftUI
struct ContactPicker: UIViewControllerRepresentable {
    var onSelect: (CNContact) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void

        init(onSelect: @escaping (CNContact) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }
    }
}

// MARK: - ProfileImageViewModel
class ProfileImageViewModel: ObservableObject {
    @Published var profileImage: UIImage?
    private var imageUrl: String?

    func loadProfileImage() {
        FirestoreService.shared.getCurrentUserProfile { [weak self] (result: Result<[String: Any]?, Error>) in
            switch result {
            case .success(let data):
                if let urlString = data?["profileImageUrl"] as? String, let url = URL(string: urlString) {
                    self?.downloadImage(from: url)
                }
            case .failure:
                break
            }
        }
    }

    private func downloadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImage = image
                }
            }
        }.resume()
    }

    func uploadProfileImage(image: UIImage, progress: @escaping (Double) -> Void, completion: @escaping (Bool) -> Void) {
        guard let userId = FirestoreService.shared.getCurrentUserId(),
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(false)
            return
        }
        let imageId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("profile_images/\(userId)/\(imageId)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let uploadTask = storageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                completion(false)
                return
            }
            storageRef.downloadURL { url, error in
                if let url = url {
                    self.saveProfileImageUrl(url.absoluteString)
                    self.downloadImage(from: url)
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
        uploadTask.observe(.progress) { snapshot in
            let percent = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
            DispatchQueue.main.async {
                progress(percent)
            }
        }
    }

    private func saveProfileImageUrl(_ url: String) {
        FirestoreService.shared.updateUserProfileImageUrl(url: url) { _ in }
    }
}

// MARK: - ImagePicker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage?) -> Void
        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            onImagePicked(image)
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ProfileView()
}
