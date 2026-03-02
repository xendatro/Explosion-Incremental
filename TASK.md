# Task Creation Guide

## Purpose

This guide teaches you how to convert design documents into individual programming tasks for Roblox game development. Tasks are sent to programmers via Discord and must be **concise, clear, and actionable**.

**Target Audience:** Programmers familiar with the Services/Tags/Classes architecture (see README.md)

---

## Critical Requirements Before Writing Tasks

### 1. Understand the Architecture

Before creating ANY tasks, thoroughly read and understand:
- **README.md** - Services/Tags/Classes pattern, Tagger system, existing services
- **Design Doc** - All game systems and mechanics
- **Project structure** - ReplicatedStorage vs ServerStorage, Communication folder, etc.

**Key Architecture Points:**
- **Services**: Singleton modules (never instantiated). Use for utility functions and game-wide management.
- **Classes**: OOP modules with `.new()` constructor. Use for individual objects/entities.
- **Tags**: Use CollectionService + Tagger system for designer-placeable objects.
- **Existing Services**: DataSaveService, AudioService, BadgeService, TagService, ClickEffectService - DO NOT recreate these.

### 2. Ask Functional Questions

If the design doc is unclear about **HOW** something works (not specific values), ask before writing the task:

**Ask about:**
- "How does X interact with Y?"
- "What happens when a player does Z?"
- "Does this system need to persist data?"
- "Should this be client-side, server-side, or both?"

**DON'T ask about:**
- Specific item prices (unless it affects system design)
- Exact damage values (programmers will use configs)
- Color/size of UI elements (designers handle this)

**Critical Rule:** The infrastructure must be fully understood. Programmers should be able to implement ALL systems, not just "parts" of them.

---

## Task Ordering: Build Foundation First

Tasks must be ordered **logically** based on technical dependencies:

### Ordering Guidelines

1. **Core Infrastructure** (if not already built)
   - Data structures
   - Communication setup (RemoteEvents/Functions)
   - Shared utility services

2. **Foundation Systems**
   - Systems other systems depend on
   - Currency/economy if other systems use it
   - Player state management
   - Inventory systems

3. **Independent Game Systems**
   - Systems that don't depend on each other
   - Can be built in parallel by different programmers

4. **Integration Systems**
   - Systems that connect multiple other systems
   - UI that displays data from multiple sources
   - End-game/win conditions

5. **Polish & Secondary Features**
   - Effects, animations, audio
   - Optional mechanics
   - Quality-of-life features

### Example Ordering: Abandoned Building Game

```
1. DataSaveService Setup (currency persistence)
2. Artifact System (core collectible mechanic)
3. Quota System (depends on artifacts)
4. Enemy System (independent of artifacts/quota)
5. Map System (independent, but enemies spawn here)
6. Lobby System (ties everything together)
7. Rating System (evaluates completed missions)
8. Shop System (uses saved currency)
```

**Think:** "What needs to exist before I can build this system?"

---

## Task Structure

Each task represents **one system** (e.g., Shop System, Combat System, Quest System).

### Task Format

```
# [System Name] - Difficulty: [1-5]/5

## Overview
[1-2 sentences describing what this system does from the player perspective]

## Functionality Requirements

### [Subsystem/Feature 1]
- [How it works]
- [Player interactions]
- [Expected behavior]

### [Subsystem/Feature 2]
- [How it works]
- [Player interactions]
- [Expected behavior]

[Continue for all subsystems...]

## Edge Cases to Handle
- [Edge case 1 and how to handle it]
- [Edge case 2 and how to handle it]
- [Edge case 3 and how to handle it]

## Suggested Technical Outline

**Services:**
- `SystemNameService` (Server) - [Key methods: :MethodName(), :OtherMethod()]
- `SystemNameService` (Client) - [Key methods: :ClientMethod()]

**Classes:**
- `ClassName` (Location) - [Purpose, when instantiated]

**Communication:**
- RemoteEvent: `EventName` (Purpose)
- RemoteFunction: `FunctionName` (Purpose)

**Tags (if applicable):**
- "TagName" → `ClassName` (Where used)

**UI/Client Scripting:**
- [Button/element] should [do what]
- [Display] should show [what data]
- [Setting/config] for [what purpose]

**Configs:**
- `SystemConfig.luau` - [What values to expose]

## Testing Checklist
- [ ] [Test case 1]
- [ ] [Test case 2]
- [ ] [Edge case verification]
- [ ] [Multiplayer sync test if applicable]

## Notes
- [Any important warnings or gotchas]
- [Performance considerations if applicable]
- [Integration notes with other systems]
```

