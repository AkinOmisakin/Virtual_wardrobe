# Cher: Virtual Wardrobe

📱 Project Overview
Virtual Wardrobe is a Flutter mobile application that allows users to create digital outfits by dragging, scaling, and rotating clothing items on a canvas. Users can upload photos of their clothes, organize them by category, and design outfit combinations with an intuitive touch-based interface.

✨ Key Features
Interactive Canvas – Drag, scale, and rotate clothing items with single-finger pan and multi-touch pinch gestures
Wardrobe Management – Add clothing items from camera or gallery
Category Filtering – Filter clothes by type (Tops, Bottoms, Dresses, etc.) — only active categories display
Multi-Select – Select multiple items at once to add to canvas in bulk
Layer Management – Bring items to front, duplicate, and delete from canvas
Outfit Toolbar – Quick-access pill-shaped toolbar for selected item actions
Persistent State – Canvas and selections persist while navigating tabs

🏗️ Project Structure
virtual_wardrobe/
├── lib/
│   ├── models/
│   │   ├── clothing_item.dart         # Individual clothing item model
│   │   ├── clothing_categories.dart   # Category grouping model
│   │   └── canvas_item.dart           # Canvas-specific item model (position, scale, rotation)
│   ├── pages/
│   │   ├── canvas.dart                # Main canvas editor screen
│   │   └── storage.dart               # Wardrobe inventory/storage
│   ├── services/
│   │   └── itemprovider.dart          # Provider state management for clothing items
│   └── main.dart
└── assets/
    └── icons/                          # App icons (clothing_carousel.png, outfit.png, etc.)

🎮 Usage Guide
Adding Items to Canvas
Tap the up-chevron button at the bottom to open the inventory sheet
Select from Store room or Outfits tabs
Use filter chips (All, Tops, Bottoms, etc.) to narrow down choices
Tap items to select them (multi-select enabled)
Press "Add selected item" to add to canvas
Manipulating Items on Canvas
Drag – Single finger drag to move selected item
Pinch – Two-finger pinch to scale up/down
Rotate – Two-finger twist to rotate
Select/Deselect – Tap item to select; tap again to deselect
Toolbar Actions (when item selected)
Duplicate – Clone the selected item
Bring to Front – Layer above other items
Delete – Remove from canvas
Clear – Remove all items
🛠️ Tech Stack
Framework – Flutter
State Management – Provider
Image Caching – cached_network_image
UI Components – dotted_border, material_design_icons
Navigation – Flutter Navigator with modal bottom sheets
📦 Dependencies
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  cached_network_image: ^3.0.0
  dotted_border: ^2.0.0
  collection: ^1.0.0

🚀 Getting Started
Clone the repository
Run flutter pub get
Ensure assets are configured in pubspec.yaml
Connect a device or emulator
Run flutter run
🎯 Core Classes
CanvasItem
Represents an item on the canvas with position, scale, and rotation:
class CanvasItem {
  final ClothingItem item;
  Offset position;
  double scale;
  double rotation;
  double size;
}

ClothingItem
Individual clothing piece from the wardrobe:
class ClothingItem {
  String id;
  String name;
  String imageUrl;
  String category;
}
ItemProvider
Manages the global wardrobe state and fetches clothing data.

🔧 Known Limitations & Future Improvements
Outfits tab UI not yet implemented
Camera/gallery upload hooks not connected
No export/save outfit functionality
No cloud synchronization
Canvas bounds checking not enforced (items can move off-screen)
📝 Notes
Single-finger drag ownership (_draggingItem) ensures smooth item movement without multi-select conflicts
Z-index stacking prevents need to mutate list order
setModalState in inventory sheet allows instant UI feedback without triggering full canvas rebuild