# Calendar App Design Research

> Comprehensive analysis of 11 calendar applications, covering layout, color systems, typography, interaction patterns, and design systems. Every sentence contains a concrete design decision, measurement, color code, or interaction pattern.
>
> Research date: 2026-09-09

---

## Table of Contents

1. [Google Calendar](#1-google-calendar)
2. [Apple Calendar](#2-apple-calendar)
3. [Fantastical](#3-fantastical)
4. [Microsoft Outlook Calendar](#4-microsoft-outlook-calendar)
5. [TimeTree](#5-timetree)
6. [Notion Calendar](#6-notion-calendar)
7. [TickTick](#7-ticktick)
8. [Calendars by Readdle](#8-calendars-by-readdle)
9. [Timepage by Moleskine](#9-timepage-by-moleskine)
10. [Structured](#10-structured)
11. [Morgen](#11-morgen)
12. [Design Patterns & Best Practices](#12-design-patterns--best-practices)
13. [Synthesis: Common Patterns](#13-synthesis-common-patterns)
14. [Synthesis: Differentiators](#14-synthesis-differentiators)
15. [Synthesis: Anti-Patterns](#15-synthesis-anti-patterns)
16. [Recommendations for Own Calendar](#16-recommendations-for-own-calendar)

---

## 1. Google Calendar

### Layout & Grid

**Mobile (Android/iOS):**
- Monthly view: 7-column grid (Sun-Sat), 5-6 row cells. Date numbers top-left of each cell. Events shown as small colored dots (timed) or thin colored bars (all-day). Tapping a date expands a schedule/agenda list below.
- Weekly view: 3 visible day columns by default on phone. Time column on left with hour labels. Events as colored rectangular blocks proportional to duration. All-day events in a row above the time grid.
- Daily view: Single column time grid with hour markers on the left.
- Schedule (Agenda) view: Vertical scrollable list grouped by date. Whimsical seasonal illustrations (beaches, mountains, parks) on empty days -- a signature design element.

**Web (Desktop):**
- Left sidebar ~260px: mini month calendar (7x6 grid) + calendar list + "Other people's calendars" section.
- Main content area uses Material Design 3 rounded container with light blue tint (#E8F0FE range) behind it.
- Month view: events as colored chips (rounded rectangle, ~20px height). Overflow: "+N more" clickable link at bottom of cell.
- Week view: 7 day columns, events as filled blocks with 4px border-radius.
- Three density options: Responsive (dynamically scales), Comfortable (standard), Compact (tighter spacing).

### Color System

**Primary brand color:** Google Blue #4285F4 -- today indicator, primary actions, default calendar "Cobalt" color.

**11 Event Colors (Modern set):**

| Name | Hex |
|------|-----|
| Tomato | #D50000 |
| Flamingo | #E67C73 |
| Tangerine | #F4511E |
| Banana | #F6BF26 |
| Sage | #33B679 |
| Basil | #0B8043 |
| Peacock | #039BE5 |
| Blueberry | #3F51B5 |
| Lavender | #7986CB |
| Grape | #8E24AA |
| Graphite | #616161 |

**13 Additional Calendar Colors:**

| Name | Hex |
|------|-----|
| Cocoa | #795548 |
| Pumpkin | #EF6C00 |
| Mango | #F09300 |
| Eucalyptus | #009688 |
| Pistachio | #7CB342 |
| Avocado | #C0CA33 |
| Citron | #E4C441 |
| Cobalt | #4285F4 |
| Wisteria | #B39DDB |
| Birch | #A79B8E |
| Radicchio | #AD1457 |
| Cherry Blossom | #D81B60 |
| Amethyst | #9E69AF |

**Two color rendering sets (Web):** Modern = white text on solid colored blocks. Classic = black text on lighter/pastel blocks.

**Today highlight:** Blue filled circle (~28dp diameter, #4285F4) behind the date number.
**Now line (Day/Week):** Red horizontal line with a small red dot (~6dp) on the left end, spanning full grid width, real-time position updates.
**Weekend vs weekday:** No color differentiation by default.

### Typography

- Google Sans (headings/UI), Google Sans Text (body/events). Material 3 Expressive update introduces Google Sans Flex.
- Month/year header ~20sp semibold. Day-of-week abbreviations ~12sp medium. Date numbers ~14sp regular (today: white on blue circle). Event text ~14sp regular (schedule view), ~12px (web chips).

### Interactive Elements

- FAB: bottom-right, 56dp diameter, 16dp corner radius, 6dp elevation. Expands to show "Event", "Task", "Birthday" options.
- Swipe: horizontal to navigate periods.
- Long-press: on time slot to quick-create event.
- Pull-to-refresh: syncs calendar.
- Touch targets: minimum 48dp per Material guidelines.

### Event Representation

- Week/Day: colored blocks spanning duration. Modern = solid fill + white text. Classic = lighter fill + black text. 4px border-radius, title truncated with ellipsis.
- Month (mobile): colored dots beneath date number for timed, thin bars for all-day.
- Month (web): colored chips (~20px height), "+N more" overflow.

### Widget Design (Android)

- Schedule (Agenda): min 2x2, expandable. Shows day/date large + scrollable event list + FAB. Material You Dynamic Color theming.
- Month View: monthly grid with date numbers, colored event dots, FAB top-right. Dynamic Color background.
- Both use rounded corners matching system widget shape.

### Unique Insights

- Seasonal empty-state illustrations are unique -- no other calendar does this.
- 24 total colors (11 event + 13 calendar) is the most generous palette in the industry.
- Material You Dynamic Color theming on Android adapts the entire widget to wallpaper colors.

---

## 2. Apple Calendar

### Layout & Grid

**iPhone (iOS 18):**
- Monthly view: large bold month name top-left. Four sub-modes via toggle:
  - Compact: colored dots below date numbers indicating calendar source
  - Stacked: thin colored pills stacked per day
  - Details: event titles inline, pinch-to-zoom supported
  - List: month grid above, selected day's event list below (split-screen)
- Day view: time column left, event blocks spanning duration, red now-line.
- Week view: 7 narrow columns.

**iPad:** Two-panel layout with sidebar (mini-calendar + calendar list).
**macOS:** Day/Week/Month/Year views via top toolbar segmented control. Sidebar with calendar list and mini-month.

### Color System

**Primary accent:** System Red #FF3B30 (light) / #FF453A (dark) -- today indicator, current time line, "+" button.

**System event colors:**

| Token | Light | Dark |
|-------|-------|------|
| systemRed | #FF3B30 | #FF453A |
| systemBlue | #007AFF | #0A84FF |
| systemGreen | #34C759 | #30D158 |
| systemOrange | #FF9500 | #FF9F0A |
| systemYellow | #FFCC00 | #FFD60A |
| systemPurple | #AF52DE | #BF5AF2 |
| systemPink | #FF2D55 | #FF375F |
| systemTeal | #5AC8FA | #64D2FF |
| systemIndigo | #5856D6 | #5E5CE6 |

**Today:** Red text for date number (systemRed). No filled circle -- text color only.
**Surfaces:** white #FFFFFF / grouped background #F2F2F7 (light), #1C1C1E (dark).
**Text:** primary #1D1D1F (light) / #FFFFFF (dark). Secondary: 60% opacity.

### Typography

- SF Pro: Display at >=20pt, Text at <20pt. 9 weights (Ultralight to Black).
- Large title (month name): 34pt Bold. Day-of-week labels: 13pt Regular. Date numbers: 17pt Regular (today: Semibold red). Event title: 15pt Regular. Event time: 13pt Regular. Tab bar labels: 10pt Regular.
- Tracking: Body -0.43px, Secondary -0.24px, Captions -0.08px, Tab bar +0.12px.

### Interactive Elements

- "+" button top-right (no FAB). iOS 18: "New" card with Event/Reminder toggle.
- Long-press on date/time for quick-create.
- Horizontal swipe to navigate.
- Pinch-to-zoom in Details month view and iPad Day/Week.
- Natural language: "Lunch with Alex tomorrow at 1 PM" auto-parses.
- Touch targets: minimum 44pt per Apple HIG.

### Event Representation

- Day/Week: colored blocks with lighter shade fill + ~3pt darker left border bar. Title and time inside.
- Month Compact (iOS 18): color-coded dots by calendar source.
- Canceled events: strikethrough on name. Invitation status icons: ? (pending), check (accepted), X (declined).

### Widget Design (iOS)

- Small (2x2): today's date large + next event title/time.
- Medium (4x2): today's date + 2-3 upcoming events with calendar color indicators.
- Large (4x4): mini month grid or expanded event list.
- Rounded corners ~20pt, SF Pro typography. Tap opens Calendar at relevant date.

### Unique Insights

- Red as primary accent is unusual -- most calendars use blue. Creates urgency.
- iOS 18's four month-view sub-modes (Compact/Stacked/Details/List) is the most flexible month view in any major calendar.
- Reminders integration (iOS 18) unifies events and tasks.
- No empty-state illustrations -- pure minimalism.

---

## 3. Fantastical

### Layout & Grid

- **DayTicker (signature element):** horizontal strip of upcoming days showing colored event pills positioned to indicate timing within the day. Synced with the schedule list below -- swiping the DayTicker changes the schedule date. Called "one of the best pieces of custom iPhone UI ever made."
- Monthly: full month grid accessed by pulling down on DayTicker. Color-coded dots indicate event density.
- Weekly: activated by landscape rotation with a delightful expansion animation from DayTicker.
- Year view: heat map -- darker colors = more events.
- Quarter view: three months simultaneously.
- Mac navigation sidebar: ~250px width. Three sidebar themes: dark+light (default "Fantastical"), all-light, all-dark.

### Color System

**Brand red scale:** #FCE3E8 (50) through #E0143C (500, primary) to #34030D (900).

**Event colors (Apple system):** Red #FF3B30, Orange #FF9500, Yellow #FFCC00, Green #34C759, Mint #00C7BE, Blue #3A82F7, Indigo #5856D6, Purple #AF52DE, Pink #FF2D55, Brown #A2845E.

**Semantic:** Success #34C759 fg / #D1F0DC bg. Warning #FF9500 / #FFF1C5. Error #E0143C / #FCE3E8. Info #3A82F7 / #E0EDFE.

**Surfaces:** Base #F5F5F7, Subtle #F2F2F7, Elevated #FFFFFF, Sidebar #F0F0F2.
**Dark mode:** Base #1C1C1E, Subtle #2C2C2E, Elevated #2C2C2E, Border #3A3A3C.
**Text:** Primary #1D1D1F, Secondary #48484A, Tertiary #8E8E93.
**Focus border:** brand red #E0143C.

### Typography

- SF Pro Text/Display (English), Apple SD Gothic Neo / Pretendard (Korean), SF Mono (time labels).
- Display: 32px Bold (700) / line-height 1.2. H1: 24px Bold / 1.25. H2: 18px Bold / 1.3. H3: 15px Bold / 1.35.
- Body Large: 15px Regular (400) / 1.45. Body: 13px Medium (500) / 1.4. Body Small: 12px Medium / 1.4.
- Day number: 14px SemiBold (600). Day (today): 16px Bold (700). Time label: 11px Bold. Caption: 11px Medium / 1.3.

### Spacing System

- Base unit: 4px. XS: 4px, SM: 6px, MD: 10px, LG: 14px, XL: 20px, 2XL: 32px, 3XL: 48px.
- Border radius: None (0), SM (4px), MD (5px), LG (8px), XL (12px), Full (9999px).
- Day cells: 6px padding, 50px min-height.
- Shadows: SM 0 1px 2px rgba(0,0,0,0.04), MD 0 4px 12px rgba(0,0,0,0.08), LG 0 12px 28px rgba(0,0,0,0.12).

### Interactive Elements

- Natural language input: 14px Regular, 8px/12px padding, 5px radius, focus 2px outline rgba(224,20,60,0.18). "/" selects calendar, "with" adds invitees, "at" sets location.
- Buttons: 13px SemiBold, 5px radius, 7px/14px padding. Primary: #E0143C background.
- Availability indicators: solid dot (busy), circle (free), forbidden sign (unavailable), dotted circle (tentative).
- Tentative events: diagonal striped pattern.
- Motion: Fast 120ms, Base 240ms, Slow 400ms. Easing: cubic-bezier(0.16, 1, 0.3, 1).

### Widget Design

16 home screen widgets in 3 sizes: Up Next, Event List, Month, Today's Date, Action button (small); Event List + Date, Event List + Calendar (medium); in-depth agenda (large). Weather integration included.

### Unique Insights

- DayTicker is the most distinctive custom UI component in any calendar app.
- Natural language parsing is best-in-class -- handles complex recurring events, multiple attendees, locations.
- Calendar sets (custom groupings toggled in one tap) are unique.
- Motion easing cubic-bezier(0.16, 1, 0.3, 1) creates a distinctive "snappy settle" feel.

---

## 4. Microsoft Outlook Calendar

### Layout & Grid

**Mobile:** Agenda, Day, 3-Day, Month views. View switching via icon in top-right.
- Agenda: vertical list with date headers.
- Day: time grid with animated calendar icon that fans forward/backward during scroll.
- Month: traditional grid; tapping a day shows that day's agenda below.

**Desktop (New Outlook):** Today button top-left. Inline appointment creation directly in time slots (no pop-up modal). Bold time indicator bar with past days shaded.

### Color System

**Brand:** Microsoft Fluent Blue #0078D4.
**Event categories:** Blue, Gray, Green, Orange, Purple, Red, Yellow (7 defaults). Web supports 15 predefined shades + custom hex picker.
**Design system:** Fluent 2 with three palette types: Neutral, Shared (cross-M365), Brand (product-specific).

### Typography (Fluent 2 -- iOS Type Ramp)

- Platform-native fonts: SF Pro (iOS), Roboto (Android), Segoe UI (Windows/Web).
- iOS: Caption 2 12pt Regular / 16pt line-height. Body 2 15pt Regular / 20pt. Body 1 17pt Regular / 22pt. Title 3 20pt SemiBold / 25pt. Title 1 28pt Bold / 34pt. Large Title 34pt Bold / 41pt. Display 60pt Bold / 70pt.
- Android: Body 2 14sp Regular / 20sp. Body 1 16sp Regular / 24sp. Title 3 18sp Medium / 24sp. Title 1 24sp Bold / 32sp.

### Interactive Elements

- Animated calendar icon: fans forward/backward during agenda scroll.
- Inline event creation (New Outlook): single-click empty time slot creates appointment in grid.
- Smart scheduling: drag options around calendar with team availability.
- Dynamic header: reduces size as you scroll.
- Meeting conflict detection from inbox.

### Today Indicator

Bold header bar with calendar-colored outline and fill stretching to current time. Past days shaded to emphasize "now."

### Widget Design (iOS)

Small: next event. Medium: next few calendar items + tasks. "Outlook Today": next event + tasks + quick email compose.

### Unique Insights

- Inline creation (no modal) reduces friction for quick entries.
- Animated calendar icon during scroll provides delightful feedback.
- Past-time shading visually distinguishes "done" from "upcoming."
- Smart scheduling with drag-based availability is unique to enterprise calendars.

---

## 5. TimeTree

### Layout & Grid

- Monthly: standard 7-column grid. Event titles as colored horizontal bars (~16-20px height) with white text. 2-3 event lines per cell, "+N" overflow.
- Weekly: two variants (since iOS 7.2.0 / Android 6.13.0) -- standard list and detailed time-block view.
- List view: vertical chronological list grouped by date.
- 2026 redesign: shifted to "My Time" -- single layered interface aggregating all shared calendars.
- Bottom tab navigation (4 tabs): Home Calendar, Calendar List, Activity, More.

### Color System

- 25 label colors available (expanded from original 10). Each family member typically owns their own color.
- Brand color: nature-inspired green (~#4CAF50 to #66BB6A range based on app icon).
- Today: colored circle behind date number.
- "Last selected color" remembered as default for next event -- reduces friction.

### Interactive Elements

- Event chat: comments directly on events create lightweight communication threads.
- Shared photo albums attached to calendars.
- Memo feature: sticky-note-like memos for non-date-bound information.
- Real-time notifications for shared calendar updates.
- Member identification: visual distinction of who added/modified events.

### Widget Design (iOS)

Three sizes: small (today's date + 1-2 events), medium (week view with event bars), large (full week with details). Lock screen widget (iOS 16+) shows next event. "Show only my events" toggle for filtering.

### Unique Insights

- Family-first color coding: each member owns a color across the calendar. Month view instantly shows whose events dominate each day.
- In-event chat turns the calendar into a coordination hub, not just a schedule display.
- 25 colors (vs typical 8-12) provides much more differentiation room for families.
- 70M+ users globally validates the family/shared calendar model.

---

## 6. Notion Calendar

### Layout & Grid

- Three-panel layout: left sidebar (calendar list), center (time grid), right (event detail panel).
- Weekly view is primary. Time gutter uses monospaced numerals for vertical alignment. 7-day columns with 1px borders at rgba(0,0,0,0.09).
- Daily: single column, "D" key. Monthly: standard grid, "M" key. Flexible multi-day: press 1-9 to show that many days.

### Color System (Exact Values)

**8-color event palette:**

| Color | Hex |
|-------|-----|
| Blue | #2383E2 |
| Green | #0F7B6C |
| Yellow | #CB912F |
| Red | #D44C47 |
| Purple | #9065B0 |
| Pink | #C14C8A |
| Orange | #D9730D |
| Default/Gray | #E3E2E0 |

**Surface (light):** Background #FFFFFF, Surface rgb(247,247,245) / #F7F7F5.
**Text (light):** Primary rgba(0,0,0,0.9), Secondary rgba(0,0,0,0.54), Tertiary rgba(0,0,0,0.35).
**Grid borders:** rgba(0,0,0,0.09) at 1px.
**Popover shadow:** 0 4px 12px rgba(0,0,0,0.12).

**Dark mode:** Background #191919. Default text #D4D4D4, Gray text #9B9B9B. Blue #2E7CD1 (icons) / #447ACB (text). Red #CD4945 / #BE524B. Purple #8D5BC1 / #865DBB. Green #2D9964 / #4F9768. Orange #D9730D / #CB7B37.

### Typography (Exact Values)

- Font: NotionInter (custom fork of Inter).
- Display H1: 64px / weight 700 / line-height 1.0 / letter-spacing -2.125px.
- Section headers: 12px / weight 500 / letter-spacing 0.125px / uppercase.
- Body: 16px. Time labels: 11px monospaced.
- Scale ratio: 5.3:1 between display and labels (exceeds typical 2-3:1).
- Three text opacity levels (0.9/0.54/0.35) create hierarchy without weight changes.

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| C / N | Create event |
| T | Jump to today |
| D / W / M | Day / Week / Month view |
| 1-9 | Show N days |
| G / . | Go to date |
| P | Overlay teammate calendar |
| Cmd+K | Command palette |

### Unique Insights

- Keyboard-first design is the core philosophy, not an accessibility add-on.
- Flexible N-day view (press 1-9) eliminates rigid day/week/month paradigm.
- Near-black text at 0.9 opacity (not pure black) reduces eye strain -- a subtle but impactful detail.
- rgba(0,0,0,0.09) grid borders are nearly invisible, creating structure without visual weight.
- Scheduling snippets: highlight empty blocks to generate shareable single-use booking links.

---

## 7. TickTick

### Layout & Grid

- 5 calendar views: List (mobile-only), Day, 3-Day (mobile-only), Weekly, Monthly.
- TickTick 8.0 (Jan 2026) added Yearly View with heatmap showing activity density across 12 months (similar to GitHub contribution graph).
- Monthly supports pinch-to-zoom to expand/contract visible task range.
- "Modern" calendar style option for cleaner look with improved readability.
- Desktop: card-style layout for browsing tasks.

### Color System

- Three "color-by" modes: By List (custom per list), By Tag (custom per tag), By Priority (red=high, orange=medium, blue=low, gray=none).
- Themes: color themes, seasonal series, city series, photography series, custom.
- Custom backgrounds per list.

### Task-Calendar Integration

- Tasks and calendar events appear side-by-side in unified calendar grid.
- Scheduled tasks show as time-blocked entries; unscheduled tasks in separate list.
- "Show Check Items" displays subtask checkboxes within calendar blocks.
- "Show All Repeat Cycles" shows repeated tasks on recurrence dates.
- Drag-and-drop from task list to calendar for scheduling.
- Two-way sync with Google Calendar, iCloud, Outlook.
- Suggested Tasks (8.0): AI reviews unfinished items and identifies focus priorities.

### Event/Task Representation

- Time-blocked colored rectangles in weekly/daily views.
- Vertical color bar on left side of each block.
- Color corresponds to selected color-by mode.
- Task completion interaction directly on calendar blocks.

### Unique Insights

- Task-calendar parity: tasks and events are first-class citizens in the same timeline.
- Pinch-to-zoom on month view changes temporal granularity -- rare gesture.
- Heatmap yearly view borrowed from productivity tools (GitHub, fitness trackers).
- Three color-by modes provide semantic flexibility no pure calendar offers.

---

## 8. Calendars by Readdle

### Layout & Grid

- Views: Day, Week, Month, List, Tasks -- moved from burger-menu to top-bar visibility.
- Horizontal orientation eliminates top/bottom bars for pure content focus; pinch-to-zoom changes between 7-day and 3-day range.
- iPad: multi-panel layout with sidebar.

### Interactive Elements

- Natural language input as primary creation path: "Lunch with Alex tomorrow at 1 PM" auto-parses. "/" selects calendar. Supports English, German, French, Italian, Spanish, Russian.
- Tap-and-hold to create events in Day/Week/Month.
- Drag-and-drop to reschedule.
- Meeting integration: Zoom and Google Meet join buttons directly on events.

### Color System

- Refined dark mode palette -- refuses high-contrast pure black/white.
- Calendar-level color coding per account.

### Unique Insights

- Natural language is the core UX, not a feature -- event creation via typing is the primary path.
- Custom weather icon set for cross-platform consistency.
- Task management inline: location-based reminders, subtasks, notes, due dates within calendar context.
- 2.5-year design cycle with senior product designer.

---

## 9. Timepage by Moleskine

### Layout & Grid

- **Heat Map View (signature):** month displayed as "blobs" in shades of the chosen theme color -- deeper color = more events. Not a traditional grid.
- **Timeline View:** combines mini-month, upcoming days, day schedule, and event details in one vertical fluid layout.
- **Day View:** events as rich cards with location map, weather forecast (actual vs feels-like), travel time (car/bicycle/pedestrian ETAs), recognized contacts.

### Color System

- **Monochromatic philosophy:** entire app uses a single color theme. Background, accents, and intensity gradients all derived from one hue.
- 60+ hand-crafted themes: bright colors, pastels, dark mode, black & white.
- Color selection is part of onboarding -- choosing a favorite color is the first setup step.
- Each theme is a curated set of tints/shades matching Moleskine's physical notebook colors.

### Unique Insights

- Monochromatic design is unique among all calendar apps -- the entire UI is one color with graduated intensity.
- Heat map replaces standard dots/numbers with organic blob shapes showing schedule density.
- Weather treated as a peer of time and location, not an afterthought.
- Physical notebook aesthetic ("stationery, not software") creates strong brand differentiation.

---

## 10. Structured

### Layout & Grid

- **Vertical Timeline (centerpiece):** single continuous vertical line showing the entire day.
- Three layout modes:
  - Full: time on left, gap suggestions, task icons below dates.
  - Simplified: removes time slot suggestions and task icons.
  - Minimal: strips suggestions and timestamps -- cleanest appearance.
- Weekly view integrates the timeline design.
- Inbox: holding area for unscheduled tasks, reducing timeline clutter.

### Color & Typography

- Selectable app color schemes or custom colors. Three backgrounds: System, Light, Dark.
- "Vibrant colors to distinguish between different types of activities."
- OpenDyslexic font available as accessibility option -- neurodivergent-friendly.
- Font size linked to device settings on mobile; slider on macOS.

### Unique Insights

- Timeline-first rejects the traditional calendar grid in favor of linear day visualization.
- Three explicit layout densities (Full/Simplified/Minimal) is rare.
- Neurodivergent design focus: ADHD-friendly structure, dyslexia font, VoiceOver support.
- Free time between tasks is visually highlighted, showing availability gaps.

---

## 11. Morgen

### Layout & Grid

- **Three-pane interface:** left (navigation: tasks, invites, booking, workflows), middle (overview of due tasks/events, sortable by priority), right/largest (calendar views: weekly, monthly, agenda, custom).
- Sidebar is the control center for tasks with filtering by folders/lists.

### Color System

- Calendar-level colors from Calendar Integrations panel.
- 13 additional base colors for task blocks and tags beyond calendar colors.
- Light, Dark, or System theme.

### Interactive Elements

- Drag-and-drop tasks from integrated apps (Todoist, Things, etc.) onto calendar.
- AI Planner suggests optimal time slots, adjusts to conflicts, respects focus time.
- Booking links with buffer time and focus protection.
- Confetti celebrations after completing tasks.

### Unique Insights

- Three-pane layout is rare for calendars -- typically a productivity/email pattern.
- 13 tag/block colors beyond calendar colors enables rich semantic coding.
- AI planner "suggests, not automates" -- preserves user control.

---

## 12. Design Patterns & Best Practices

### Grid Construction

- Monthly grid: `grid-template-columns: repeat(7, 1fr)` -- seven equal columns. Cell aspect-ratio 1:1 (square) on mobile; min-height ~100px web, ~48-52px mobile. Grid lines: 1px hairline borders.
- Weekly time grid: left time gutter 72px for hour labels (right-aligned). Hour row heights: 96px/hour (48px/30min). Seven day columns split remaining width equally.
- Event height formula: `(duration_minutes / 60) * hourRowHeight` -- height IS the duration.

### Touch Target Requirements

| Platform | Minimum Size | Physical Size |
|----------|-------------|---------------|
| iOS (Apple HIG) | 44x44 pt | ~7.5mm |
| Android (MD3) | 48x48 dp | ~9mm |
| WCAG 2.2 AAA | 44x44 CSS px | varies |

- At 7 columns on 375pt screen, each cell is ~53pt wide -- naturally meets iOS minimum.
- Below 44pt touch targets: 25%+ tap error rate.
- Minimum 8dp between interactive elements (MD3).

### Dark Mode Color Adaptation

- Background: #121212 (MD3 standard) or #000000 (OLED) / #1C1C1E (iOS system).
- Surface elevations: #1E1E1E, #2C2C2C, #383838.
- Text: primary white at 87% opacity, secondary 60%, disabled 38%.
- Grid lines: 15-20% white opacity.
- Event colors: boost chroma/saturation 15-25% to maintain perceived equivalence. Formula: light mode 60% HSL saturation becomes 75-85% in dark mode. Alternative: increase lightness +25%, reduce saturation -10%.
- Today indicator accent unchanged (red for Apple, blue for Google).

### Responsive Breakpoints

| Name | Width | Layout |
|------|-------|--------|
| XSmall | <=575px | Single column, bottom sheets |
| Small | 576-767px | Single column, more spacing |
| Medium | 768-991px | Optional sidebar, 2-panel |
| Large | 992-1199px | Sidebar + main, 2-panel |
| XLarge | >=1200px | Sidebar + main + detail panel |

### Event Representation Patterns

1. **Filled Block:** entire chip background = calendar color. Most prominent; readability risk with dark colors.
2. **Left-Border:** neutral background + 3-4px colored left bar. Best readability.
3. **Left-Tint:** 10-30% opacity tinted background + colored left bar. Balanced.

- Border radius: 4-8px (pill for all-day, slight round for timed).
- Min height: 20-24px visual for 15-min events.
- All-day events: full-width pill, 24-28px tall.
- Text: 11-13px medium weight, single-line truncated with ellipsis.

### Typography for Calendars

- iOS scale reference: Large title 34pt Bold, Body 17pt Regular, Secondary 15pt Regular, Caption 13pt Regular, Minimum 10pt Regular.
- Material 3 reference: Title Large 22px, Title Medium 16px/500, Body Large 16px/400, Body Medium 14px/400, Label Medium 12px/500, Label Small 11px/500.
- Date numbers in monthly grid: 14-16px medium (mobile), 12-14px (dense web).
- Event title text: 12-14px (mobile), 11-13px (web).
- Sans-serif/humanist fonts work best at small calendar sizes.

### Information Density

- Monthly: 2-3 events per cell maximum, then "+N more" overflow.
- Mobile monthly: colored dots only (no event text in cells) is the cleanest approach.
- Progressive disclosure: compressed month for navigation, detailed week/day for active planning.
- Optimal event color count: 8-12 distinguishable colors maximum; 4-6 for family calendars.

### Widget Design Guidelines

**iOS WidgetKit:** Small = next event only (title + time). Medium = 2-3 events as list. Large = mini calendar grid + event list. No "Open App" button -- tap content to open. At end of day, show tomorrow's first event.

**Android:** Glanceable -- most important data in smallest size. Layout-independent across orientations. Minimize update frequency for battery.

### Animation Patterns

- Period navigation: horizontal slide, 200-300ms.
- View switching (month/week/day): vertical expansion/collapse or cross-fade.
- Event detail: bottom sheet slide-up (mobile) / modal fade (web), 250-350ms.
- Micro-interactions: 100-150ms.
- Spring animations for bottom sheets: overdamped, ~400ms.

---

## 13. Synthesis: Common Patterns

These patterns appear in 80%+ of analyzed apps. Own Calendar should adopt them as baseline:

### Universal Standards

1. **7-column grid for monthly view** -- every single app uses Sun-Sat (or Mon-Sun locale) seven columns.
2. **Today highlighted differently from all other dates** -- 100% of apps do this. The two dominant patterns: filled circle behind date number (Google, TimeTree) or colored text without circle (Apple, Notion).
3. **Red or accent-colored horizontal "now line" in day/week views** -- Apple (red), Google (red), Notion (red), Fantastical, Readdle all use this. Full-width line with left-anchored dot.
4. **Event overflow as "+N more" in month cells** -- Google, Apple, TimeTree, Outlook all use this pattern.
5. **Bottom sheet for event creation on mobile** -- universal on iOS/Android. Slides up with spring animation.
6. **Horizontal swipe for period navigation** -- every mobile calendar uses left=forward, right=backward swipe.
7. **Calendar-level color coding** -- every app assigns colors at the calendar/list level, not individual events (though event-level overrides exist in Google, TickTick).
8. **8-12 event color options** -- Google (11+13), Apple (9), Fantastical (10), Notion (8), Outlook (7+custom). The sweet spot is 8-12 distinguishable colors.
9. **Colored left border on event blocks** -- Apple, TickTick, Morgen, Readdle all use the "neutral background + colored left bar" pattern. Google uses solid fill as alternative.
10. **Touch targets >= 44pt (iOS) / 48dp (Android)** -- universal. Calendar cells at 7 columns on 375pt screen naturally meet this (~53pt each).

### Near-Universal (70-80%)

11. **Natural language event creation** -- Fantastical, Apple, Readdle, Notion Calendar, Google all support parsing "Lunch tomorrow at noon."
12. **Agenda/schedule view as a list** -- Google, Outlook, Apple, Fantastical, Readdle all offer chronological vertical list.
13. **Dark mode with separate color palette** -- not just inverted colors. Event saturation boosted 15-25%.
14. **Widget showing next upcoming event** -- every app with a widget shows the next event in the smallest widget size.

---

## 14. Synthesis: Differentiators

These vary by design philosophy and become strategic choices for Own Calendar:

### Today Indicator Style

| Style | Apps | Character |
|-------|------|-----------|
| Filled blue circle | Google Calendar | Friendly, visible |
| Red text (no circle) | Apple Calendar | Minimal, elegant |
| Larger bold text | Fantastical | Subtle, typographic |
| Heat map intensity | Timepage, TickTick yearly | Data-dense |

**Decision for Own Calendar:** Filled circle (more visible than text-only) in the app's primary accent color.

### Event Color Fill Style

| Style | Apps | Tradeoff |
|-------|------|----------|
| Solid fill + white text | Google (Modern) | High visibility, brand-feeling |
| Light tint + colored left bar | Apple, Readdle | Best readability |
| Soft/muted fills | Notion Calendar | Calm, professional |
| Monochromatic graduated | Timepage | Unique, brand-heavy |

**Decision for Own Calendar:** Left-tint (10-30% opacity background + colored left bar) as default -- best readability. Solid fill as optional "vibrant" mode.

### Information Density Philosophy

| Level | Apps | When |
|-------|------|------|
| Sparse | Timepage, Structured Minimal | Focus/calm |
| Moderate | Google, Apple, Readdle | General use |
| Dense | Morgen, Outlook, TickTick | Power users |

**Decision for Own Calendar:** Moderate as default, with density toggle (matching Google's Comfortable/Compact).

### Primary Accent Color

| Color | Apps | Feeling |
|-------|------|---------|
| Blue | Google, Outlook, Notion | Trust, calm, professional |
| Red | Apple, Fantastical | Urgency, today-focus |
| Green | TimeTree | Nature, family, growth |

**Decision for Own Calendar:** Blue as primary (trust, professionalism) with today indicator in a warm accent (coral/red) for contrast.

### Navigation Pattern

| Pattern | Apps | Platform |
|---------|------|----------|
| Bottom tab bar | TimeTree, most iOS apps | iOS native |
| FAB (bottom-right) | Google Calendar | Material/Android |
| Top-right "+" button | Apple Calendar | iOS HIG |
| Keyboard shortcuts | Notion Calendar | Desktop/power users |

---

## 15. Synthesis: Anti-Patterns

Common mistakes that Own Calendar must avoid:

1. **Recurring event editing without clear "this / following / all" disambiguation.** Users accidentally modify all instances when they meant to change one. Always show a three-option dialog.

2. **Visual overload from too many simultaneous colors/icons/text.** More than 5-6 distinct colors visible in a single month view becomes a rainbow noise wall. Cap visible colors contextually.

3. **Shrinking desktop to mobile instead of redesigning.** Phone monthly view with dots is appropriate; showing the same dots on a 1440px screen wastes space. Each breakpoint needs its own layout.

4. **Color-only information without supplementary indicators.** Color-blind users (8% of males) cannot distinguish events by color alone. Supplement with patterns, icons, or text labels.

5. **Touch targets under 44pt.** 25%+ tap error rate below this threshold. 15-minute event blocks in day view must extend tap area beyond visual bounds.

6. **Empty calendar with no onboarding or CTA.** A blank grid with no events is intimidating. Google's illustrations and Structured's "add your first task" prompt both solve this.

7. **Timezone omission in event display.** Enterprise users crossing zones lose trust when events show in ambiguous local time.

8. **Drag-and-drop without undo.** Moving an event by accident with no way to undo causes anxiety. Always offer undo snackbar (3-5 second window).

9. **Calendar pickers for dates > 1 year away.** Scrolling month-by-month to find a date 18 months out is torture. Use year/month dropdowns or date input for distant dates.

10. **Dark mode that inverts event colors to illegibility.** Event colors designed for white backgrounds look washed out or clash on #1C1C1E. Maintain a separate dark-mode color palette with boosted saturation.

---

## 16. Recommendations for Own Calendar

### Phone View

1. **Monthly view: adopt the "dots + expand" pattern.** Show colored dots below date numbers (maximum 3 dots per day matching calendar colors). Tapping a date expands an agenda list below the grid (Apple List mode / Google Schedule hybrid). This is the proven mobile pattern -- dense month views with inline text are unreadable on phones.

2. **Today indicator: filled circle in primary blue (#4285F4 range) behind date number, ~28dp diameter.** White text for date number inside circle. This is more visible than Apple's text-only approach and proven by Google's massive user base.

3. **Now line: red (#FF3B30) horizontal line with 6dp left-anchored dot in day/week views.** Real-time position updates. Use red regardless of app theme -- it's the universal "now" signal.

4. **Event blocks: left-tint pattern.** 15% opacity calendar-color background + 3px solid calendar-color left border + dark text. This has the best readability across all color choices.

5. **Touch targets: minimum 48dp.** Use Material 3 guidelines (48dp) not Apple's lower 44pt. For 15-minute event blocks in day view, visual height can be 24px but tap target extends to 48dp with transparent padding.

6. **FAB placement: bottom-right, 56dp, primary blue.** Single tap creates event. Long-press or upward drag expands to show Event/Task options. 16dp corner radius, 6dp elevation.

7. **Navigation: bottom tab bar with 4 tabs maximum.** Calendar (monthly), Today (day view), Tasks, Settings. Active tab uses filled icon + primary color; inactive uses outlined icon + gray.

8. **Event creation: bottom sheet, not full-screen modal.** Natural language input field at top. Sheet height: 60% of screen initially, expandable to full-screen for detail editing.

9. **Swipe gestures: horizontal only.** Left = forward in time, right = backward. No vertical swipe conflicts with scroll. 200-300ms slide animation.

10. **Empty state: single illustration + "No events today" text + primary CTA button "Add Event."** Not as elaborate as Google's seasonal illustrations, but not as bare as Apple's text-only approach.

### Web View

1. **Three-panel layout at >= 992px:** Left sidebar (~260px) with mini-month + calendar list. Center panel with main calendar view. Right panel (~300px) with event detail (collapsible). Below 992px: collapse to two panels. Below 768px: single panel with bottom sheet for details.

2. **Sidebar mini-month:** 7x6 grid with today highlighted. Clicking a date navigates the main view. Current month days in primary text; adjacent month days at 40% opacity.

3. **Week view as default on web.** 7 day columns, 96px/hour rows, 72px time gutter. Events as left-tint blocks (same pattern as phone). Hour labels right-aligned in gutter, half-hour lines at 50% opacity of hour lines.

4. **Month view on web: show event chips (not dots).** Colored rounded rectangles (~20px height, 4px border-radius) with truncated event title. Maximum 3 per cell, then "+N more" link.

5. **Keyboard shortcuts (adopt Notion Calendar's proven set):** N = new event, T = today, D/W/M = day/week/month, arrow keys = navigate, Enter = open event detail. Display shortcut hints in tooltips.

6. **Hover states:** Event blocks show shadow elevation on hover (0 4px 12px rgba(0,0,0,0.12)). Day cells show light background tint on hover.

7. **Density toggle:** Comfortable (default, 96px/hour) and Compact (72px/hour). Accessible from top toolbar.

### Widget (iOS)

1. **Small (2x2):** Today's date number large (34pt Bold) + next event title and time (13pt). Calendar color dot (6pt) next to event. If no events: "No events" in secondary text.

2. **Medium (4x2):** Today's date + 2-3 upcoming events as list. Each event: calendar color bar (3px) + title (15pt) + time (13pt secondary). If all-day: show "All day" instead of time.

3. **Large (4x4):** Mini month grid (top) + event list (bottom). Today highlighted with filled circle. Events with calendar colors.

4. **Tap behavior:** Small/Medium: open app at today view. Large month grid: tap date opens that date's view.

### Theme System

1. **Design tokens to expose:**

```
// Surfaces
--surface-primary: #FFFFFF / #1C1C1E
--surface-secondary: #F2F2F7 / #2C2C2E
--surface-elevated: #FFFFFF / #2C2C2E

// Text
--text-primary: rgba(0,0,0,0.9) / rgba(255,255,255,0.87)
--text-secondary: rgba(0,0,0,0.54) / rgba(255,255,255,0.60)
--text-tertiary: rgba(0,0,0,0.35) / rgba(255,255,255,0.38)

// Accent
--accent-primary: #4285F4 / #5B9BF7
--accent-today: #FF3B30 / #FF453A
--accent-now-line: #FF3B30 / #FF453A

// Grid
--grid-border: rgba(0,0,0,0.09) / rgba(255,255,255,0.12)
--grid-hour-line: rgba(0,0,0,0.15) / rgba(255,255,255,0.15)
--grid-half-hour-line: rgba(0,0,0,0.06) / rgba(255,255,255,0.06)

// Event colors (light / dark -- boost saturation 20% for dark)
--event-red: #D50000 / #E53935
--event-pink: #E67C73 / #EF9A9A
--event-orange: #F4511E / #FF7043
--event-yellow: #F6BF26 / #FFCA28
--event-green: #33B679 / #4CAF50
--event-teal: #009688 / #26A69A
--event-blue: #039BE5 / #42A5F5
--event-indigo: #3F51B5 / #5C6BC0
--event-purple: #8E24AA / #AB47BC
--event-gray: #616161 / #9E9E9E
```

2. **Spacing scale (4px base, matching Fantastical):**
   - XS: 4px, SM: 8px, MD: 12px, LG: 16px, XL: 24px, 2XL: 32px, 3XL: 48px.

3. **Border radius scale:**
   - None: 0, SM: 4px, MD: 8px, LG: 12px, XL: 16px, Full: 9999px.
   - Event blocks: SM (4px). Buttons: MD (8px). Bottom sheets: LG (12px) top corners. FAB: Full.

4. **Typography scale (Inter or system font):**
   - Display: 32px/700. H1: 24px/700. H2: 18px/600. H3: 15px/600.
   - Body: 14px/400. Body Small: 12px/400. Caption: 11px/500.
   - Day number: 14px/500. Day today: 14px/700 (white on accent circle).
   - Event title: 13px/500. Event time: 11px/400.

5. **Motion tokens:**
   - Duration fast: 120ms. Duration base: 240ms. Duration slow: 400ms.
   - Easing: cubic-bezier(0.16, 1, 0.3, 1) -- Fantastical's proven "snappy settle."

6. **Shadow scale:**
   - SM: 0 1px 2px rgba(0,0,0,0.04). MD: 0 4px 12px rgba(0,0,0,0.08). LG: 0 12px 28px rgba(0,0,0,0.12).

### Event Color Palette (10 colors recommended)

Own Calendar should ship with 10 event colors, matching the sweet spot between Google's generous 24 and Notion's minimal 8:

| Name | Light Hex | Dark Hex | Usage |
|------|-----------|----------|-------|
| Red | #D50000 | #E53935 | Urgent/important |
| Coral | #E67C73 | #EF9A9A | Personal |
| Orange | #F4511E | #FF7043 | Work |
| Yellow | #F6BF26 | #FFCA28 | Reminders |
| Green | #33B679 | #4CAF50 | Health/exercise |
| Teal | #009688 | #26A69A | Family |
| Blue | #039BE5 | #42A5F5 | Default |
| Indigo | #3F51B5 | #5C6BC0 | Study |
| Purple | #8E24AA | #AB47BC | Social |
| Gray | #616161 | #9E9E9E | Canceled/tentative |

Dark mode colors are shifted: saturation boosted ~20%, lightness increased ~10% to maintain perceived equivalence on dark backgrounds.

### Family Calendar Specific (from TimeTree Analysis)

- Assign a default color to each family member when they join a shared calendar.
- Show member avatar (or initial circle) on event blocks in shared calendar view.
- "Last selected color" memory per user to reduce event creation friction.
- In-event comments/chat for coordination (TimeTree's killer feature for families).
- "Whose events" filter toggle in month view header.

---

## Appendix: Source Apps Summary

| App | Primary Color | Event Colors | Font | Today Style | Key Innovation |
|-----|--------------|-------------|------|-------------|----------------|
| Google Calendar | #4285F4 Blue | 11+13 | Google Sans | Blue filled circle | Seasonal empty-state illustrations |
| Apple Calendar | #FF3B30 Red | 9 system | SF Pro | Red text | 4 month-view sub-modes (iOS 18) |
| Fantastical | #E0143C Red | 10 Apple | SF Pro | Bold+size | DayTicker + NL parsing |
| Outlook | #0078D4 Blue | 7+custom | Platform native | Shaded past | Inline creation + animated icon |
| TimeTree | ~#4CAF50 Green | 25 labels | System | Green circle | In-event chat for families |
| Notion Calendar | #2383E2 Blue | 8 | NotionInter | Red now-line | Keyboard-first + N-day view |
| TickTick | Per-theme | By list/tag/priority | System | Platform default | Task-calendar parity |
| Readdle | Per-theme | Per-calendar | SF Pro | Accent color | NL as primary creation UX |
| Timepage | Monochromatic | Single hue | Sans-serif | Heat intensity | Monochromatic theming |
| Structured | Per-theme | Per-task | System + OpenDyslexic | Timeline marker | 3 layout densities |
| Morgen | Per-theme | 13+ colors | Sans-serif | Standard | Three-pane + AI planner |
