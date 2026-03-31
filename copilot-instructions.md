# Copilot Instructions – Swift AppKit Project

## General Guidelines
- Use **Swift (latest stable)** with **AppKit**, not UIKit or SwiftUI unless explicitly required.
- Prefer **native AppKit patterns** and APIs over cross-platform abstractions.
- Keep code **clear, minimal, and maintainable**.
- Avoid unnecessary dependencies.

## Architecture
- Follow a **clean and modular structure**.
- Separate responsibilities clearly (UI, logic, data handling).
- Prefer **MVC or lightweight MVVM**, depending on context.
- Avoid massive view controllers.

## AppKit Best Practices
- Use `NSViewController` and `NSView` appropriately.
- Manage UI updates on the **main thread**.
- Use Auto Layout properly; avoid hardcoded frames when possible.
- Prefer programmatic UI unless Interface Builder is explicitly required.

## Naming Conventions
- Use **clear and descriptive names**.
- Follow Swift naming conventions:
  - `camelCase` for variables and functions
  - `PascalCase` for types
- Avoid abbreviations unless widely understood.

## Code Style
- Keep functions **small and focused**.
- Avoid deeply nested logic.
- Prefer `guard` for early exits.
- Use extensions to organize code logically.

## Comments Policy
- All comments must be written in **concise and clear English**.
- Add comments **only when the code is not immediately self-explanatory**.
- Avoid redundant comments that repeat the code.

### File Header Comment (Required)
Each file must start with a top-level comment describing its purpose and main responsibilities.

Example:
```swift
//
// This file manages the main window UI and user interactions.
// It handles layout setup, button actions, and data display.
//