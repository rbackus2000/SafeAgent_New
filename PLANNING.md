# SafeAgent App Planning Document

## Overview
SafeAgent is an iOS application designed to enhance real estate agent safety during property showings. The app integrates with calendar events, provides geofencing capabilities, and includes emergency features for agent protection.

## Architecture
The app follows the MVVM (Model-View-ViewModel) architecture with SwiftUI as the primary UI framework.

### Core Components
1. **Models** - Core Data entities for data persistence
2. **Views** - SwiftUI views for the user interface
3. **ViewModels** - Business logic and state management
4. **Services** - Calendar integration, location services, geofencing

### Key Design Patterns
1. **Dependency Injection** - Used for passing services and contexts to views
2. **Observer Pattern** - Notification-based communication between components
3. **Protocol-Oriented Programming** - Swift protocols for clear interfaces
4. **Value Types** - SwiftUI views as structs for better performance

## Directory Structure
```
SafeAgent/
├── Core/
│   ├── Services/
│   │   ├── CalendarService.swift
│   │   ├── LocationService.swift
│   │   └── GeofenceService.swift
│   ├── Models/
│   │   └── CoreData models
│   └── Persistence/
│       └── PersistenceController.swift
├── Features/
│   ├── Appointments/
│   │   ├── AppointmentsView.swift
│   │   ├── AppointmentDetailView.swift
│   │   └── AddAppointmentView.swift
│   ├── Safety/
│   │   ├── PanicButton.swift
│   │   └── EmergencyContactsView.swift
│   └── Settings/
│       └── SettingsView.swift
├── UI/
│   ├── Components/
│   │   ├── AppointmentRowView.swift
│   │   ├── MapView.swift
│   │   └── CustomButtons.swift
│   └── Styles/
│       └── AppTheme.swift
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

## Design Principles
1. **User-Centered Design** - Focus on agent safety and intuitive interactions
2. **Reliability** - Robust geofencing and location tracking
3. **Performance** - Efficient battery usage for background location monitoring
4. **Privacy** - Secure handling of location data and personal information

## Modularity & Dependency Management
1. **Avoiding Circular Dependencies** - Views use direct components or notifications instead of circular imports
2. **Component Reusability** - UI components are designed to be reused across different views
3. **Clear Interfaces** - Well-defined inputs and outputs for each component
4. **State Management** - Using environment objects for app-wide state, published properties for observable changes

## Key Features
1. **Calendar Integration** - Sync with calendar events to automatically import showings
2. **Geofencing** - Create virtual boundaries around showing locations
3. **Safety Alerts** - Panic button and automatic alerts when entering/exiting properties
4. **Offline Support** - Core functionality works without internet connection
5. **Emergency Contacts** - Quick access to emergency contacts

## Technical Specifications
- **iOS Target**: iOS 15.0+
- **Frameworks**: SwiftUI, CoreData, CoreLocation, EventKit
- **Design Pattern**: MVVM
- **State Management**: Combine
- **Dependencies**: Minimal third-party dependencies

## UI/UX Guidelines
- Follow Apple's Human Interface Guidelines
- Support Dark Mode
- Support Dynamic Type for accessibility
- Use SF Symbols for consistent iconography
- Implement haptic feedback for important actions

## Future Enhancements
1. **Check-in System** - Automated check-ins with time limits
2. **Client Database** - Store client information securely
3. **Route Planning** - Optimize routes between showings
4. **Analytics** - Track safety metrics and app usage
5. **Apple Watch Integration** - Quick access to panic button on Apple Watch

## Development Roadmap
1. **Phase 1**: Core functionality - Calendar sync, basic geofencing
2. **Phase 2**: Safety features - Panic button, emergency contacts
3. **Phase 3**: Enhanced geofencing and notifications
4. **Phase 4**: UI polish and performance optimization
5. **Phase 5**: Additional features and platform expansion

## Testing Strategy
- Unit tests for core business logic
- UI tests for critical user flows
- Beta testing with real estate agents
- Performance testing for battery consumption

## Architectural Decisions

### View Structure
- MainTabView serves as the app's container, providing navigation between main sections
- Each major feature has its own directory with related views and components
- UI components are kept separate for reusability

### State Management
- Use @StateObject for view-owned observable objects
- Use @ObservedObject for objects passed to a view
- Use @EnvironmentObject for objects that need to be accessed by many views
- Use NotificationCenter for cross-component communication to avoid tight coupling

### Error Handling
- Use Result type for operations that can fail
- Provide user-friendly error messages
- Log detailed error information for debugging

Last updated: May 15, 2023 