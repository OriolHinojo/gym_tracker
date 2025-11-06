# 📊 IronPulse — Insights & Analytics Expansion Plan

> Detailed roadmap for enriching the Progress and Home experiences with deeper analytics, richer filters, and more visual storytelling. Use this document to coordinate design, implementation, and data model work across the team.

---

## 1. Objectives

- Elevate the analytics depth beyond a single line chart.
- Highlight trends that motivate users (streaks, PRs, volume growth).
- Provide granular filters so lifters can reflect on specific routines, time slots, or tags.
- Keep the UI consistent and visually engaging across Home, Progress, and Detail screens.

### Current Status (vNext)
- ✅ Added analytics service (volume, PRs, time-of-day) and wired summary cards into Progress screen (scoped to selected exercise).
- ✅ Implemented template/tag/time filters with modal UX.
- ⏳ Still need to capture session duration/RPE/location/rest actuals.
- ⏳ Drill-down visuals, saved views, and home-page insights strip remain outstanding.

---

## 2. Data Model & Storage Upgrades

To power the new insights, extend the data stored per workout and set:

| Field | Scope | Purpose | Notes |
| --- | --- | --- | --- |
| `template_id` | workout + set | Track lineage of templated sessions | ✅ Already persisted |
| `tag` | set | Warm-up / Drop set / AMRAP / Custom | ✅ Already persisted |
| `started_hour` | workout | Time-of-day analysis | Derived from `started_at` (local) |
| `session_duration` | workout | Rest efficiency, completion time metrics | Compute from log start/finish |
| `perceived_exertion` (RPE) | workout | Correlate effort with performance | Optional field on finish screen |
| `location` | workout | Differentiate home vs gym vs travel | Free-form or picklist |
| `mood` | workout | Qualitative insight (emoji scale) | Optional but useful for correlations |
| `set_rest_target` | set | Compare planned vs actual rest | Already tracked in-screen; persist to analyze |
| `set_rest_actual` | set | Actual rest before set start | Need to store when rest timer stops |

**Storage implications**
- Update `LocalStore.saveWorkout` + `updateWorkout` to accept new fields.
- Add lightweight migrations in `_ensureTemplateMetadata()` successor to backfill defaults.
- Consider evaluating Drift/SQLite if JSON operations become costly; migration path should be documented but not mandatory for the first iteration.

---

## 3. Insight Features & Metrics

### 3.1 Volume & Load Progression
- Total tonnage per session / week / template.
- Volume split by movement category (push/pull/legs or custom tags).
- Rolling 4-week average vs current week.
- Visual: stacked bar or area chart.

### 3.2 PR & Personal Bests
- Track 1-rep max estimates, heaviest set, and rep PRs.
- “Near miss” detection (95%+ of PR).
- Visual: badge list + timeline with highlight markers.

### 3.3 Consistency & Streaks
- Workout streak (days/weeks).
- Program adherence (templates completed consecutively).
- Rest timer compliance (percentage within target).
- Visual: calendar heatmap + streak chip.

### 3.4 Time-of-Day Performance
- Split sessions into morning/afternoon/evening buckets.
- Compare volume, PR rate, subjective effort across buckets.
- Visual: dual bar chart + insight text (“Morning sessions average +12% volume”).

### 3.5 Template Deep Dive
- Dedicated template detail page:
  - Last N runs with volume/time-to-complete deltas.
  - Top performing exercises within template.
  - Suggestions: “Ready to increase weight?” based on trend.
- Visual: side-by-side comparison cards + mini sparkline.

### 3.6 Tag-Based Insights
- Filter by set tags (Warm-up, Drop set, AMRAP).
- Metrics: volume contribution, PR frequency, fatigue correlations.
- Visual: donut chart for tag distribution; table of top exercises using each tag.

### 3.7 Recovery & Effort
- Compare perceived exertion vs performance.
- Highlight sessions with high volume but low RPE (potential for PR pushes).
- Visual: scatter plot (RPE vs volume) with regression line.

---

## 4. Filtering & Query UX

### 4.1 Filter Controls
- Multi-select chips for:
  - Workout templates
  - Exercise groups / muscle categories
  - Time of day (Morning 4–11, Midday 11–16, Evening 16–22, Late)
  - Locations (Home, Gym X, Travel)
  - Tags (Warm-up, Drop set, AMRAP)
- Date range picker with quick presets (Last 7 days, 4 weeks, 3 months, Year to date).
- Toggle to include/exclude rest days (for streak view).

