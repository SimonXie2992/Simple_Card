# Simple Card — Smart Business Card & Document Scanner

A Flutter-based iOS app for scanning, managing, and sharing business cards and documents with built-in OCR and PDF generation.

## ✨ Features

### 📷 Smart Scanner
- **Full-screen camera** with real-time edge detection overlay
- **Dynamic alignment frame** — automatically tracks and highlights card/document edges using iOS Vision framework (`VNDetectRectanglesRequest`)
- **Auto-classification** — distinguishes business cards from documents based on detected aspect ratio
- **Perspective correction** — applies `CIPerspectiveCorrection` for a flat, clean scan result
- **Confirmation screen** — preview the corrected image before proceeding, with manual type toggle (Card ↔ Document)
- **Single / Continuous** capture modes with swipe or tap to switch
- **Gallery import** — pick existing photos with the same auto-detect pipeline

### 🪪 Business Card OCR
- Powered by **iOS Vision** (`VNRecognizeTextRequest`) — runs entirely on-device
- Automatically extracts: Name, Company, Title, Phone, Email, Address
- **Card Review** screen to verify and edit extracted fields before saving

### 📄 Document to PDF
- Scanned documents are automatically converted to **PDF** via native iOS rendering
- Multi-page support in **Continuous** capture mode — batch scan → merge into one PDF
- Share or save PDFs via the system share sheet

### 🗂️ Card Management
- **Card Holder** — browse all saved business cards in a searchable grid
- **Card Detail** — view full card info with the original scanned image
- **Card Edit** — modify any field after import
- **Import / Export** — scan new cards, import from gallery

### ⚙️ Settings & Tools
- **Notion Integration** — sync cards to a Notion database
- **Tools** — additional utilities for card data management

## 🏗️ Architecture

```
lib/
├── main.dart                  # App entry, routing, theme
├── models/
│   └── business_card.dart     # Data model
├── screens/
│   ├── home_screen.dart       # Tab navigation (Cards / Tools / Settings)
│   ├── scanner_screen.dart    # Camera + edge detection + capture flow
│   ├── card_holder_screen.dart
│   ├── card_detail_screen.dart
│   ├── card_edit_screen.dart
│   ├── card_management_screen.dart
│   ├── settings_screen.dart
│   └── tools_screen.dart
├── services/
│   └── scanner_service.dart   # Native channel bridge
├── widgets/
│   └── card_widget.dart       # Reusable card UI component
├── scanner_overlay.dart       # Edge detection overlay painter
├── data_extractor.dart        # OCR field extraction logic
└── notion_service.dart        # Notion API integration
```

**Native Layer** (`ios/Runner/AppDelegate.swift`):
- `processImage` — full OCR pipeline
- `detectRectangleLive` — real-time rectangle detection from camera stream (BGRA frames)
- `processCapture` — detect → perspective correct → classify → return processed image
- `generatePdf` — convert image paths to PDF

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.x
- Xcode ≥ 15 (for iOS builds)
- Physical iOS device recommended (camera features require real hardware)

### Run
```bash
flutter pub get
flutter run -d <device_id>
```

### Notes
- **Wireless debugging** on iOS 26+ may be slow; use a USB connection for best performance.
- Native Swift code changes require a **full rebuild** (stop → `flutter run` again); hot restart is not sufficient.

## 📝 Feedback

See [FEEDBACK.md](FEEDBACK.md) for the current issue tracker and wishlist.
