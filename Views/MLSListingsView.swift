import SwiftUI

struct MLSListingsView: View {
    @AppStorage("agentLicenseNumber") private var licenseNumber: String = ""
    @AppStorage("agentState") private var agentState: String = ""
    @StateObject private var viewModel = MLSListingsViewModel()
    @State private var selectedListing: PropertyListing? = nil

    var body: some View {
        NavigationView {
            VStack {
                if licenseNumber.isEmpty || agentState.isEmpty {
                    Text("Please enter your State and License Number in your Profile to view MLS listings.")
                        .foregroundColor(.secondary)
                        .padding()
                } else if viewModel.isLoading {
                    ProgressView("Loading MLS listings...")
                        .padding()
                } else if viewModel.listings.isEmpty {
                    Text("No listings found for your license number.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(viewModel.listings) { listing in
                                Button(action: {
                                    selectedListing = listing
                                }) {
                                    VStack(alignment: .center, spacing: 12) {
                                        if let imageUrl = listing.imageUrl, let url = URL(string: imageUrl) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                        .frame(height: 180)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(height: 180)
                                                        .clipped()
                                                        .cornerRadius(12)
                                                case .failure:
                                                    Image(systemName: "house.fill")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(height: 100)
                                                        .foregroundColor(.gray)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        } else {
                                            Image(systemName: "house.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                                .foregroundColor(.gray)
                                        }
                                        VStack(spacing: 4) {
                                            Text(listing.address)
                                                .font(.headline)
                                                .multilineTextAlignment(.center)
                                            Text(listing.price)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.green)
                                                .multilineTextAlignment(.center)
                                        }
                                        Text(listing.mlsNumber)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        VStack(spacing: 2) {
                                            Text(listing.agentName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            HStack(spacing: 6) {
                                                Image(systemName: "phone.fill")
                                                    .foregroundColor(.blue)
                                                Text(listing.agentPhone)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .multilineTextAlignment(.center)
                                            HStack(spacing: 6) {
                                                Image(systemName: "envelope.fill")
                                                    .foregroundColor(.blue)
                                                Text(listing.agentEmail)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .multilineTextAlignment(.center)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("MLS Listings")
            .onAppear {
                viewModel.syncListingsForLicense(licenseNumber, state: agentState)
            }
            .sheet(item: $selectedListing) { listing in
                MLSListingDetailView(listing: listing)
            }
        }
    }
}

struct MLSListingDetailView: View {
    let listing: PropertyListing
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let imageUrl = listing.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 220)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 220)
                            .clipped()
                            .cornerRadius(14)
                    case .failure:
                        Image(systemName: "house.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "house.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .foregroundColor(.gray)
            }
            Text(listing.address)
                .font(.title2)
            Text(listing.price)
                .font(.title3)
                .foregroundColor(.green)
            Text(listing.details)
                .font(.body)
            Spacer()
        }
        .padding()
    }
}

// Helper to extract tags from details (e.g., lines in ALL CAPS or separated by commas)
func extractFeatureTags(from details: String) -> [String]? {
    let tagCandidates = [
        "STAINLESS STEEL APPLIANCES", "COVERED PATIO", "FENCED BACKYARD", "COZY FRONT PORCH", "VINYL AND TILE FLOORING", "BRIGHT AND OPEN LAYOUT"
    ]
    return tagCandidates.filter { details.uppercased().contains($0) }
}

// Modern tag grid using LazyVGrid for iOS-native wrapping chips
struct TagGridView: View {
    let tags: [String]
    let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 6), count: 4)
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray4))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