### 4.2 Saved Views
- Allow saving filter combinations as named presets (“Leg Day mornings”).
- Store in LocalStore under `analytics_views`.
- Surface as quick chips at the top of the Progress page.

### 4.3 Empty & Loading States
- Friendly illustrations when no data matches filters.
- Inline call to action (e.g., “Log a morning session to see this chart”).

---

## 5. UI/UX Enhancements

### 5.1 Progress Dashboard Layout
- Replace single-line chart with a scrollable card grid:
  1. **Headline Insight Card** – “You lifted 8% more volume this week.”
  2. **Volume Trend Card** – stacked bar with weekly tonnage.
  3. **Streak Card** – big number, progress bar, “Maintain streak” CTA.
  4. **PR Feed** – list of recent PRs with icons (weight plate).
  5. **Time-of-Day Comparison** – split bars with textual recommendation.
  6. **Template Leaderboard** – cards sorted by average volume or PR rate.
  7. **Tag Distribution** – donut chart for set tags.

### 5.2 Drill-Down Screens
- Tap any card to open a full page with detailed charts + filters scoped to that metric.
- Provide breadcrumbs to return to overall insights.

### 5.3 Visual Cohesion
- Adopt consistent color palette across charts (use theme extensions).
- Introduce legend chips with icons (e.g., sun for morning, moon for evening).
- Consider using `fl_chart` or `syncfusion_flutter_charts` for complex visuals; define a wrapper for shared styling (rounded corners, gradients).

### 5.4 Home Screen Insights Strip
- Add a top “Insights Today” horizontal scroll:
  - Streak chip (tappable).
  - “3 PRs this week” card.
  - “Rest target hit 75% yesterday” card.
- Each chip opens the relevant deep-dive page.

### 5.5 Session Detail Enhancements
- Expand per-exercise collapse to include mini charts (sparkline for weight progression during session).
- Show tag icons next to each set.
- Include session summary header with duration, start time bucket, volume, PR badges.

---

## 6. Implementation Phases

### Phase 1 — Foundations *(in progress)*
- ✅ Added analytics service and tests (`test/analytics_service_test.dart`).
- ✅ Added helper queries (`listWorkoutsRaw`, `listAllSetsRaw`) and shared tag helpers.
- ⏳ Instrument log screen to capture session duration, start hour, rest actuals, RPE, location.
- ⏳ Evaluate persistence format once new fields are defined.

### Phase 2 — Dashboard Cards *(partially complete)*
- ✅ Progress screen shows summary, volume trend, time-of-day, PR cards.
- ✅ Added filter bar + modal (template/tag/time-of-day).
- ⏳ Create reusable `InsightCard` abstraction & saved views.
- ⏳ Add streak card, leaderboard, tag distribution donut.

### Phase 3 — Deep Dives & Visuals
- TODO: Drill-down pages per metric, richer chart types (stacked bar, scatter, heatmap).
- TODO: Shared chart styling utilities, accessible legends/tooltips.

### Phase 4 — Home & Detail Integration
- TODO: Home insights strip, session/template detail enrichments.
- Ensure consistent theming and icons across sections.

### Phase 5 — Polish & Performance
- Optimize analytics queries (consider indexing or caching).
- Add background pre-calculation when app launches.
- Expand widget/integration tests for filter interactions and chart rendering.
- Conduct user testing / gather feedback.

---

## 7. Dependencies & Open Questions

- **Chart library**: evaluate `fl_chart` vs `syncfusion_flutter_charts` vs custom painter. Need to confirm license constraints and performance.
- **Performance**: with more data fields, should we migrate from JSON to a structured DB? Plan migration path if necessary.
- **Sync/Sharing**: if future roadmap includes cloud sync, ensure new data fields align with backend schema plans.
- **Accessibility**: ensure charts have semantic descriptions; consider alt text or data tables.
- **Mobile constraints**: design responsive layout that scales on tablets and handles landscape orientation.

---

## 8. Tracking & Follow-up

- Once implementation begins, log progress cards/issues referencing sections of this doc.
- Update `design/design.md` as features ship.
- Move completed items to the main design doc and trim them from this plan.
- Keep tests and analytics calculations documented (`docs/analytics.md` suggestion) as formulas grow complex.

---

*Prepared to align engineering, design, and product for the upcoming Insights & Analytics milestone. Iterate on this plan as new requirements surface or priorities shift.*
