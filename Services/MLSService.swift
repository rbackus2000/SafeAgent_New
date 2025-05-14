import Foundation

struct PropertyListing: Identifiable {
    let id: String
    let address: String
    let price: String
    let imageUrl: String?
    let mlsNumber: String
    let details: String
    let agentName: String
    let agentPhone: String
    let agentEmail: String
    let featureTags: [String]?
    let longDescription: String?
}

class MLSService: ObservableObject {
    // Demo/mock property data
    private let sampleListings: [PropertyListing] = [
        PropertyListing(
            id: "1",
            address: "123 Main St, Springfield",
            price: "$500,000",
            imageUrl: "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80",
            mlsNumber: "MLS#123222",
            details: "3 bed, 2 bath, 1800 sqft. Recently renovated kitchen.",
            agentName: "Sarah Johnson",
            agentPhone: "123-3434",
            agentEmail: "robert@johns.com",
            featureTags: [
                "STAINLESS STEEL APPLIANCES",
                "COVERED PATIO",
                "FENCED BACKYARD",
                "COZY FRONT PORCH",
                "VINYL AND TILE FLOORING",
                "BRIGHT AND OPEN LAYOUT"
            ],
            longDescription: "****Seller to contribute up to 2% in closing costs as allowable****Welcome to this inviting 3-bedroom, 2-bathroom single-story home that combines comfort, style, and functionality. Inside, you'll discover a bright and open layout featuring stain cabinets and laminate countertops in the kitchen, perfectly complemented by stainless steel appliances — ideal for preparing your favorite meals.\n\nThe home offers a mix of vinyl and tile flooring throughout, ensuring easy maintenance and a modern touch. Both bathrooms are well-appointed, and the primary suite provides a relaxing retreat with its own private bath.\n\nEnjoy outdoor living at its finest with a fenced backyard, covered patio, and a cozy front porch — perfect for morning coffee or evening gatherings. Additional features include an attached garage, providing secure parking and extra storage space.\n\nDon't miss the opportunity to own this move-in-ready gem, offering the perfect blend of indoor comfort and outdoor enjoyment!"
        ),
        PropertyListing(
            id: "2",
            address: "456 Oak Ave, Shelbyville",
            price: "$750,000",
            imageUrl: "https://images.unsplash.com/photo-1460518451285-97b6aa326961?auto=format&fit=crop&w=800&q=80",
            mlsNumber: "MLS#654321",
            details: "4 bed, 3 bath, 2400 sqft. Large backyard and pool.",
            agentName: "Michael Lee",
            agentPhone: "555-987-6543",
            agentEmail: "michael.lee@homesplus.com",
            featureTags: nil,
            longDescription: nil
        ),
        PropertyListing(
            id: "3",
            address: "789 Pine Rd, Capital City",
            price: "$1,200,000",
            imageUrl: "https://images.unsplash.com/photo-1507089947368-19c1da9775ae?auto=format&fit=crop&w=800&q=80",
            mlsNumber: "MLS#112233",
            details: "5 bed, 4 bath, 3500 sqft. Luxury finishes throughout.",
            agentName: "Emily Chen",
            agentPhone: "555-246-8100",
            agentEmail: "emily.chen@luxuryestates.com",
            featureTags: nil,
            longDescription: nil
        )
    ]
    
    @Published var fetchedListings: [PropertyListing] = []
    
    // Example: Fetch MLS listings for agent
    func fetchMLSListings(agentId: String, completion: @escaping ([PropertyListing]) -> Void) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(self.sampleListings)
        }
    }

    // Demo: filter by license number (simulate association)
    func fetchListings(forLicense license: String, completion: (() -> Void)? = nil) {
        // For demo, assign all listings if license is not empty, else none
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if license.isEmpty {
                self.fetchedListings = []
            } else {
                self.fetchedListings = self.sampleListings
            }
            completion?()
        }
    }

    func fetchDetails(for mlsNumber: String, completion: @escaping (PropertyListing?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let listing = self.sampleListings.first { $0.mlsNumber == mlsNumber }
            completion(listing)
        }
    }
}

struct MLSListing: Identifiable, Codable {
    let id: String
    let address: String
    let price: Double
    let status: String
    // Add other MLS fields as needed
}
