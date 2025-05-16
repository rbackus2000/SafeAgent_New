# SafeAgent Development Tasks

## Current Sprint

### High Priority
- [x] Fix geocoding functionality to properly handle addresses from calendar events
- [x] Implement address extraction from appointment titles
- [ ] Remove debug UI elements (Update Location, Test Geofence, Debug buttons) for production
- [x] Implement proper error handling for geocoding failures
- [ ] Optimize geofence monitoring to reduce battery consumption
- [x] Improve AppointmentsView UI and functionality
- [x] Filter out past appointments from the appointment list
- [x] Enhanced appointment detail view with comprehensive information
- [ ] Update Core Data model to include new appointment properties

### Medium Priority
- [x] Enhance LoginView with improved design, animations, and logo placeholder
- [x] Refactor appointment detail view for better UI/UX
- [x] Implement a responsive and modern list UI for appointments
- [ ] Add unit tests for geocoding and address extraction
- [x] Create dedicated GeofenceManager service separate from view code
- [x] Implement proper loading states during geocoding operations
- [ ] Add haptic feedback for important actions (entering/exiting geofence)
- [x] Create data model for comprehensive appointment information
- [x] Fix "Cannot find property" errors for extended AppointmentEntity
- [x] Fix "Cannot find 'AddAppointmentView' in scope" error
- [x] Fix "Cannot find 'AppointmentDetailCoreDataView' in scope" error
- [x] Fix "Type 'MainTabView' does not conform to protocol 'View'" error
- [x] Fix "Cannot find 'AppointmentService' in scope" error
- [x] Fix map display issues and automatic geocoding in AppointmentDetailView
- [x] Improve map accuracy by enhancing MapKit integration
- [x] Add "Mark Complete" functionality with client feedback collection
- [x] Implement Firebase integration for data storage
- [x] Fix Firebase authentication with Apple Sign In
- [x] Implement data saving to Firestore from ShowingCompleteView
- [ ] Integrate RecapHistoryView into main navigation and connect with ShowingCompleteView for viewing sent recaps

### Low Priority
- [x] Improve address validation before geocoding
- [ ] Add settings screen for configuring geofence radius
- [ ] Create onboarding flow for new users
- [ ] Implement analytics for feature usage
- [x] Add ability to capture client feedback after showings

## Backlog

### Features
- [ ] Emergency contacts management
- [ ] Check-in system with automated alerts
- [ ] Route optimization between showings
- [ ] Client database integration
- [ ] Apple Watch companion app
- [ ] Custom notification sounds
- [ ] Calendar event creation from app
- [ ] MLS integration for property details

### Technical Debt
- [ ] Refactor AppointmentsView to reduce complexity
- [ ] Move geocoding logic to dedicated service
- [ ] Create proper error types instead of string messages
- [ ] Implement comprehensive logging system
- [ ] Optimize CoreData queries and models

### Bug Fixes
- [x] Fix compilation errors in AppointmentsView.swift
- [x] Fix circular import issues between views
- [x] Fix MainTabView conformance to View protocol
- [x] Resolve missing PersistenceController.checkAppointmentCoordinates() error
- [x] Fix missing map and "Get Coordinates" button functionality
- [x] Fix map location accuracy issues
- [x] Fix "Cannot find 'CLGeocodeRequestOption' in scope" error
- [x] Fix "Invalid redeclaration of 'AnnotationItem'" error
- [x] Fix "Invalid redeclaration of 'MapAnnotationItem'" error
- [x] Fix "Cannot find 'Views' in scope" error
- [x] Fix "No such module 'Models'" error
- [x] Fix layout constraints in appointment detail view
- [ ] Address potential memory leaks in location monitoring
- [x] Fix calendar sync for recurring events
- [ ] Resolve background refresh issues
- [x] Fix "Invalid appointment ID" error in ShowingCompleteView

