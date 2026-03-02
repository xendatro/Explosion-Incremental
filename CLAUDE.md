# EXPLOSION INCREMENTAL
## Game Design Document
**Version 0.5 — Workers | February 2026**

---

## Table of Contents
1. [Game Overview](#1-game-overview)
2. [World Structure](#2-world-structure)
3. [Player Stats](#3-player-stats)
4. [Core Gameplay Loop](#4-core-gameplay-loop)
5. [Sprinting](#5-sprinting)
6. [Items](#6-items)
7. [Gems](#7-gems)
8. [Structures & Upgrades](#8-structures--upgrades)
9. [Workers](#9-workers)
10. [Multiplayer & Social](#10-multiplayer--social)
11. [Economy](#11-economy)
12. [Future Features](#12-future-features-post-launch)
13. [Technical Notes](#13-technical-notes)
14. [Open Questions & TODOs](#14-open-questions--todos)

---

## 1. Game Overview

Explosion Incremental is a multiplayer incremental game built in Roblox. Players spawn on personal plots, scavenge items from shared biomes, and bring them back to their Exploder. Explosions pay out **coins** and **gems**. Coins fund plot and player upgrades. Gems hire **Workers** — NPC passive income units that automate the scavenge-and-explode loop while the player is active or idle.

The design philosophy is **dopamine-first**. Every explosion is a mini-spectacle. Every Worker you add to your plot is visible progress. Upgrades are immediate and visible. The result is a game that rewards active play while building a satisfying base of automation.

| | |
|---|---|
| **Genre** | Multiplayer Incremental / Idle — Roblox platform |
| **Release Scope** | v0.1: Exploder, Gym, Biomes 1+, Coins, Gems, Workers |
| **Server Size** | Up to 6 players per server, one player per plot |
| **Platform** | Roblox — PC (keyboard) and Mobile (touch) supported from launch |

---

## 2. World Structure

### 2.1 Plots

Six plots are arranged side-by-side in a row. One plot belongs to exactly one player per server session. Plots contain all of a player's structures and serve as their base of operations. All progress persists across sessions via Roblox DataStore.

Each plot contains:

- **Exploder** — the central machine where the player manually detonates items
- **Fitness Area (Gym)** — players click here to train Strength
- **Upgrade Boards (×2)** — Plot Upgrader and Player Upgrader
- **Worker Board** — where players spend gems to hire new Workers
- **Worker Base** — where Worker NPCs idle between cycles
- **NPC Exploder** — separate exploder where Workers cash out their items
- **Portal** — visual gate Workers walk through to enter/leave the biome

> **Design note:** Players can see neighboring plots and observe each other's Workers cycling, creating organic soft competition.

### 2.2 Biomes

Biomes extend in the positive Z direction from the plot row. Each biome spans approximately 100 studs and is populated with randomly spawning items. Biomes are **shared** — all players scavenge from the same space and compete for item spawns in real time.

Items respawn after being picked up. Biomes are differentiated by item pool and weight tier — they are **not** associated with individual gem types.

| Biome | Item Weight Range | Access |
|---|---|---|
| Biome 1 | Light (1–5 kg for Common) | Available from spawn |
| Biome 2 | Medium | Buy Biome 1 wall (per-player) |
| Biome N+ | Heavier | Buy each preceding wall |

> **Note:** Biome wall purchases are **per-player** and do not affect other players.

---

## 3. Player Stats

| Stat | v0.1 Status | Description |
|---|---|---|
| **Strength** | Active | Maximum total weight the player can carry. Items with weight above remaining capacity cannot be picked up. Trained at the Gym. |
| **Carry Amount** | Active | Maximum number of items the player can carry simultaneously. Upgraded at the Player Upgrader board with coins. |
| **Sprint Speed** | Active | Movement speed while sprinting. Toggle Shift (PC) or dedicated mobile button. No stamina limit. Upgraded at the Player Upgrader board. |
| **Coins** | Active | Primary currency. Earned from manual explosions and Worker passive cycles. Spent on all stat upgrades, biome walls. |
| **Gems** | Active | Single-type secondary currency. Earned exclusively by manually exploding items (or via Robux). Spent on hiring Workers and upgrading them. |

---

## 4. Core Gameplay Loop

| # | Action |
|---|---|
| 1 | Player spawns on their plot with default stats. |
| 2 | Player toggles sprint and runs into the active biome. |
| 3 | Player scans biome for items. Rarity is visible via BillboardGui. |
| 4 | Player picks up items they are strong enough to carry (Strength ≥ item weight). Up to Carry Amount items held simultaneously. |
| 5 | Player sprints back to their plot and places items on the Exploder. |
| 6 | Player triggers detonation. Items processed FIFO — each explosion awards coins and gems. |
| 7 | Coins and gems counters update. |
| 8 | Player spends coins at the Upgrade Boards; spends gems at the Worker Board to hire or upgrade Workers. |
| 9 | Workers passively run their cycle — walk to biome, return with item, explode it for coins — while the player continues their own runs. |
| 10 | Optional: Player visits the Gym to click-train Strength or enable Autotrain. |

---

## 5. Sprinting

Sprint is a **toggle** mechanic with no stamina cost.

| Platform | Input |
|---|---|
| **PC** | Shift key toggles sprint on/off. |
| **Mobile** | Dedicated on-screen sprint button. |

Sprint Speed is upgraded at the Player Upgrader board. Carrying items does **not** reduce Sprint Speed — Strength is a binary carry gate, not a drag penalty.

---

## 6. Items

### 6.1 Item Properties

| Property | Description |
|---|---|
| **Name** | Display name shown in pickup prompt and BillboardGui. |
| **Model** | Roblox free marketplace model. |
| **Weight** | Rolled from `RarityItemWeights[rarity]` on spawn. Player must have remaining Strength capacity ≥ Weight to pick it up. |
| **Rarity** | Common, Uncommon, Rare, Epic, Legendary, Mythic, Exotic. Affects coin payout, gem payout, and weight range. |
| **Biome** | Which biome this item spawns in. No gem-type coupling. |
| **Base Coin Value** | Base coin payout before multipliers. |
| **Base Gem Value** | Base gem quantity before rarity multiplier. |
| **Variant** | Optional: Radioactive, Poison, Electric. Multiplies payout. Deferred to post-launch. |

### 6.2 Carry Amount

Players can carry multiple items simultaneously, up to their **Carry Amount** stat. All held items are stacked visually above the player's head. Combined weight must not exceed Strength.

> **Example:** Strength = 10, Carry Amount = 3. Player picks up a weight-4 item (remaining: 6) and a weight-3 item (remaining: 3). Cannot pick up a third item weighing more than 3.

### 6.3 Item Weight by Rarity

Item weight is determined by rarity at spawn (from `ItemSpawnConfig.RarityItemWeights`), not per-item. Rarer items are heavier, requiring more Strength to carry them.

| Rarity | Weight Range (kg) |
|---|---|
| Common | 1 – 5 |
| Uncommon | 10 – 30 |
| Rare | 50 – 150 |
| Epic | 200 – 600 |
| Legendary | 1,000 – 3,000 |
| Mythic | 5,000 – 15,000 |
| Exotic | 25,000 – 75,000 |

### 6.4 Item Spawning

Items spawn randomly in the biome. When consumed, a replacement respawns after `RespawnDelay` at a random location in the same biome. Uncollected items despawn after `GroundDespawnTime` and respawn immediately.

### 6.5 Payout on Explosion

**Coins:**
```
Coin Payout = Base Coin Value × RarityMultiplier × ExploderLevelBonus
```

**Gems:**
```
Gem Payout = floor(BaseGemValue × RarityGemMultiplier[rarity])
```

- `BaseGemValue` is defined per item in `ItemConfig`
- `RarityGemMultiplier` scales gem payout by rarity (defined in `GemConfig`)
- All items award a single generic gem type regardless of biome

Draft `RarityGemMultiplier` values (to be tuned):

| Rarity | Gem Multiplier |
|---|---|
| Common | 1.0× |
| Uncommon | 1.5× |
| Rare | 2.5× |
| Epic | 5.0× |
| Legendary | 10.0× |
| Mythic | 25.0× |
| Exotic | 75.0× |

---

## 7. Gems

### 7.1 Overview

Gems are a **single-type** secondary currency. There is no per-biome gem — all explosions yield the same generic Gem. Gems are earned **only** by manually exploding items (or via optional Robux purchase). Workers do not produce gems.

### 7.2 Spending Gems

Gems are spent on two things:
1. **Hiring Workers** — purchasing a new Worker NPC. The cost scales up with each additional Worker (see Section 9).
2. **Upgrading Workers** — spending gems to improve an individual Worker's Speed (shorter cycle time) or Weight (more coins per cycle).

### 7.3 Design Intent

Gems create the core long-term tension: active manual play is required to hire more Workers and keep them upgraded. A player who stops exploding will fall behind on both hiring and upgrades. The visible NPC activity on your plot — Workers walking in and out of the portal — gives satisfying feedback that your progression is working.

---

## 8. Structures & Upgrades

### 8.1 Exploder

The central machine on each plot. Players place their entire carry stack via `PlacePrompt`, then detonate via `DetonatePrompt`. Items are processed FIFO from the bottom up — each consumed item causes the remaining stack to fall down one slot.

The `PlacePrompt` is only enabled while the plot owner is holding items. The `DetonatePrompt` is only enabled when items are queued and the owner is not holding anything. A Panel display shows current queue weight and estimated coin value.

Upgrading increases the Exploder Level Bonus multiplier and unlocks more dramatic visual/audio explosion tiers.

### 8.2 Fitness Area (Gym)

Physical structure on the plot. Player must be inside the Gym **Zone** part to train.

| Mode | Description |
|---|---|
| **Manual Click-Train** | Each click adds Strength directly. Gain = GymLevel multiplier. |
| **Autotrain** | Toggled at the Gym. Auto-fires training ticks at a set interval. Cancels automatically when player leaves the Zone or picks up an item. |

Gym level is upgraded at the Plot Upgrader board. Higher Gym level = larger Strength increment per click.

### 8.3 Plot Upgrader Board

SurfaceGui board. Upgrades:

- **Exploder Level** — increases coin payout multiplier
- **Gym Level** — increases Strength gain per click

### 8.4 Player Upgrader Board

SurfaceGui board. Upgrades:

- **Sprint Speed Level** — increases WalkSpeed
- **Carry Amount Level** — increases max items carried simultaneously

Also displays current **Strength** as a read-only label.

### 8.5 Worker Board

A dedicated board on each player's plot where they spend gems to hire new Workers. Displays current Worker count and the gem cost for the next hire.

Workers do not need physical slot licenses — the player simply hires as many as they can afford (each successive Worker costs more gems). Workers are permanently owned; they cannot be sold or removed.

### 8.6 Biome Walls

Per-player walls between biomes. Cost scales per wall. Purchasing opens that biome for that player only.

---

## 9. Workers

### 9.1 Overview

Workers are **NPC passive income units** that automate the scavenge-and-explode loop. Unlike the player's manual loop, Workers produce **coins only** — no gems. There is no rarity, no gacha, no inventory management. You simply hire them and upgrade them.

Workers are the primary motivation for sustained active play: the more you manually explode, the more gems you earn, and the more Workers you can hire and upgrade.

### 9.2 Hiring

Workers are purchased at the **Worker Board** on the player's plot. The gem cost scales with each purchase:

```
cost(N) = ceil(BasePurchaseCost × PurchasePriceScale^(N-1))
```

Where N is the Nth worker being purchased. There is no maximum — players can hire as many Workers as they can afford.

### 9.3 The Cycle

Each Worker independently runs a repeating cycle:

1. Worker idles at the **Worker Base**
2. Worker walks through the **Portal** into the biome (visual)
3. Worker is away for `BaseInterval × SpeedDecayRate^SpeedLevel` seconds
4. Worker returns through the Portal carrying an item (visual)
5. Worker walks to the **NPC Exploder** and detonates
6. Player receives `floor(BaseCoins × WeightBase^WeightLevel)` coins
7. Worker returns to idle — cycle repeats

### 9.4 Per-Worker Upgrades

Each Worker has two independent upgrade tracks, paid in gems:

| Upgrade | Effect | Formula |
|---|---|---|
| **Weight** | More coins per cycle | `floor(BaseCoins × WeightBase^WeightLevel)` |
| **Speed** | Shorter cycle interval | `BaseInterval × SpeedDecayRate^SpeedLevel` |

Upgrade costs scale per level:
```
speedCost(L)  = ceil(SpeedBaseCost  × SpeedPriceScale^L)
weightCost(L) = ceil(WeightBaseCost × WeightPriceScale^L)
```

Upgrades apply immediately on the next cycle — no restart needed.

### 9.5 Output

Workers produce **coins only**. Gems are exclusively a product of manual play.

### 9.6 Design Note

Workers are intentionally lower coin-per-hour than active manual play at equivalent progression. Their value is passive accumulation while the player is doing other things (gym training, biome runs, AFK). Watching your Workers cycle — seeing them walk out, return with an item, and explode it at the NPC Exploder — provides satisfying visual feedback that your investment is working. The NPC activity on your plot is organic social proof to neighboring players that you've invested in automation.

---

## 10. Multiplayer & Social

### 10.1 Server Layout

All 6 players share the same biome space. They can see each other scavenging, watch neighboring explosions, and observe each other's plots.

### 10.2 Item Competition

Shared biome with respawning items. Sprint Speed determines who reaches good items first. Strength (and Carry Amount) determines what and how much they can take per trip.

### 10.3 Social Feel

Explosion cutscenes are visible to neighboring players (in-world VortexFX effect). A player with many active Workers has visible NPC activity on their plot — Workers walking in and out of the portal, exploding at the NPC Exploder — which signals investment and progression to neighbors.

### 10.4 Future: Friend Bonus

A future update will reward Roblox friends sharing a server — potential forms include a small coin multiplier, shared biome events, or bonus gem drop rates.

### 10.5 Future: Competitive Mechanics

Leaderboards, timed challenges, and competitive events deferred to post-launch.

---

## 11. Economy

### 11.1 Coins

Earned from: manual explosions, Worker passive cycles.
Spent on: Exploder upgrades, Gym upgrades, Sprint Speed upgrades, Carry Amount upgrades, biome walls.

Coins are the stat/progression currency. They make the player personally more capable and open the world.

### 11.2 Gems

Earned from: manual explosions only (single generic type). Every explosion yields gems.
Spent on: hiring Workers (cost scales per Worker), upgrading individual Workers (Speed and Weight tracks).

Gems are the Worker acquisition and upgrade currency. Sustained active play is required to keep hiring new Workers and improving existing ones. The gem cost to hire each successive Worker ensures there's always a meaningful gem sink regardless of how many Workers you already have.

> **Balance note:** Gem quantities and Worker costs must be tuned so a new player can afford their first Worker within a reasonable session, while having a large workforce requires sustained investment.

---

## 12. Future Features (Post-Launch)

### Friend Bonus
Passive benefit for Roblox friends sharing a server. Mechanic TBD.

### Competitive Features
Leaderboards, timed challenges, server-wide events, direct competitive mechanics.

### Additional Biomes
New biomes with themed visuals and new item pools. Biome count scales with content updates.

### Gym Visual Progression
Gym model visually expands at level milestones — adding racks/equipment to signal progress.

### Worker Visual Diversity
Distinct NPC appearance or animations per upgrade tier (e.g. a visually beefier Worker at high Weight level). Art-team driven.

### Prestige System
Reset progress for permanent multipliers or cosmetic rewards.

---

## 13. Technical Notes

### ⚠ EternityNum Rule — MANDATORY

Any value that can grow without bound **must** use `EternityNum` (`ReplicatedStorage/Classes/EternityNum`).

| Rule | Detail |
|---|---|
| **Big stats** | `Coins` and `Strength` are EternityNum. Gems will become EternityNum when implemented. |
| **Storage** | Big stats are persisted as EN strings (`"Layer;Exp"`) in DataStore, not raw numbers. |
| **Arithmetic** | Use `EN.add / EN.sub / EN.mul / EN.div`. Plain `+ - * /` operators do not work on EN tables. |
| **Comparisons** | Use `EN.le / EN.me / EN.leeq / EN.meeq / EN.eq`. Plain `< > ==` operators do not work on EN tables. |
| **Display** | Always use `EN.short(value)` for any big-stat display — never `tostring` on an EN table. For values below 1000, floor before display to avoid decimals. |
| **Input conversion** | `EN.convert(x)` accepts plain numbers, `"XeY"` strings, `"Layer;Exp"` strings, or EN tables. |
| **Passing to EN functions** | All EN arithmetic functions call `EN.convert` internally, so a plain Lua number delta (e.g. `EN.add(enCoins, 100)`) is safe. |

`PlayerStatsService` (both server and client) enforces this automatically for `Coins` and `Strength` via `BIG_STATS`. When adding a new big stat: add it to `BIG_STATS` in both services and update the DataStore template default to `"0;0"`.

---

### 13.1 ClickEffectService
Auto-initializes. Fires 2D particles on every click. Used by the Gym for manual training feedback.

### 13.2 Explosion Cutscene
Triggered by player detonating their Exploder. Client creates a local clone of the item for animation (drops, shakes, explodes). At the BOOM frame, client fires `CutsceneBoomReady` to server. Server awards coins and gems, fires VortexFX in-world. Scale of effects should reflect item rarity.

### 13.3 Gem Drops
Gems are a single generic type. On detonation, the server calculates `floor(BaseGemValue × RarityGemMultiplier[rarity])` and awards them directly to the player. Physical gem scatter effect (models scattering from the Exploder) is a visual flourish; the actual credit is server-authoritative and instant.

### 13.4 Item Carry Stack
Multiple items stack vertically above HumanoidRootPart. Each additional item is offset upward by the height of the item below it.

### 13.5 DataStore Schema
Fields persisted per player:
- `Coins` (EN string `"Layer;Exp"`), `Strength` (EN string), `ExploderLevel`, `GymLevel`, `SprintSpeedLevel`, `CarryAmountLevel`, `MaxBiomeUnlocked`
- `Gems` — single integer (becomes EN string when implemented)
- `Workers` — array of worker entries; each entry: `{ WeightLevel: number, SpeedLevel: number }`. Index = worker ID. Workers are never removed.

### 13.6 ⚠ Board Architecture Rule — MANDATORY

Plot boards (upgrade boards, worker board, biome wall board, any future board) **must** use the Tagger + Class pattern. **Never** wire boards via `PlotAssigned` remote event.

| Rule | Detail |
|---|---|
| **Instantiation** | Each board tag gets a `TagService:Listen` call in its class module. The class constructor handles everything. |
| **Ownership check** | Constructor yields until `AssignedPlotName` attribute is set, then checks `board:IsDescendantOf(plot)`. Returns nil if not the player's board. |
| **GUI setup** | `BoardBase.new(boardModel, "GuiTemplateName")` clones the SurfaceGui from `RS.Props.UI`, sets `Adornee = board.Main`, parents to `PlayerGui`. |
| **Element lookup** | Always use `xenterface:Get(elementId)`. Never use `FindFirstChild` recursive search on the GUI. Elements are in `PlayerGui`, so xenterface finds them. |
| **No PlotAssigned wiring** | Using `PlotAssigned.OnClientEvent` for boards creates race conditions and duplicate GUIs. The Tagger pattern is self-contained and correct. |

Current board classes: `UpgradeBoardClass` (tag `UpgradeBoard`, BoardType attribute `"Plot"` or `"Player"`), `BiomeWallBoardClass` (tag `BiomeWallBoard`), `WorkerBoardClass` (tag `WorkerBoard`). Base: `BoardBase`.

### 13.7 Mobile Support
- Sprint toggle (not hold)
- Proximity prompts sized for touch
- Gym tap registration via ClickEffectService
- Autotrain valuable for mobile players

---

## 14. Open Questions & TODOs

| # | Question / TODO | Priority |
|---|---|---|
| 1 | Define coin payout values and rarity multipliers. | High |
| 2 | Define Gym upgrade levels and Strength gains per level. | High |
| 3 | Define Exploder upgrade levels and payout bonuses. | High |
| 4 | Define Sprint Speed upgrade levels and WalkSpeed per level. | Medium |
| 5 | Define Carry Amount upgrade levels and item count per level. | Medium |
| 6 | Define biome wall costs and how many biomes ship at launch. | Medium |
| 7 | Define `BaseGemValue` per item in ItemConfig and `RarityGemMultiplier` table in GemConfig. | High |
| 8 | Tune WorkerConfig values — BasePurchaseCost, PurchasePriceScale, BaseInterval, BaseCoins, upgrade costs. | High |
| 9 | Design explosion cutscene — item drop animation, camera, timing. | High |
| 10 | Decide gem collection mechanic — instant credit, auto-collect on touch, or float to player. | Medium |
| 11 | Determine item respawn delay and max concurrent items per biome. | Medium |
| 12 | Design Worker NPC visual loop (client) — walk-out animation, item-carry animation, NPC Exploder sequence. | High — requires art |
| 13 | Decide Worker upgrade UI format — ScreenGui panel per worker vs. SurfaceGui on a board. | Medium |
| 14 | Curate item pools for Biomes 1 and 2 from free model marketplace. | Medium |
| 15 | Confirm gamepass plan — any premium features beyond gem purchases? | Low — post-launch |
| 16 | Design Worker NPC model — single design or upgradeable visual tiers at high upgrade levels? | High — requires art |

---

*End of Document — Explosion Incremental GDD v0.5*
