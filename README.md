# 🎲 Moonseed — Godot 4 Edition

A **Balatro-style habit tracker** built in Godot 4 (GDScript).  
**Stable Build Release v0.7M**

Original Python/tkinter → Go/Fyne → **Godot 4 GDScript**.

---

## 🚀 Getting Started

### Requirements
- **Godot 4.2+** (download from https://godotengine.org)

### Setup
1. Open Godot 4 Engine
2. Click **Import** and select this folder (`Moonseed/`)
3. Godot will import and configure all assets automatically
4. Press **▶ Play** (F5) to run

### First Run
- A **Default** profile is created automatically
- Sample tasks and relics are seeded on first launch
- Visit **⚙ Settings → Dev Tools → Populate Sample Data** to get started quickly

---

## 🎮 How to Play

### 📋 PLAY Tab
- Each **Task** has a dice roll (d6 default, upgrade via Shop)
- **Difficulty** sets how many times you roll per task and how challenging you find a life event
- Press **🎲** to roll individual tasks, or **ROLL ALL DICE** for everything
- Activate **Relics** with checkboxes to apply their multiplier to your score
- Press **💾 SAVE DAY** to commit your score to the calendar

### 📅 CALENDAR Tab
- Heat-map view of your dice box scores
- Click any day to navigate to it
- Green = completed, brighter = higher score

### 🛒 SHOP Tab
- **Dice box shop** refreshes at midnight (seeded by date)
- Buy dice upgrades, Jokers, and Power-ups
- Jokers apply passive effects during dice rolling

### 🎒 SATCHEL Tab
- Add/remove **Tasks** and **Relics**
- Adjust difficulty (1–5) and die type (d6–d20)

### 📜 CONTRACTS Tab
- Set **Boss Challenges** with deadlines and subtasks
- Difficulty tiers: Reminder → Mini Boss → Boss
- Complete contracts for rewards!

### 🌿 GARDEN Tab
- Grow **plants** with passive score effects
- Water them daily to level up (stages 0–3)
- Higher-stage plants provide stronger bonuses

### ⚙ SETTINGS Tab
- Switch / create / delete **Profiles**
- Set your **Timezone**
- Dev tools: populate 365 days of test data, give all dice

---

## 🎲 Scoring Formula

```
Score = (Σ Roll Values × 5) × (1.0 + Σ Relic Multipliers) × Joker Bonuses
```

---

## 📁 Project Structure

```
Moonseed/
├── project.godot          # Godot project config
├── autoloads/
│   ├── GameData.gd        # Global state & constants (singleton)
│   └── Database.gd        # JSON persistence layer (singleton)
├── scenes/
│   ├── Main.tscn          # Root scene with TabContainer
│   ├── PlayTab.tscn       # Dice box rolling
│   ├── CalendarTab.tscn   # Monthly heatmap
│   ├── ShopTab.tscn       # Dice box Balatro shop
│   ├── SatchelTab.tscn  # Task/Relic management
│   ├── ContractsTab.tscn  # Boss challenges
│   ├── GardenTab.tscn     # Plant garden
│   └── SettingsTab.tscn   # Profiles & settings
└── scripts/
    ├── Main.gd            # Root controller & header
    ├── PlayTab.gd         # Task rolling & score logic
    ├── CalendarTab.gd     # Calendar heatmap UI
    ├── ShopTab.gd         # Shop UI & purchase logic
    ├── SatchelTab.gd    # CRUD for tasks/relics
    ├── ContractsTab.gd    # Contract management
    ├── GardenTab.gd       # Garden grow system
    └── SettingsTab.gd     # Settings & dev tools
```

---

## 💾 Save Data

Save files are stored at:
- **Windows:** `%APPDATA%\Godot\app_userdata\Moonseed\moonseed\`
- **macOS:** `~/Library/Application Support/Godot/app_userdata/Moonseed/moonseed/`
- **Linux:** `~/.local/share/godot/app_userdata/Moonseed/moonseed/`

Data is stored as JSON files (no external dependencies required).



*Ported from Python/tkinter original. Go/Fyne reference also provided.*