---

## Difficulty Rating Guide (1-5)

Use this scale to rate task difficulty:

**1 - Trivial**
- Simple service with 1-2 methods
- No complex logic or edge cases
- Minimal integration with other systems
- Example: AudioService wrapper, simple config module

**2 - Easy**
- Straightforward service or class
- Basic logic, few edge cases
- Light integration with existing systems
- Example: Badge award system, simple collectible class

**3 - Moderate**
- Multiple interconnected components
- Moderate complexity logic
- Some edge cases to handle
- Client-server communication required
- Example: Shop system, inventory management

**4 - Challenging**
- Complex system with many subsystems
- Significant edge cases and state management
- Tight integration with multiple other systems
- Client-server synchronization critical
- Example: Combat system, multiplayer lobby system

**5 - Expert**
- Highly complex architecture
- Many interdependent components
- Critical edge cases and race conditions
- Advanced state management or algorithms
- Example: Procedural generation system, complex AI system, networking-heavy systems

**Consider:**
- Number of services/classes needed
- Complexity of logic
- Edge cases and error handling
- Client-server sync requirements
- Integration with other systems

---

## Writing Guidelines

### Be Concise but Complete
- Tasks will be sent via **Discord** - keep them focused
- No rambling or unnecessary context
- Every sentence should provide actionable information
- Use bullet points and subheadings for clarity

### Focus on Functionality, Not Values
- Describe **how** systems work, not specific numbers
- "Items should have a price and description" ✅
- "Item #1 costs 500 coins and is a sword that does 25 damage" ❌

### Specify Behavior, Not Implementation Details
- Let programmers choose implementation within architecture constraints
- "Shop should display available items filtered by player level" ✅
- "Use a for loop to iterate through items table and check level >= requirement" ❌

### Reference Existing Systems
- "Use DataSaveService to persist player currency" ✅
- "Create a new data saving system for currency" ❌

### Call Out Integration Points
- Clearly state when systems need to communicate
- Mention what data needs to be passed between systems
- Note if events/signals are needed for other systems to listen to

---

## Example Task

Here's a complete example task following the format:

---

# Shop System - Difficulty: 3/5

## Overview
Players can purchase items using currency earned from missions. Shop is accessible in the lobby and displays items available based on player level and unlock status.

## Functionality Requirements

### Item Structure
- Each shop item has: name, description, price, unlock level requirement, unique ID
- Items can be marked as "unlocked" or "locked" based on progression
- Support for different item categories (weapons, equipment, cosmetics)

### Purchase Flow
1. Player browses shop and clicks an item
2. System checks: sufficient currency, meets level requirement, not already owned (if applicable)
3. If valid, deduct currency and grant item
4. Update UI to reflect purchase
5. If invalid, show error message explaining why

