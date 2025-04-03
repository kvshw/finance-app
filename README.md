# Finance App

A modern Flutter application for personal finance management with a clean, intuitive interface and powerful analytics features.

## Features

- **Dashboard Overview**
  - Quick access to key financial metrics
  - Recent transactions list
  - Quick action buttons for common tasks

- **Transaction Management**
  - Add and edit expenses and income
  - Categorize transactions
  - Custom category management
  - Transaction history

- **Analytics**
  - Income vs Expenses trend analysis
  - Category-wise expense distribution
  - Customizable date range selection
  - Interactive charts and visualizations

- **User Interface**
  - Dark theme
  - Modern, clean design
  - Responsive layout
  - Intuitive navigation

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- iOS development tools (for iOS development)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/finance-app.git
   cd finance-app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
finance-app/
├── frontend/                 # Flutter application
│   ├── lib/
│   │   ├── screens/         # Application screens
│   │   ├── widgets/         # Reusable widgets
│   │   ├── models/          # Data models
│   │   ├── services/        # Business logic
│   │   └── main.dart        # Application entry point
│   └── pubspec.yaml         # Flutter dependencies
└── backend/                 # Backend services
    └── ...
```

## Dependencies

- `flutter_chart` - For financial charts and visualizations
- `google_fonts` - For typography
- `intl` - For date and number formatting
- `provider` - For state management
- `shared_preferences` - For local storage

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Version History

- v1.0.0 - Initial release
  - Basic transaction management
  - Analytics dashboard
  - Category management
  - Dark theme UI
