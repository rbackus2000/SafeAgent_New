# SafeAgent

SafeAgent is an iOS application designed to enhance the safety of real estate agents during property showings through geofencing, calendar integration, and emergency features.

## Features

- **Calendar Integration**: Automatically import showings from your calendar
- **Geofencing**: Get notified when entering or leaving a property
- **Panic Button**: Quick access to emergency help when needed
- **Location Tracking**: Keep track of your showing locations
- **Offline Support**: Core functionality works without internet connection

## Screenshots

[Screenshots will be added here]

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Apple Developer Account for testing on physical devices

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/SafeAgent.git
```

2. Open the project in Xcode:
```bash
cd SafeAgent
open SafeAgent.xcodeproj
```

3. Install dependencies (if any):
```bash
# If using CocoaPods
pod install
```

4. Build and run the application in Xcode

## Usage

### Calendar Integration

The app automatically syncs with your device's calendar to import property showings. For best results, format your calendar events as follows:

- Title: Include "Showing" or "Listing" followed by the property address
- Example: "Showing - 123 Main St, Anytown, TX 12345"

### Geofencing

The app creates a virtual boundary around each property. When you enter or exit this boundary:
1. You'll receive a notification
2. The app will update the showing status
3. Emergency features become available if needed

### Emergency Features

The panic button appears when you're at a showing location. Tapping it will:
1. Alert your emergency contacts
2. Share your current location
3. Provide quick access to emergency services

## Architecture

SafeAgent follows the MVVM (Model-View-ViewModel) architecture pattern using SwiftUI and Combine for reactive programming. The app uses CoreData for local storage and CoreLocation for geofencing capabilities.

For more detailed information about the project architecture, see [PLANNING.md](PLANNING.md).

## Development

For current development tasks and roadmap, see [TASK.md](TASK.md).

### Project Structure

```
SafeAgent/
├── Core/ - Core services and utilities
├── Features/ - Main feature modules
├── UI/ - Reusable UI components
└── Resources/ - Assets and configuration files
```

## Testing

Run the tests in Xcode:
1. Select the SafeAgent scheme
2. Press Cmd+U or navigate to Product > Test

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [CoreLocation](https://developer.apple.com/documentation/corelocation)
- [EventKit](https://developer.apple.com/documentation/eventkit)

## Contact

Your Name - [@yourtwitter](https://twitter.com/yourtwitter) - email@example.com

Project Link: [https://github.com/yourusername/SafeAgent](https://github.com/yourusername/SafeAgent) 