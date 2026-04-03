# Dice Cascade System Implementation

## Overview
The dice cascade system triggers when a die rolls its maximum value (e.g., a 6 on a d6). This causes:
1. Visual cascade effects
2. Automatic reroll of the die
3. Score accumulation (original max roll + bonus roll)
4. Cascading cascades if bonus rolls are also max values

## Components

### 1. Cascade Shader (`shaders/dice_explosion_shader.gdshader`)
- Custom particle shader for dice cascade effects
- Supports customizable cascade colors and particle behavior
- Fixed initialization issue for forward plus/mobile rendering
- Uses sprite-based particles with cascade color tinting

### 2. Enhanced Dice Base (`scripts/dice_base.gd`)
- Added cascade tracking variables (`_cascade_count`, `_base_result`)
- Enhanced `_trigger_cascade()` function with cascading logic
- Limited to 3 cascades to prevent infinite loops
- Proper score accumulation with visual feedback

### 3. Cascade Dice Scene (`scenes/DiceBase_Explosive.tscn`)
- Complete dice scene with particle system
- Configured GPUParticles2D with cascade shader
- All required child nodes for animations and effects

### 4. PlayTab Integration (`scripts/PlayTab.gd`)
- Connected to `dice_cascaded` signal
- Added visual cascade effects at task card positions
- Sound effects for cascades
- Automatic score updates

## How It Works

### Cascade Trigger
1. Die settles on maximum value (e.g., 6 on d6)
2. `_trigger_cascade()` function called
3. Cascade signal emitted via SignalBus
4. Visual and audio effects triggered

### Cascading Logic
1. First cascade stores original max roll
2. Bonus roll is performed (1 to sides)
3. Bonus result added to total
4. If bonus roll is also max value, trigger another cascade
5. Maximum 3 cascades to prevent infinite loops
6. Final combined total emitted as task_rolled signal

### Visual Effects
1. Shader-based ring glow animation
2. Particle burst with cascade shader
3. "CASCADE!" text popup at task card
4. Sound effect playback
5. Score accumulation display

## Usage

### To Enable Cascades:
1. Use the `DiceBase_Explosive.tscn` scene for dice
2. Ensure dice have proper shader materials
3. Connect cascade signals in PlayTab

### To Customize:
1. Modify cascade colors in shader parameters
2. Adjust particle count and behavior
3. Change cascade limit in dice_base.gd
4. Update visual effects in PlayTab

## Signal Flow

```
Die rolls max value
    ↓
_trigger_cascade()
    ↓
SignalBus.dice_cascaded.emit()
    ↓
PlayTab._on_dice_cascaded()
    ↓
Visual effects + sound
    ↓
Bonus roll calculation
    ↓
SignalBus.task_rolled.emit(combined_total)
```

## Performance Considerations

- Particle system limited to 64 particles
- Cascades limited to 3 maximum
- Effects auto-cleanup after animation
- Minimal performance impact during normal gameplay

## Future Enhancements

- Different cascade effects per die type
- Customizable particle shapes
- More complex cascade patterns
- Achievement integration for cascade chains
