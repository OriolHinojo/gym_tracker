# 💪 IronPulse — Design & Requirements (Flutter • Dart • Offline)

> A gym tracker that’s laser-focused on **progress**, not just logging. Fully offline. Production-grade Flutter & Dart practices with clear structure, metrics, and delightful UX.

---

## 1) 🎯 Product Vision

**IronPulse** helps lifters track workouts with **variable sets/reps/weights**, understand **progress over time**, and see **set-by-set strength trends**. It’s **offline-first** (no internet, no cloud), fast, and transparent about how metrics are computed.

---

## 2) 🧭 Information Architecture (Bottom Nav)

* **Home** — dashboard pulse & quick start
* **Log** — start/continue a workout; frictionless set entry
* **Progress** — metrics & charts (e1RM, rep-specific, per-set strength)
* **Library** — exercises & templates
* **More** — settings, units, export/import, privacy

---

## 3) 🖥️ Screens & Interactions

### 3.1 Home (Dashboard)

**Purpose:** quick pulse of progress and a fast path into logging.

**Top summary cards**

* **This Week**: sessions, volume load (kg), avg intensity (% e1RM), time trained.
* **Trend (7–28d)**: up/down arrows for volume, e1RM*, best set power**.
* **Last Session**: exercises done, PR badges, “Resume draft” if unfinished.

**Widgets**

* **Highlights**: “e1RM +2.5 kg on Bench”, “New 5RM PR on Squat”.
* **Upcoming** (optional): next planned workout (from templates).
* **FAB**: Quick Start → Empty Workout | Use Template.

* e1RM = estimated 1RM (Epley/Brzycki selectable).
** If/when bar-speed exists; hidden otherwise.

---

### 3.2 Log (Workout)

**Purpose:** frictionless logging with variable sets/reps/weights and live feedback.

**Header**

* Workout name + date
* Session timer • per-exercise rest timer
* Save / Finish

**Exercise list**

* Reorderable, collapsible blocks.

**Exercise block**

* Title + muscle tag + last-time preview (best set, e1RM, volume)
* Actions: **+ Add Set**, **+ Superset** (later), **History**, **Plate Calc**

**Set table (per exercise)**

* `#` set index (editable, 1-based)
* **Weight** (kg/lb toggle, decimal)
* **Reps** (numeric, variable per set)
* **RPE/RIR** (optional)
* **Notes** (per set)
* **☑︎** Completed
* **Smart fill** row suggests next set from last completed set; always override-able.

**Auto-math chips**

* Best set today (by e1RM or weight×reps heuristic)
* Volume today (Σ weight×reps)
* “Match last workout” shortcut

**Quick actions**

* Duplicate / Delete set
* Rest-pause or Drop set (sub-rows with their own reps/weight)
* Convert set type: straight / AMRAP / top-set + back-offs

**History bottom sheet**

* Last 5 sessions: date • best set • total sets • volume • tiny e1RM sparkline
* “Use exact from [date]” → paste targets

**Rest timer**

* Auto-starts when you tick a set complete
* Controls: pause • +30s • reset • haptic at 0:00

**Micro-UX**

* One-hand number pad, “Next” jumps Weight → Reps → RPE/RIR
* Undo/Redo for edits within workout

---

### 3.3 Progress (Metrics)

**Purpose:** the progress lens you asked for: averages across sets, last-rep filtering, and set-index trends.

**Filters (persistent bar)**

* Exercise (multi-select) • Date range • Unit • Set Type (straight/back-off/top)
* **Rep filter modes:**

  * **Average across all sets** (true mean of weight, reps, e1RM, volume)
  * **Filter by last repetition** (strict: reps == X; or targeted: treat Xth rep via formula)
* **Set index filter**: compare Set #1 vs #N across time
* Secondary: equipment, variation tags, RPE range

**Tabs**

1. **Overview**
   e1RM trend • Volume load trend • Avg intensity (% e1RM) • Best set progression
2. **Per-Set Strength**
   Chart: **Set Index vs Performance** (avg e1RM / weight / reps)
   Insight: “Set 1 is +2.1% vs Set 3 (n=42)”
