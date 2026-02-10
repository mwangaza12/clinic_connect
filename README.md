# ClinicConnect - Interoperable EHR System for Kenya

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)](https://firebase.google.com/)
[![FHIR R4](https://img.shields.io/badge/FHIR-R4-green.svg)](https://hl7.org/fhir/R4/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Overview

ClinicConnect is a mobile-first Electronic Health Record (EHR) system designed for the Kenyan healthcare environment. It enables healthcare facilities to manage patient data efficiently while maintaining interoperability between independent facilities through FHIR standards.

### Key Features

- ✅ **Offline-First Architecture** - Works without internet connectivity
- ✅ **Patient Registration** - NUPI-based patient identification
- ✅ **Clinical Records** - Comprehensive visit documentation
- ✅ **Referral Management** - Seamless inter-facility patient referrals
- ✅ **FHIR Compliance** - HL7 FHIR R4 for data interoperability
- ✅ **Multi-Facility Support** - Independent facility data ownership
- ✅ **Automatic Sync** - Background synchronization when online
- ✅ **Disease Management** - HIV/ART, Diabetes, Hypertension, Malaria

## Architecture

ClinicConnect uses Clean Architecture with BLoC pattern:
```
├── Presentation Layer (UI/BLoC)
├── Domain Layer (Entities/Use Cases)
└── Data Layer (Models/Repositories/Datasources)
```

**Technology Stack:**
- **Frontend:** Flutter/Dart
- **Backend:** Firebase (Firestore, Auth, Storage)
- **Local Storage:** SQLite
- **State Management:** BLoC
- **Standards:** FHIR R4

## Prerequisites

- Flutter SDK (3.x or higher)
- Dart SDK (3.x or higher)
- Android Studio / VS Code
- Firebase account
- Android/iOS device or emulator

## Installation

### 1. Clone Repository
```bash
git clone https://github.com/mwangaza12/clinicconnect.git
cd clinicconnect
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android/iOS apps to your Firebase project
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place configuration files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

5. Enable Firebase services:
   - Authentication (Email/Password)
   - Cloud Firestore
   - Firebase Storage

### 4. Configure Firebase

Update `lib/core/config/firebase_config.dart`:
```dart
class FirebaseConfig {
  static const String apiKey = 'YOUR_API_KEY';
  static const String projectId = 'YOUR_PROJECT_ID';
  // ... other config
}
```

### 5. Run the App
```bash
flutter run
```

## Project Structure
```
lib/
├── core/                      # Core functionality
│   ├── constants/            # App constants
│   ├── config/               # Configuration
│   ├── network/              # API clients
│   ├── database/             # SQLite database
│   ├── sync/                 # Offline sync
│   └── utils/                # Utilities
│
├── features/                 # Feature modules
│   ├── auth/                # Authentication
│   ├── patient/             # Patient management
│   ├── encounter/           # Clinical visits
│   ├── referral/            # Inter-facility referrals
│   ├── medication/          # Prescriptions
│   ├── lab/                 # Laboratory
│   ├── appointment/         # Scheduling
│   ├── interop/             # FHIR interoperability
│   └── sync/                # Data synchronization
│
├── shared/                   # Shared components
│   ├── widgets/             # Reusable widgets
│   ├── models/              # Common models
│   └── extensions/          # Dart extensions
│
└── routes/                   # Navigation
```

## Usage

### First Time Setup

1. **Launch App** → Setup wizard appears
2. **Choose Setup Type:**
   - New Facility (auto-creates Firebase project)
   - Join Existing Facility (connect to existing)
   - Connect Existing System (for interoperability)
3. **Enter Facility Details**
4. **Create Admin Account**
5. **Start Using**

### Patient Registration
```dart
// Navigate to patient registration
Navigator.pushNamed(context, '/patient/register');

// Fill in patient details
// NUPI, demographics, contact info, medical history

// Save (works offline)
// Syncs automatically when online
```

### Creating Referral
```dart
// Select patient
// Navigate to create referral
Navigator.pushNamed(context, '/referral/create');

// Select receiving facility
// Enter clinical summary
// Attach supporting documents
// Submit referral
```

### Offline Mode

- All features work offline
- Data saved to local SQLite
- Automatic sync when internet available
- Visual indicator shows sync status

## FHIR Interoperability

ClinicConnect stores all data in FHIR R4 format:
```json
{
  "resourceType": "Patient",
  "identifier": [{
    "system": "http://kenya.go.ke/fhir/identifier/nupi",
    "value": "123456789"
  }],
  "name": [{
    "family": "Doe",
    "given": ["John"]
  }],
  "gender": "male",
  "birthDate": "1990-05-15"
}
```

**Supported FHIR Resources:**
- Patient
- Encounter
- Observation
- Condition
- MedicationRequest
- ServiceRequest
- DiagnosticReport
- Appointment
- Practitioner
- Organization

## API Documentation

See [API_DOCUMENTATION.md](docs/API_DOCUMENTATION.md) for complete API reference.

**Key Endpoints:**
```
POST   /auth/login
POST   /patients
GET    /patients?nupi={nupi}
POST   /encounters
POST   /referrals
GET    /fhir/Patient/{id}
```

## Database Schema

See [DATABASE_DESIGN.md](docs/DATABASE_DESIGN.md) for complete schema.

**Core Tables:**
- patients
- encounters
- referrals
- observations
- conditions
- medication_requests

## Configuration

### Environment Variables

Create `.env` file:
```env
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
PATIENT_INDEX_URL=https://index.clinicconnect.ke
```

### App Configuration

Edit `lib/core/constants/app_constants.dart`:
```dart
class AppConstants {
  static const String appName = 'ClinicConnect';
  static const String appVersion = '1.0.0';
  static const int syncIntervalMinutes = 15;
  static const int maxOfflineDays = 30;
}
```

## Testing

### Run All Tests
```bash
flutter test
```

### Run Specific Tests
```bash
# Unit tests
flutter test test/unit

# Widget tests
flutter test test/widget

# Integration tests
flutter test test/integration
```

### Test Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Deployment

### Android APK
```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle
```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS
```bash
flutter build ios --release
```

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## Coding Standards

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use BLoC pattern for state management
- Write tests for all features
- Comment complex logic
- Use meaningful variable names

## Troubleshooting

### Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Firebase Connection
```bash
# Verify Firebase configuration
flutterfire configure
```

### Sync Issues

1. Check internet connectivity
2. Verify Firebase rules
3. Check sync queue: Settings → Sync Status
4. Manual sync: Pull down to refresh

## Roadmap

- [ ] Phase 1: Core Features (Q1 2024)
  - [x] Patient Registration
  - [x] Clinical Records
  - [x] Referrals
  - [ ] Medications
  - [ ] Lab Tests

- [ ] Phase 2: Advanced Features (Q2 2024)
  - [ ] Appointments
  - [ ] Analytics Dashboard
  - [ ] Billing
  - [ ] Reports

- [ ] Phase 3: Integration (Q3 2024)
  - [ ] MPR/NUPI Integration
  - [ ] M-Pesa Integration
  - [ ] SMS Notifications
  - [ ] DHIS2 Export

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Kenya Ministry of Health for FHIR guidelines
- HL7 International for FHIR standards
- Flutter team for excellent framework
- Firebase for backend infrastructure

## Contact

**Project Maintainer:** [Your Name]

- Email: your.email@example.com
- GitHub: [@mwangaza12](https://github.com/mwangaza12)
- Project Link: [https://github.com/mwangaza12/clinicconnect](https://github.com/mwangaza12/clinicconnect)

## Support

- **Documentation:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/mwangaza12/clinicconnect/issues)
- **Discussions:** [GitHub Discussions](https://github.com/mwangaza12/clinicconnect/discussions)

## Citation

If you use ClinicConnect in your research, please cite:
```bibtex
@software{clinicconnect2024,
  title={ClinicConnect: Interoperable EHR System for Kenya},
  author={Your Name},
  year={2024},
  url={https://github.com/mwangaza12/clinicconnect}
}
```

---

**Built with ❤️ for Kenyan Healthcare**