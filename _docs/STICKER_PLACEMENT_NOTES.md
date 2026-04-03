# STICKER PLACEMENT NOTES
# Documentation for sticker placement mechanics in the satchel tab

## Overview
This file contains design notes and implementation details for the sticker placement system used in the satchel/studio interface.

## Key Components

### Studio Room System
- **Studio Cards**: Task and relic/curio cards can be opened in a studio view
- **Sticker Slots**: Each card has predefined slots where stickers can be placed
- **Drag & Drop**: Users can drag stickers from the book onto cards
- **Visual Feedback**: Hover states, placement validation, and visual indicators

### Implementation Notes

#### Slot System
- Uses grid-based positioning with predefined anchor points
- Slots are stored in `_studio_slots` array
- Each slot has position, type, and current sticker data

#### Sticker Types
- Task stickers: Represent different tasks/activities
- Relic/Curio stickers: Represent special abilities or modifiers  
- Decorative stickers: Visual elements for customization

#### File Structure References
- Main implementation: `scripts/ui/satchel_tab.gd`
- Studio controller: `scripts/ui/StudioRoomController.gd`
- Paint canvas: `scripts/ui/studio_paint_canvas.gd`

## Development Notes

### Known Issues & Solutions
- Cache clearing required after file renames (resolved)
- Function dependencies must be declared before use (fixed)
- Theme propagation needs proper signal connections (implemented)

### Future Enhancements
- Add sticker rotation support
- Implement sticker layering system
- Add undo/redo functionality for sticker placement