3. **Rep-Specific**
   Choose reps (e.g., 5): **weight@5** over time (strict vs targeted)
4. **Distribution**
   Histograms: reps per set • intensity buckets • RPE spread
5. **PRs**
   Lifetime PRs by rep (1–10), best e1RM, streaks

**Metric definitions (in an info sheet)**

* **Volume** = Σ(weight × reps) per exercise/day
* **Intensity** = avg(weight / day_e1RM) as % (or vs lifetime e1RM)
* **e1RM**: Epley (w×(1+reps/30)) or Brzycki (w×36/(37−reps))
* **Per-set strength**: group by `set_index`, mean metric, deltas vs Set 1

---

### 3.4 Library (Exercises & Templates)

**Exercises**

* Search, categories, equipment filters

**Exercise detail**

* Name, tags, notes
* Mini trends: e1RM, best set, weekly volume
* Last 10 sessions table; tap to open workout
* **Auto-progression settings** (rule, step, microplates)
* Variation linkage (e.g., High-bar vs Low-bar)

**Templates (optional)**

* Create templates with target sets/reps/RPE; on start, paste targets but user logs actuals

---

### 3.5 More (Settings & Data)

* Units (kg/lb), default e1RM formula, default charts
* Data: **export CSV/JSON**, **import JSON** (local only)
* Privacy lock (Face/Touch ID)
* Integrations: none online; future placeholders hidden

---

## 4) 🧪 Key Micro-Flows

* **Start workout** → Template or empty → Add exercises → Log sets (variable) → Finish → Summary (volume, best set, PRs).
* **Set variants**: “⋯” → drop set (auto %), rest-pause (timestamped)
* **Undo/Redo** while logging
* **Offline-first**: everything local; import/export via files

---

## 5) 🗃️ Data Model (Drift / SQLite)

> Optimized for variable set data, rep-specific analytics, and set-index trends.

**Tables**

* **exercises**
  `id (uuid)`, `name (unique)`, `equipment (enum)`, `primary_muscles (json)`,
  `variation_tags (json)`, `notes`, `aggregation_key`,
  `progression_rule (enum: rir|rpe|simple)`, `increment_step (real, default 2.5)`,
  `microplates (json [0.5,1.25,2.5])`, `created_at`, `updated_at`
* **workouts**
  `id`, `started_at`, `finished_at?`, `name?`, `notes?`
* **exercise_instances**
  `id`, `workout_id`, `exercise_id`, `order_index`, `rest_seconds_default?`
* **sets**
  `id`, `exercise_instance_id`, `set_index (1-based)`,
  `weight (real)`, `reps (int)`, `rpe? (real)`, `rir? (real)`,
  `rep_target? (int)`, `hit_target? (bool)`, `felt_flag? (hard|good|easy)`,
  `is_dropset_parent (bool)`, `parent_set_id?`, `tempo?`, `completed_at?`, `notes?`
* **prs_cache** (derived, cached)
  `id`, `exercise_id`, `pr_type (1rm|5rm|e1rm_best|weight_at_rep)`, `rep_count?`, `value`, `at_date`
* **next_targets** (derived)
  `id`, `exercise_id`, `suggested_weight`, `suggested_reps`, `reason`, `created_at`

**Indexes**

* `exercises(name NOCASE)` • `sets(exercise_instance_id)` • `sets(set_index)` • `prs_cache(exercise_id, pr_type)`

**Why `set_index` matters**
It powers the **Per-Set Strength** analysis. Keep it stable within a session; renumber on save if sets removed, but you may store an `original_index` if you want deeper analytics later.

---

## 6) 🧮 Calculations

**Average across sets & reps (Overview)**

* `avg_weight = mean(all sets.weight)`, `avg_reps`, `avg_e1RM`
* Option: weight means by reps (config)

**Filter at last repetition (Rep-Specific)**

* **Strict**: include sets where `reps == target_rep` → chart `weight` over time
* **Targeted**: for sets with `reps ≥ target_rep`, compute weight@target via e1RM inversion (formula-based), make this explicit

**Per-set strength (Set Index)**

* Group by `set_index` across sessions; compute mean metric (e1RM/weight)
* Show delta vs Set 1 and sample size `n`