## Completed Tasks
- [x] Initial calendar integration
- [x] Basic geofencing implementation
- [x] Panic button UI
- [x] Fix "Cannot find 'extractNumericAddress' in scope" error
- [x] Implement address cleanup from calendar events
- [x] Fix missing propertyAddress field population
- [x] Enhance LoginView with modern UI and animations (May 12, 2025)
- [x] Add Color extension for hex color support
- [x] Create logo image asset placeholder
- [x] Redesign AppointmentRowView with improved layout and visual indicators (May 12, 2025)
- [x] Update AppointmentsView with modern design and better UX (May 12, 2025)
- [x] Add pull-to-refresh functionality to appointments list
- [x] Create an enhanced empty state view for when no appointments exist
- [x] Implement AppointmentEntity extensions for additional property data (May 12, 2025)
- [x] Create comprehensive property details section in appointment view
- [x] Add client and agent information sections to appointment detail view
- [x] Implement action buttons for safety features and navigation
- [x] Add safe fallbacks for missing Core Data properties (May 12, 2025)
- [x] Restore AddAppointmentView implementation (May 12, 2025)
- [x] Fix "Cannot find 'AppointmentDetailCoreDataView' in scope" by implementing inline detail view (May 12, 2025)
- [x] Fix "Type 'MainTabView' does not conform to protocol 'View'" by updating class definitions (May 12, 2025)
- [x] Implement notification-based geofence monitoring to avoid UI casting issues (May 12, 2025)
- [x] Recreate AppointmentDetailView design with improved layout and consistent styling (May 12, 2025)
- [x] Add dual map functionality with both view and navigation options (May 12, 2025)
- [x] Fix "Cannot find 'AppointmentService' in scope" error by implementing forward declaration (May 12, 2025)
- [x] Implement automatic geocoding for appointments on startup and detail view appearance (May 12, 2025)
- [x] Fix map display issues in AppointmentDetailView (May 12, 2025)
- [x] Enhance MapKit integration with improved accuracy and features (May 12, 2025)
- [x] Fix map location accuracy issues for property addresses (May 12, 2025)
- [x] Fix "Cannot find 'CLGeocodeRequestOption' in scope" error (May 12, 2025)
- [x] Fix "Invalid redeclaration of 'AnnotationItem'" error (May 12, 2025)
- [x] Fix appointment location showing 3-4 blocks from actual address in map view (May 12, 2025)
- [x] Implement real-time location tracking with distance to appointment indicator (May 12, 2025)
- [x] Remove hardcoded location database in favor of dynamic geocoding (May 12, 2025)
- [x] Fix "Performing I/O on the main thread can cause hangs" warning (May 12, 2025)
- [x] Implement automatic map centering on user location (May 12, 2025)
- [x] Adjust status pill position in appointment detail view (May 12, 2025)
- [x] Convert distance measurements from meters to feet/miles for US users (May 12, 2025)
- [x] Create ShowingCompleteView for appointment completion workflow (May 15, 2025)
- [x] Fix MapAnnotationItem and Views namespace issues by refactoring code structure (May 16, 2025)
- [x] Refactored ShowingCompleteView to break up large body into smaller subviews for type-checking performance; removed all [weak self] from SwiftUI closures; added FirestoreService stub and ensured single MapAnnotationItem definition (May 16, 2025)
- [x] Fixed "'weak' may only be applied to class and class-bound protocol types" errors in ShowingCompleteView (June 10, 2025)
- [x] Fixed "The compiler is unable to type-check this expression in reasonable time" by using AnyView type erasure and more structured view composition (Current date)
- [x] Added addressed type issues with annotationItems by creating a proper MapAnnotationItem type with Identifiable conformance (today's date)
- [x] Fixed map display issue in ShowingCompleteView to ensure it shows the actual property address and coordinates (June 12, 2025)
- [x] Enhanced map implementation to prevent it from showing Apple's headquarters coordinates and ensure it's a static, non-interactive snapshot (June 13, 2025)
- [x] Implemented Firebase integration and Firestore data storage (June 15, 2025)
- [x] Fixed Apple Sign In authentication with Firebase Auth using proper nonce validation (June 15, 2025)
- [x] Fixed UUID validation issue in ShowingCompleteView causing "Invalid appointment ID" errors (June 15, 2025)
- [x] Added improved error handling and debug logging for Firestore operations (June 15, 2025)
- [x] Fixed "Missing or insufficient permissions" error when saving showing data to Firestore by using user-specific collections (June 16, 2025)
- [x] Created and implemented Firestore security rules with proper user-based authentication and data access controls (June 16, 2025)
- [x] Fixed "Cannot find 'MapAnnotationItem' in scope" error in AppointmentsView and AppointmentDetailView by adding local type definitions (Current date)
- [x] Fixed "Cannot find 'ShowingCompleteView' in scope" and "Invalid component of Swift key path" errors by using namespaces and proper environment key path (Current date)
- [x] Removed namespace approach and fixed type conflicts by using a cleaner approach with local definitions and renamed the MapAnnotationItem in ShowingCompleteView to ShowingMapAnnotationItem to avoid conflicts (Current date)
- [x] Added compiler directives to increase type-checking time in complex view files (Current date)
- [x] Created a temporary local version of ShowingCompleteView in AppointmentDetailView to resolve the "Cannot find ShowingCompleteView in scope" error (Current date)
- [x] Enhanced the temporary ShowingCompleteView implementation with a fully functional UI that matches the original design (Current date)
- [x] Implemented Firebase integration for the temporary LocalShowingCompleteView to properly save showing completion data to Firebase (Current date)
- [x] Fixed "Send Recap to Office" functionality to properly save data to the showingRecaps collection and track sent recaps in the user's sentRecaps collection (Current date)
- [x] Fixed Firebase permissions error by using user-specific collections and improved error handling (Current date)
- [x] Updated Firebase collection paths to match the security rules (officeRecaps and showingCompletions) (Current date)
- [x] Fixed "Mark Complete" button requiring two taps to open ShowingCompleteView by using DispatchQueue.main.async and adding ButtonStyle (Current date)
- [x] Fixed appointment selection in AppointmentsView requiring two taps by using DispatchQueue.main.async and BorderlessButtonStyle (Current date)
- [x] Fixed compilation errors by moving UUID extension to a separate file and removing duplicate MapAnnotationItem definitions (Current date)
- Fixed navigation and Core Data update issues in AppointmentsView and AppointmentDetailView.
- Ensured all appointments have valid propertyAddress and id before showing in UI.
- Added automatic geocoding and address fixing after appointments are loaded, with refresh logic.
- Added a user-friendly down arrow and message to prompt pull-to-refresh on first launch.
- Refactored AppointmentDetailView to use @FetchRequest by id for live updates.
- Removed duplicate/floating Directions button from map view.
- Fixed double navigation bar issue by removing inner NavigationView from AppointmentDetailView.
- The star rating in ShowingCompleteView is now visually interactive and animated (June 9, 2024).
- The selected rating is saved and included in the showing completion report sent to Firebase (June 9, 2024).

## Completed Tasks (June 2024)

- Enhanced MLSListingsView UI to display property images, address, price, MLS number, and agent info in a modern card layout.
- Updated PropertyListing model to include agentName, agentPhone, agentEmail, and (temporarily) featureTags and longDescription fields for richer detail views.
- Implemented and tested several tag chip layouts (FlexibleView, LazyVGrid, etc.) for property features; reverted to original detail view for simplicity and native feel after user feedback.
- Improved MLSListingDetailView to show property image, address, price, and details, matching the rest of the app's style.
- Fixed type-checking and compiler issues related to complex SwiftUI view builders for tag chips.
- Ensured all changes are consistent with MVVM and SwiftUI best practices.
- Added a Sign Out button to ProfileView that signs out the user from Firebase and updates authentication state (June 15, 2025)
- Fixed 'Cannot find Auth in scope' error in ProfileView by importing FirebaseAuth (June 15, 2025)
- Removed duplicate Sign in with Apple button from LoginView, keeping only the blue custom button (June 15, 2025)
- Updated Sign Out button in ProfileView to use blue background and white text for visual consistency (June 15, 2025)
- Fixed Firebase Storage profile image upload: explicitly set contentType to 'image/jpeg' in upload metadata to match security rules and resolve permission errors. Updated troubleshooting steps and ensured only one FirestoreService.swift is used and properly referenced. (June 16, 2025)

### Panic Button & Noonlight Integration (June 15, 2025)
- Made panic button responsive and visually prominent on all iPhone screen sizes using GeometryReader and dynamic sizing.
- Ensured panic button remains vertically centered regardless of map snippet overlay.
- Moved map snippet overlay to appear above the panic button and reduced top padding for better usability.
- Added extra spacing between map snippet and panic button to prevent accidental taps.
- Removed 'View in Google Maps' link from map overlay for a cleaner UI.
- Verified Noonlight API integration uses the correct endpoint (`/platform/v1/alarms`) and bearer token header.
- Searched codebase to confirm no incorrect Noonlight endpoints are used.
- Provided debugging steps for API calls, Info.plist ATS settings, and Noonlight token/scope requirements.

## Discovered During Work (June 2024)

- Future: Consider a more native, compact, and visually appealing tag chip layout for property features if/when user requests it again.
- Noonlight API integration requires correct endpoint, valid bearer token, and proper OAuth scopes (e.g., `write:alarm`). Webhook URL is only needed for backend event notifications, not for basic panic alerting from the app. (June 15, 2025)
- Firebase Storage will reject uploads with incorrect contentType (e.g., text/plain); always set correct image contentType in upload metadata. (June 16, 2025)

- Panic button now always uses the Noonlight sandbox endpoint and the provided sandbox token (G2ij1Bi0IaouXqesiSRAHLd2uvQztdAV) for all alarm tests. To revert to production, restore the production API call and update the token. (June 16, 2025)
- Noonlight sandbox integration: reverted payload to address-only (no coordinates) per API requirements, fixed function signature and call in PanicButtonView, and confirmed production alert logic still uses coordinates. Geocoding and map logic elsewhere in the app is unaffected. (June 16, 2025)

---

Last updated: June 15, 2025 