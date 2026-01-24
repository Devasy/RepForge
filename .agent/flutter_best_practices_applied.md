# Flutter Best Practices Applied - TextFormField State Management

## Summary
Fixed code quality issues in `workout_flow_screen.dart` by replacing `initialValue` with `TextEditingController` following Flutter best practices.

## Problem
The previous implementation used `initialValue` for `TextFormField` widgets in the dropset UI:

```dart
TextFormField(
  initialValue: _currentWeight.toString(),  // ⚠️ Resets on rebuild
  onChanged: (val) { ... },
)
```

### Issues with `initialValue`:
1. **Resets on rebuild** - User input is lost when the widget rebuilds
2. **No programmatic control** - Cannot clear, update, or read the field value programmatically
3. **Not dynamic** - Value only set once during widget creation
4. **Poor UX** - Inconsistent state management leads to frustrating user experience

## Solution (v1 - Initial Implementation)
Implemented `TextEditingController` following Flutter best practices.

## Solution (v2 - Review Feedback Applied) ✅

### Critical Issues Fixed:

#### 1. **Removed Controller Mutations in Build Methods**
**Problem**: Assigning `controller.text` inside `build()` causes cursor jumps.

**Before (❌):**
```dart
Widget _buildMainSetEntry() {
  // ⚠️ Mutating controller state in build - causes cursor jumps!
  if (_mainWeightController.text != _currentWeight.toString()) {
    _mainWeightController.text = _currentWeight.toString();
  }
  return TextFormField(controller: _mainWeightController);
}
```

**After (✅):**
```dart
void _loadLastSessionData() {
  setState(() {
    _currentWeight = lastSet.weight;
    _currentReps = lastSet.reps;
    // Initialize controllers ONCE in state loader
    _mainWeightController.text = _currentWeight.toString();
    _mainRepsController.text = _currentReps.toString();
  });
}

Widget _buildMainSetEntry() {
  // Build only READS, never mutates controller state
  return TextFormField(controller: _mainWeightController);
}
```

#### 2. **Removed setState During User Input**
**Problem**: Calling `setState` during text input can interrupt typing.

**Before (❌):**
```dart
onChanged: (val) {
  final parsed = double.tryParse(val);
  if (parsed != null) setState(() => _currentWeight = parsed); // ⚠️ Rebuilds during typing
}
```

**After (✅):**
```dart
onChanged: (val) {
  final parsed = double.tryParse(val);
  if (parsed != null) {
    _currentWeight = parsed;
    // Controller is the source of truth during input - no setState needed
  }
}
```

#### 3. **Removed Controller Creation in Build**
**Problem**: Creating controllers in `_buildDropEntry()` causes duplicate instances.

**Before (❌):**
```dart
Widget _buildDropEntry(int index) {
  // ⚠️ Creating controllers in build - memory leak and duplication!
  while (_dropWeightControllers.length <= index) {
    _dropWeightControllers.add(TextEditingController());
  }
  // ...
}
```

**After (✅):**
```dart
void _addDrop() {
  // Create controllers ONCE when adding drop
  _dropWeightControllers.add(TextEditingController(text: newWeight.toString()));
  _dropRepsControllers.add(TextEditingController(text: _currentReps.toString()));
}

Widget _buildDropEntry(int index) {
  // Build only READS from existing controllers
  return TextFormField(controller: _dropWeightControllers[index]);
}
```

#### 4. **Fixed Memory Leak in _completeSet**
**Problem**: When completing a dropset, controllers weren't disposed.

**Before (❌):**
```dart
void _completeSet() {
  setState(() {
    _isDropset = false;
    _drops.clear(); // ⚠️ Controllers still in memory - memory leak!
  });
}
```

**After (✅):**
```dart
void _completeSet() {
  setState(() {
    _isDropset = false;
    // Dispose all controllers before clearing
    for (var controller in _dropWeightControllers) {
      controller.dispose();
    }
    for (var controller in _dropRepsControllers) {
      controller.dispose();
    }
    _dropWeightControllers.clear();
    _dropRepsControllers.clear();
    _drops.clear();
  });
}
```

## Controller Lifecycle Best Practices

### ✅ DO:
1. **Initialize controllers in state methods** (`initState`, `_loadLastSessionData`)
2. **Create controllers with initial values**: `TextEditingController(text: '10')`
3. **Make controllers the source of truth during user input**
4. **Only READ from controllers in build methods**
5. **Dispose controllers in `dispose()` method**
6. **Dispose controllers when removing items dynamically**

### ❌ DON'T:
1. **Never mutate `controller.text` inside `build()` methods**
2. **Never create controllers inside `build()` methods**
3. **Don't call `setState` in `onChanged` during text input**
4. **Don't compare `controller.text` to state in build**
5. **Don't forget to dispose controllers**

## Benefits of TextEditingController

| Feature | `initialValue` | `TextEditingController` |
|---------|---------------|------------------------|
| **Dynamic Updates** | ❌ No | ✅ Yes |
| **Programmatic Access** | ❌ No | ✅ Yes (get/set/clear) |
| **Persists on Rebuild** | ❌ No | ✅ Yes |
| **Real-time Listening** | ❌ No | ✅ Yes (addListener) |
| **Cursor Stability** | ⚠️ Issues | ✅ Stable (when used correctly) |
| **Memory Management** | ✅ Automatic | ⚠️ Manual (dispose required) |

## Testing Recommendations
1. ✅ Test that text persists when screen rebuilds
2. ✅ Test cursor position doesn't jump while typing
3. ✅ Test adding/removing drops maintains correct values
4. ✅ Test toggling dropset mode properly cleans up
5. ✅ Test completing sets disposes controllers
6. ✅ Verify no memory leaks (use Flutter DevTools)
7. ✅ Test rapid typing doesn't lose characters
8. ✅ Test typing doesn't cause unnecessary rebuilds

## References
- [Flutter TextFormField Documentation](https://api.flutter.dev/flutter/material/TextFormField-class.html)
- [TextEditingController Best Practices](https://docs.flutter.dev/cookbook/forms/text-field-changes)
- [Memory Management in Flutter](https://docs.flutter.dev/testing/best-practices#dispose-of-resources)
- [Avoiding setState During Build](https://api.flutter.dev/flutter/widgets/State/setState.html)

---
**Date Applied**: 2026-01-24  
**Files Modified**: `lib/screens/workout_flow_screen.dart`  
**Impact**: Improved UX, better state management, no memory leaks, no cursor jumps  
**Review Feedback**: Applied all code review suggestions v2