**PR detection**

* Track 1–10RM, best e1RM; cache in `prs_cache`

**Formulas**

* **Epley**: `e1RM = w * (1 + r/30)`
* **Brzycki**: `e1RM = w * 36 / (37 - r)`

---

## 7) 🤝 Auto-Progression (It felt easy → increase next time)

**Signals per set**

* `rpe` **or** `rir` (global preference)
* `rep_target?`, `hit_target?`
* `felt_flag?` (hard/good/easy)

**Rules**

* **RIR**: RIR ≥ 3 & reps ≥ target → **increase**; RIR ≤ 1 & reps < target → **decrease**; else **keep**
* **RPE**: RPE ≤ 7 at/above target → **increase**; RPE ≥ 9 → **decrease**
* **No RPE/RIR**: reps ≥ target+2 → **increase**; reps < target → **decrease**
* **Guardrails**: max ±5% (config per exercise), round to supported **microplates**
* **Consecutive increases**: allow a third only if previous two ended ≤ RPE 8 (or RIR ≥ 2)
* **Deload week** toggle disables increases

**Outputs**

* `NextTarget { exercise_id, suggested_weight, suggested_reps, reason }` stored on finish, or updated if user accepts during workout

**UI surfacing**

* Log: chip under exercise title → “Last time easy → +2.5 kg?” [Apply] [Keep]
* After exercise: snackbar “Next time +2.5 kg (RIR 3)”
* Start via template/history: blue suggestion chips; accept/override
* Exercise Detail: rule/step/microplates settings

---

## 8) 🧱 Tech Stack & Architecture

**Flutter/Dart**

* Flutter stable, Dart 3.x, null-safety, hot reload friendly

**Key Packages (no network)**

* State: `riverpod` + `flutter_riverpod`
* DB: `drift` + `drift_sqflite` + `path_provider`
* Models: `freezed`, `freezed_annotation`, `json_annotation`, `collection`
* Charts: `fl_chart`
* Dates: `intl`
* Files: `file_picker`, `share_plus`
* Navigation: `go_router` (optional but recommended)

**Project Structure**

```
lib/
  app.dart
  router.dart
  theme/
  features/
    home/
    log/
    progress/
    library/
    more/
  data/
    db/         // drift tables & DAOs
    repos/      // repositories (business logic over DAOs)
  services/
    metrics/    // MetricsService
    suggest/    // SuggestionEngine
  widgets/      // shared UI
test/
```

**Architecture**

* UI (Widgets) ↔ Riverpod Providers ↔ **Repositories** ↔ **DAOs (Drift)**
* **Services** (pure Dart): MetricsService & SuggestionEngine
* Streams for live updates (current workout, today’s volume)

**Platform constraints**

* No internet permission in AndroidManifest; no network calls anywhere.

---

## 9) 🧰 Add Exercise & Library UX

**Where**

* Log → **+ Add exercise** (search first; if none: **Create “query”** pill)
* Library → **+ New exercise** (full form)

**Quick-add Modal (in workout)**

* Name, Equipment, Primary muscles, Variation tags, Optional defaults (target sets/reps, rest)
* On save: create exercise + add instance to current workout; focus first set

**Exercise Detail**

* Metadata; mini trends (e1RM, best set, weekly volume)
* Last 10 sessions table; open workout on tap
* Auto-progression settings (rule/step/microplates)

---

## 10) 📊 Progress UI Specs

**Filters**
Exercise multi-select • Date range (7/28/90d/custom) • Unit • Set type • e1RM formula • Rep filter (Average vs Last-Rep Strict/Targeted) • Set index selector

**Charts (fl_chart)**

* Overview: e1RM (line), Volume (area), Avg intensity (line), Best set progression
* Per-Set Strength: X = set index; Y = avg e1RM or weight; delta badges vs Set 1 (show **n**)
* Rep-Specific: weight@rep over time; PR callout for this rep
* Distribution: histograms of reps, intensity, RPE

**Performance**

* Decimate large series (basic stride or LTTB)
* Lazy load history lists; index queries by date & exercise

---

## 11) 📦 Settings, Units, Import/Export (Offline)

