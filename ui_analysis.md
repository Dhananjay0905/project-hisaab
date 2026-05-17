# Hisaab — UI / Styling Analysis

The design system is solid (Plus Jakarta Sans + Be Vietnam Pro, coherent color tokens, softShadow/cardShadow). These suggestions aim to close the gap between the current implementation and a truly premium feel.

---

## 🏠 Home Page

| # | What | Suggestion |
|---|---|---|
| 1 | **Balance card is always hidden by default** | Start with balance visible — the hidden state (`₹ •••••`) should be the opt-in, not the default. Users opening the app want to see their balance immediately. |
| 2 | **Balance visibility is lost on every app restart** | Persist the `_balanceVisible` flag in `SharedPreferences` so it remembers the user's preference. |
| 3 | **`displayMedium` (45px) is too large for the balance** | Switch to `balanceHero` (40px, tighter tracking) — it's already defined in `AppTypography` exactly for this. |
| 4 | **Hero card income/expense chips show full currency** | Use `NumberFormat.compactCurrency` (e.g. `₹12.3K`) instead of full amount — the card is cramped on small screens. |
| 5 | **"Recent Transactions" section header** | Add a subtle left accent bar (`Container` 3px wide, primary color, 16px tall) before "Recent Transactions" and "Top Spending" headers — gives better visual hierarchy. |
| 6 | **Month Overview section** | The 3 stat cards sit tightly next to each other. Add the month's net (income − expenses) as a 4th card or a subtle summary line below the row. |
| 7 | **Top Spending progress bars** | Use `AppColors.cashOutGradient` on the bar fill instead of a flat `cashOut` color — small but premium detail. |
| 8 | **Greeting animation** | The greeting (`Good morning, Dhananjay 👋`) appears static. A one-time `FadeIn` + slight upward slide on first render would feel polished. |

---

## 📊 History / Transactions Page

| # | What | Suggestion |
|---|---|---|
| 1 | **Filter row alignment** | The `All / Cash In / Cash Out` chips and the filter icon button are vertically center-aligned but the chips feel slightly heavier visually. Give the filter icon button height: 36 (same as chip height) for optical balance. |
| 2 | **Empty state** | The empty state when no transactions match filters is plain text. Add an illustration emoji (e.g. 🔍) in a large circle with the `surfaceContainerLow` background + a "Clear filters" CTA button. |
| 3 | **Transaction tile date grouping** | Currently dates repeat inline on every tile. Group transactions under sticky date headers (`Today`, `Yesterday`, `Mon 5 May`) — this is the standard finance app pattern and massively improves scannability. |
| 4 | **Calendar view** | The calendar toggle exists but the selected-day event list below it appears unstyled. Apply the same card treatment as recent transactions. |
| 5 | **Search bar clear button** | The clear (✕) button on the search field is an `IconButton` with default ripple. Make it a small `GestureDetector` with just the icon for a tighter, cleaner look. |
| 6 | **Amount sign styling** | The `+/-` prefix on amounts uses the same `titleSmall` weight as the title. Use the dedicated `amountMedium` text style from `AppTypography` for better visual pop. |

---

## 📈 Analytics Page

| # | What | Suggestion |
|---|---|---|
| 1 | **Month selector looks generic** | Replace the plain white container with a subtle gradient background (`backgroundGradient`) or give it a primary-tinted border when it's the current month. |
| 2 | **Donut chart center text** | `titleMedium` (16px) for the total amount inside the donut is too small. Use `titleLarge` or `balanceSub` (20px) for the amount and keep `labelSmall` for the label. |
| 3 | **Bar chart colours** | The bar chart uses hardcoded `#2E7D32` (income) and `#E53935` (expense) — these are different from `AppColors.cashIn`/`cashOut`. Unify them with the design system tokens (with colorblind override). |
| 4 | **Category breakdown rows** | Budget limit rows with a progress bar look great. Rows *without* a limit show only "of ₹X total" — consider showing a coloured spending-intensity dot instead of leaving that space plain. |
| 5 | **Empty state** | The empty state is just centered text. Match the style of the Home page `_ErrorState` (icon + message + optional action). |
| 6 | **Section title "Income vs Expense (Last 6 Months)"** | This string is long. Shorten to `"Last 6 Months"` and add a legend row (already there) — the chart title can be the legend itself. |

---

## 💸 Dues Page

| # | What | Suggestion |
|---|---|---|
| 1 | **AppBar title uses default `TextStyle`** | The `Dues` title isn't using `AppTypography.titleLarge`. Apply `.copyWith(fontWeight: FontWeight.w700)` for consistency with other pages. |
| 2 | **Summary banner uses `Theme.of` colors** | `surfaceContainerLow` from Material theme instead of `AppColors.surfaceContainerLow` — inconsistency risk on theme changes. Use `AppColors` directly. |
| 3 | **Summary banner net position** | Show a net amount (`I Receive − I Owe`) between the two chips with a label like "Net Position" in a smaller style — gives users the most useful number at a glance. |
| 4 | **Due card "Settle" chip** | The green settle button on the right is small and easily missed. Make it a proper `FilledButton.tonal` or at least 28px tall with `borderRadius: 10`. |
| 5 | **Overdue card border** | Overdue cards have a red border tint — good. Add a thin `⚠️` badge in the top-right corner of the avatar circle instead of putting the warning inline in the date text. |
| 6 | **Tab bar indicator** | The tab indicator is the same `cashOut` red as the "I Owe" context. For "They Owe Me" and "Splits" the red indicator is semantically confusing. Use `primary` for the tab indicator uniformly. |

