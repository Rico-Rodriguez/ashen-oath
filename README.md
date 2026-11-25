# Ashen Oath

Ashen Oath is a dark-medieval portrait pocket ARPG built in Godot 4.7.2. You choose one of three knight classes in the Barrow Sanctum, forge four-slot equipment kits, and fight north through four Barrow Lands expeditions to slay each zone's Guardian Boss.

The game has no ads, no real-time chest timers, and no paid currencies.

## Classes and kits

Each class uses a distinct 3D knight rig, primary weapon family, offhand or relic slot, two active abilities, and an invulnerability dash:

| Class | ID | Allowed weapons | Active skills | Dash |
| --- | --- | --- | --- | --- |
| Oathbreaker Knight | `oathbreaker` | Greatsword, Halberd, Sword and Shield | Iron Tempest, Bulwark Charge | Iron Roll |
| Ashen Battlemage | `battlemage` | War Staff, Sword and Shield | Blackflame Pyre, Stormbrand Arc | Phase Blink |
| Dread Revenant | `revenant` | Halberd, Greatsword, Sword and Shield | Reaping Sweep, Wraith Lances | Shadow Step |

Equipment spans four slots (`WEAPON`, `HELM`, `CUIRASS`, `RELIC`) across four visual armor tiers (`Worn Iron`, `Blackened Steel`, `Sovereign Plate`, and `Ashen Barrows`) and four rarities (`Common`, `Rare`, `Epic`, `Relic`). All eight item affixes wire directly into `CombatStats` and live combat resolution.

## Expeditions and guardians

Each run spans three monster clearings, a mid-run Dark Shrine offering three run-scoped covenants, a warded boss gate, and a Guardian Boss arena across three difficulty tiers (`Normal`, `Veteran`, `Nightmare`):

| Zone | ID | Guardian Boss |
| --- | --- | --- |
| Barrow Fringe | `fringe` | Gravemaw, Barrow Troll |
| Blighted Weald | `weald` | Nightmaw, Blight Stalker |
| Sovereign Catacombs | `catacombs` | Obsidian Warden |
| Ashen Rift | `rift` | Khorvath, Ashen Bull |

Each Guardian Boss transitions into an Enrage phase at 55 percent HP with faster windups and expanded attack patterns. Slain foes and bosses drop Gold and physical `LootDrop3D` relics directly onto the arena floor. Unwanted gear salvages into `Scrap` in the Armory or funds targeted crafting in the Forge.

Progress saves locally to `user://ashen_oath_save.json`.

## Controls

- Move with `WASD`, arrow keys, or the lower-left virtual thumbstick. Your hero attacks nearby foes while moving without locking movement.
- Cast Skill 1 with `Q` or `1`.
- Cast Skill 2 with `E` or `2`.
- Dash through telegraphed attacks with `Space` or `Shift`.
- Pause with `Escape`.

## Run and verify

Launch the game in Godot 4.7.2 with Forward+:

```powershell
godot --path .
```

Run the headless domain, loot, save, and boss kit test suite:

```powershell
godot --headless --path . --script res://tests/run_all_tests.gd
```

Run the headless 3D physics combat slice test suite:

```powershell
godot --headless --path . --script res://tests/test_combat_slice.gd
```

Run the 720x1280 Forward+ UI end-to-end check and screenshot exporter:

```powershell
godot --windowed --resolution 720x1280 --position -2000,-2000 --path . --script res://tools/verify_phase4_ui.gd
```

Run the uncapped Forward+ 21-enemy plus Guardian Boss GPU stress benchmark:

```powershell
godot --windowed --resolution 720x1280 --position -2000,-2000 --vsync-mode disabled --path . --script res://tests/benchmark_perf.gd
```

## Asset forge pipeline

Procedural dark-medieval weapons and rig attachments (`zweihander.glb`, `halberd.glb`, `runed_staff.glb`, `cloak_tattered.glb`, `helm_plume.glb`, and `waist_lantern.glb`) build deterministically in headless Blender:

```powershell
blender --background --python tools/forge_attachments.py
```

Synthesize the dragging-blade stone scrape sound effects (`blade_scrape_1.ogg` and `blade_scrape_2.ogg`):

```powershell
python tools/build_blade_scrape_sfx.py
```

Re-bake the 3D hero, enemy, and equipment UI portraits and icons:

```powershell
godot --windowed --resolution 720x1280 --position -2000,-2000 --path . --script res://tools/bake_ui_icons.gd
```

## Project layout

- `scenes/ui/` holds `dark_theme.tres`, `main_shell.tscn`, `sanctuary_stage_3d.tscn`, `hunt_tab.tscn`, `armory_tab.tscn`, `forge_tab.tscn`, `combat_hud.tscn`, and `settings_modal.tscn`.
- `scenes/actors/` holds the three hero `.tscn` prefabs and eight dark-fantasy enemy `.tscn` prefabs.
- `scenes/combat/arena_run.tscn` hosts `CombatDirector` for 3D expedition runs.
- `scripts/data/` defines typed domain schemas (`GameEnums`, `WeaponDef`, `AffixRoll`, `EquipmentItem`, `CombatStats`, `AbilityDef`, `HeroClassDef`, `EnemyDef`, `ZoneDef`, `ShrineBlessingDef`, and `GameRegistry`).
- `scripts/items/loot_engine.gd` implements deterministic loot generation, salvage, and forge crafting.
- `scripts/core/game_state.gd` owns persistent progression, loadouts, inventory, and settings.
- `scripts/actors/` owns `ActorVisual` and `HeroRigDresser` socket mounting and material overrides.
- `scripts/vfx/` and `shaders/` implement 4-tier `armor_forge.gdshader` PBR armor, `cloak_sway.gdshader`, `BladeScrapeVfx`, `WeaponRibbon3D`, `vfx_smokey_flame.gdshader`, `LightningArc3D`, and `VfxTelegraph3D`.
- `scripts/combat/` implements `BarrowArenaBuilder`, `HeroController3D`, `EnemyController3D`, `CombatProjectile`, `DarkShrine3D`, `LootDrop3D`, and `CombatDirector`.
- `tests/` and `tools/` hold the automated test suites, Forward+ visual verifiers, GPU benchmark, and asset generators.

Third-party asset licenses live in `CREDITS.md`.

## iOS sideload and OTA

Every push to `main` runs `.github/workflows/ios-ipa.yml` on `macos-26` to verify `tests/run_all_tests.gd`, export the iOS Xcode project, package an unsigned IPA, and publish both GitHub prereleases:

- Add the AltStore or SideStore source once on your device: `https://github.com/Rico-Rodriguez/ashen-oath/releases/download/ota/altstore.json`
- Direct unsigned IPA download (`com.rico.ashenoath`): `https://github.com/Rico-Rodriguez/ashen-oath/releases/download/ios-v1/AshenOath.ipa`
- In-game OTA bootstrap (`scripts/ota_boot.gd`) checks `https://github.com/Rico-Rodriguez/ashen-oath/releases/download/ota/version.json` on iOS launch and applies verified `ashen_oath.pck` updates automatically.