* Units: kg/lb (global) with per-set quick toggle (live convert)
* e1RM formula: Epley/Brzycki
* Default charts shown
* Privacy: biometrics lock (if available)
* **Export**: JSON (full DB dump) & CSV (workouts, sets, exercises)
* **Import**: JSON merge by IDs (resolve conflicts by latest `updated_at`)
* File access via `file_picker`, sharing via `share_plus`

---

## 12) 🔐 Accessibility & UX Details

* Tap targets ≥ 44×44; scalable fonts; contrast-safe
* Voice input for notes
* Accessibility announcements on timers
* PR confetti (subtle) & badges on Home/Exercise
* Finish Summary sheet: volume, best sets, PRs, next-time targets
* Empty states: friendly copy + “Add exercise” CTA; Progress explains how to unlock charts

---

## 13) 🧯 Quality: Testing & Performance

**Seed data (debug)**

* 6 months of realistic workouts (3–6 exercises/session, varying reps/weights, random RPE/RIR)

**Tests**

* Drift: schema, inserts, cascades, migrations
* Repos: “last N sessions”, “best set per workout”
* Services: MetricsService & SuggestionEngine golden tests
* Widgets: Log editing flow, Progress filters wiring
* Performance: cold start < 400ms FTF; tab nav < 100ms; smooth logging (no jank)

---

## 14) 🧩 Wireframe Snippets

**Log – Exercise Block**

```
[Bench Press          02:00  Rest ▾]   [History]
Last: 100×5 (e1RM 116)  •  Vol today: 1,250

 # | Weight | Reps | RPE | Notes     | ✓
 1 | 100.0  | 5    | 8   |           | [ ]
 2 | 102.5  | 4    | 9   |           | [ ]
 3 | 97.5   | 6    | 8   | drop set  | [ ]
 + Add set          ⋯ (duplicate / delete / convert)
[Best set today: 102.5×4 (e1RM 118.3)]   [Plate calc]
```

**Progress – Per-Set Strength**

```
Filters: [Bench Press] [Last 8w] [Avg e1RM] [Set Index: 1..5]
Δ vs Set 1
Set #1: 118.3
Set #2: 116.9  (-1.2%)
Set #3: 114.5  (-3.2%)
[──────── line chart ────────]
```

**Rep-Specific**

```
Exercise: Bench  | Rep target: [5]  | Mode: [Strict reps == 5]
Trend: Weight@5 over time  [───•──•────•──]
PR: 105×5 on 2025-10-12
```

---

## 15) ✅ MVP vs Later

**MVP**

* Core entities & logging
* Progress: Overview + Rep-Specific + Per-Set Strength (basic)
* CSV/JSON export/import

**Later**

* Supersets/giant sets UX
* Planned targets with auto-progression
* Apple Health/Google Fit (optional, local summaries only)
* Camera notes, bar path, plate math auto-suggestion

---

## 16) 📘 Coding Standards & Documentation

* **Dart style**: effective Dart, null-safe, `very_good_analysis` lints
* **Widgets**: small, composable; prefer `const` where possible; keep rebuild scopes tight
* **State**: Riverpod providers (immutable state, pure notifiers)
* **Separation**: no DB calls in Widgets; use Repos/Services
* **Tests**: fast, deterministic; golden values for metrics; CI-friendly
* **Docs**:

  * `README.md` with setup, scripts, architecture diagram
  * `docs/` for Metrics & Suggestion specs (copy sections 6–7)
  * Inline doc comments (`///`) for public APIs
* **Hot reload friendly**: avoid static singletons with hidden state; use providers; keep side effects in Repos

---

## 17) 🔐 Platform Permissions

* **No internet permission**
* File storage (scoped) for import/export
* Biometrics (if available) for lock screen

---

## 18) 📋 Acceptance Criteria (MVP)

* Complete a full workout without templates; variable sets/reps/weights work smoothly
* Filters update charts instantly; rep-specific trends feel intuitive
* Per-set (set_index) clearly shows strength drop-off or maintenance
* PRs & trend highlights feel informative, not spammy
* Import/export round-trips data without loss

---

*End of design.md*