---

## 💰 Savings Page

| # | What | Suggestion |
|---|---|---|
| 1 | **Hero card uses `primaryGradient`** | The same gradient as buttons/chips. Use `heroCardGradient` (3-stop, deeper blue) instead to make it feel distinct and premium like the Home balance card. |
| 2 | **"Raw / −Wishlist / Net View" chip labels** | "Raw" and "Net View" are developer-speak. Rename to **"Total"**, **"−Wishlist"**, **"Net"** for clearer UX. |
| 3 | **Spendable balance toggle border** | When active, the `0.3 alpha` primary border is barely visible. Increase to `0.5` or use `primaryContainer` (solid) for the border when active. |
| 4 | **Update Total Savings dialog** | The `AlertDialog` uses a plain `OutlineInputBorder` — inconsistent with the app's rounded, borderless `fillColor` text fields elsewhere. Use the same style. |
| 5 | **Wishlist checklist empty hint** | The empty hint card with "No wishlist items yet" is fine but the `chevron_right` arrow isn't prominent. Add the primary color to it to signal it's tappable. |
| 6 | **Deduction breakdown** | The −All breakdown uses plain `Divider`s. Consider using a timeline-style vertical line with dots for "Raw → −Wishlist → −Cash → Net" — it visually tells the story of how savings are calculated. |

---

## 🔁 More Page

| # | What | Suggestion |
|---|---|---|
| 1 | **No user avatar / greeting** | The More page opens cold with just a list. Add a compact header card (name + email + avatar initials) like a mini version of the Profile page card — makes it feel personalised. |
| 2 | **Section headers ("FINANCE", "INSIGHTS")** | The uppercase, small-spaced labels are good. But they have no consistent left padding relative to the menu cards (`AppSpacing.xs` vs `AppSpacing.md`). Align left edges. |
| 3 | **Menu items all look identical** | Each feature icon has a unique `iconColor` — use this more boldly. The icon container background currently uses a fixed 12% alpha. At 15–16% it would read better. |
| 4 | **Sign Out item** | The destructive Sign Out action sits in the same card style as Profile. Move it below all cards as a standalone `OutlinedButton` with a red border — this matches standard Android/iOS patterns and visually separates the danger action. |
| 5 | **Chevron on all items** | Not all items need a `›` — the colorblind toggle is a `Switch` so it already has a control. Items with no navigation should not show a chevron (e.g. if a toggle were added to more items). |

---

## 👤 Profile Page

| # | What | Suggestion |
|---|---|---|
| 1 | **Avatar gradient card is hardcoded** | The gradient `[0xFF3861FB, 0xFF849AFF]` is hardcoded — use `AppColors.heroCardGradient` for consistency. |
| 2 | **"Member since" text is too small** | `fontSize: 11` at 60% white opacity is barely legible, especially outdoors. Bump to 12px / 70% alpha. |
| 3 | **Section cards are hardcoded dark/light** | `isDark ? Color(0xFF1C1C1E) : Colors.white` — use `AppColors.surfaceContainerLowest` instead so it respects the design system, not the raw Material brightness. |
| 4 | **Settings tiles use hardcoded `0xFF3861FB`** | The icon and focused border colors should use `AppColors.primary` so they'll update if the primary color ever changes. |
| 5 | **No logout button** | The profile page has no sign-out option — the user has to go back to More. At minimum add a "Sign Out" text button at the bottom of the Profile page as a convenience. |
| 6 | **Bottom sheet keyboard avoidance** | The `viewInsets.bottom` is applied correctly, but there's no `AnimatedPadding` — the sheet jumps when the keyboard appears. Wrap the sheet body in `AnimatedPadding`. |

---

## 🌐 Global / Cross-cutting

| # | What | Suggestion |
|---|---|---|
| 1 | **`Colors.transparent` backgrounds** | Several filter chips and interactive elements use `Colors.transparent` for their unselected background. On certain display calibrations this looks flat. Use `AppColors.surfaceContainer` with very low alpha for a subtle fill. |
| 2 | **Inconsistent border radii** | Cards use `BorderRadius.circular(20)`, `16`, `md (16)`, `AppSpacing.lg (24)` across pages. Standardise on 16 (md) for list cards and 20 for hero/banner cards. |
| 3 | **Loading states** | All pages use a bare `CircularProgressIndicator`. Consider Shimmer/skeleton placeholders for the key cards (balance, recent transactions) — it's a significant perceived performance improvement. |
| 4 | **SnackBar styling** | The Dues page snackbars use the default styling; the Profile page uses `behavior: floating` with custom shape. Standardise to a single app-wide floating snackbar helper. |
| 5 | **No dark mode support** | `AppColors` is entirely light-mode. The dues page uses `Theme.of(context)` colors while all others use `AppColors` directly — leading to visible dark/light inconsistencies. Either commit to light-only (set `themeMode: ThemeMode.light` in `MaterialApp`) or build a proper dark palette. |
| 6 | **`withValues(alpha: x)` vs `withOpacity(x)`** | Most of the codebase uses `withValues(alpha: x)` (new API) but a few places still use `withOpacity`. Standardise to `withValues`. |