### Item Ownership Tracking
- Track which items each player owns
- Persist ownership data across sessions
- Support one-time purchases (can't buy twice) and consumables (can buy multiple)

### Client UI Display
- Display all items in shop with locked/unlocked visual states
- Show price, requirements, and whether player owns it
- Disable purchase button if requirements not met
- Real-time currency display that updates on purchase

## Edge Cases to Handle
- Player doesn't have enough currency → Show "Insufficient funds" message
- Player doesn't meet level requirement → Show "Requires level X" message
- Player already owns item (for one-time purchases) → Hide purchase button or show "Owned"
- Player attempts rapid double-purchase → Prevent duplicate transactions with debounce
- Purchase fails server-side → Refund not needed (purchase never processed), but inform client
- Data not loaded yet → Disable shop until DataSaveService profile is ready

## Suggested Technical Outline

**Services:**
- `ShopService` (Server) - Key methods: `:PurchaseItem(player, itemId)`, `:GetAvailableItems(player)`, `:CanPurchase(player, itemId)`
- `ShopService` (Client) - Key methods: `:RequestPurchase(itemId)`, `:RefreshDisplay()`

**Classes:**
- `ShopItem` (ReplicatedStorage/Classes) - Represents a single shop item with properties (name, price, level, etc.)

**Communication:**
- RemoteFunction: `PurchaseItem` (Client → Server: purchase request, returns success/error)
- RemoteEvent: `ShopDataUpdate` (Server → Client: sync shop state after purchase)

**Tags:**
- None (shop is UI-based, not world objects)

**UI/Client Scripting:**
- Shop open/close button should toggle shop UI
- Item buttons should call `ShopService:RequestPurchase(itemId)` on click
- Currency display should listen for purchase events and update
- Item cards should show: icon, name, description, price, level requirement
- Purchase confirmation modal (optional) for high-value items

**Configs:**
- `ShopConfig.luau` (ReplicatedStorage/Configs) - Array of all shop items with: id, name, description, price, unlockLevel, category, isConsumable

## Testing Checklist
- [ ] Purchase succeeds when requirements met and currency deducted
- [ ] Purchase fails gracefully when insufficient currency
- [ ] Purchase fails when level requirement not met
- [ ] Ownership persists across server rejoins
- [ ] UI updates correctly after successful purchase
- [ ] Cannot purchase one-time items multiple times
- [ ] Multiple players can purchase simultaneously without conflicts
- [ ] Shop UI displays correct locked/unlocked states
- [ ] Currency display updates in real-time

## Notes
- Use `DataSaveService` to persist player currency and owned items (add `Currency` and `OwnedItems` fields to profile template)
- Validate ALL purchases server-side (never trust client)
- Consider adding a purchase cooldown (0.5s) to prevent spam
- Shop UI will use XenterFace for page navigation (designer handles tags)
- Future expansion: Add item filtering by category, search functionality

---

## Validation Checklist Before Sending Tasks

Before sending tasks to programmers, verify:

- [ ] **Ordered logically** - Foundation systems before dependent systems
- [ ] **Architecture adherence** - Uses Services/Tags/Classes correctly
- [ ] **Existing systems referenced** - Doesn't recreate DataSaveService, etc.
- [ ] **Functionality is clear** - Programmer knows exactly what to build
- [ ] **Edge cases identified** - Common failure scenarios addressed
- [ ] **Technical outline provided** - Suggested services/classes/methods listed
- [ ] **Difficulty rated** - Accurate 1-5 rating for payment
- [ ] **Concise formatting** - Readable in Discord, no rambling
- [ ] **Integration points noted** - Clear how system connects to others
- [ ] **Testing criteria included** - Verification checklist present

---

## Common Mistakes to Avoid

### ❌ Don't Recreate Existing Systems
**Bad:** "Create a DataService that saves player currency"
**Good:** "Use DataSaveService to persist player currency (add Currency field to profile template)"

### ❌ Don't Over-Specify Implementation
**Bad:** "Use a dictionary with player UserId as keys to store a nested table of items with boolean values"
**Good:** "Track which items each player owns and persist across sessions"

### ❌ Don't Include Design Values
**Bad:** "Sword costs 500 coins, Armor costs 1200 coins, Potion costs 150 coins"
**Good:** "Each item has a price defined in ShopConfig"

### ❌ Don't Forget Client-Server Split
**Bad:** "Create ShopService with purchase method"
**Good:** "Create ShopService (Server) with :PurchaseItem() and ShopService (Client) with :RequestPurchase()"

### ❌ Don't Ignore Edge Cases
**Bad:** "Player clicks button and gets item"
**Good:** "Player clicks button → check currency/requirements → validate server-side → grant item or show error"

### ❌ Don't Write Novels
**Bad:** 3-page task with detailed explanations of every function parameter
**Good:** Concise task focusing on **what** needs to be built, letting programmer decide **how**

---

## Summary: Task Creation Process

1. **Read README.md and Design Doc thoroughly**
2. **Identify all systems** that need implementation
3. **Order systems logically** (foundation → dependent)
4. **For each system:**
   - Extract functionality from design doc
   - Identify edge cases
   - Suggest technical approach (services/classes)
   - Rate difficulty (1-5)
   - Write concise, actionable task
5. **Validate** task meets all guidelines
6. **Send to programmer** via Discord

**Remember:** Programmers are skilled and know the architecture. Give them clear requirements and trust them to implement within the established patterns. Focus on **what** to build and **why**, not **how** to code it.

---

*Use this guide as reference when converting any design document into implementation tasks.*
