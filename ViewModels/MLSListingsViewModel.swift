import Foundation
import Combine

class MLSListingsViewModel: ObservableObject {
    @Published var listings: [PropertyListing] = []
    @Published var isLoading: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private let mlsService: MLSService
    
    init(mlsService: MLSService = MLSService()) {
        self.mlsService = mlsService
        mlsService.$fetchedListings
            .receive(on: DispatchQueue.main)
            .assign(to: &$listings)
    }
    
    func syncListingsForLicense(_ license: String, state: String = "") {
        guard !license.isEmpty else {
            self.listings = []
            return
        }
        isLoading = true
        mlsService.fetchListings(forLicense: license) { [weak self] in
            self?.isLoading = false
        }
    }
    
    // Call this after authentication (e.g., in RootView or AuthService)
    func syncAfterLoginIfNeeded() {
        let license = UserDefaults.standard.string(forKey: "agentLicenseNumber") ?? ""
        let state = UserDefaults.standard.string(forKey: "agentState") ?? ""
        if !license.isEmpty {
            syncListingsForLicense(license, state: state)
        }
    }
}
