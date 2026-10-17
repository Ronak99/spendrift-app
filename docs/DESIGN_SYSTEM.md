# Design System: Spendrift

This is the visual source of truth for the Spendrift iOS app.
It documents the language that already exists in the product, not a proposed redesign.
New screens should look like they came out of the same box as Transactions, Accounts, Categories, Settings, and the editors.

**Reading this as:** a daily personal-finance ledger for people who log money quickly, with a quiet enamel-and-wash language, leaning toward Apple continuous squircles, inverted ink chrome, and one shared editor hero.

| Dial | Level | How Spendrift uses it |
| --- | --- | --- |
| **Creativity** | `6` | Distinct enamel chips and a top-right colour wash. Not editorial, not template SaaS. |
| **Density** | `5` | Daily-app balance. Grouped lists and a 3-up category tray, with room around heroes and empty states. |
| **Variance** | `5` | Systematic lists. Atmosphere is offset: wash and watermark live in the top-right, content stays left-aligned. |
| **Motion Intent** | `5` | Springs on type, selection, and press. No cinematic scroll hijacks. |

Do not import landing-page rules that fight this product.
Do not add a second accent family, a second chip shape, or a second Save treatment.

---

## 1. Visual Theme & Atmosphere

Spendrift feels like a small enamel box sitting on a grouped-list canvas.
The canvas is system grouped grey in light mode and near-black `#0A0A0B` in dark mode.
Every ledger tab, settings hub, and editor sheet shares the same climate:

1. A soft colour wash that pools in the top-right and fades into the canvas.
2. An ultra-light SF Symbol watermark in that same corner.
3. Glossy continuous squircles (enamel tiles) for category, account, and settings icons.
4. Ink-and-paper inverted chrome for Plus and Save.
5. A hero that *is* the record: name, amount, or idea sits on the wash, not in a card below it.

The light source is always top-leading.
Sheen on enamel tiles, the wash radial, and tile shadows all agree on that direction.
Nothing uses a generic black drop shadow.
Shadows are tinted with the enamel colour itself.

The product is dark-only.
Hierarchy is white on Night Canvas `#0A0A0B`.
Pure `#000000` is never a canvas.
Home and Settings wash, tab tint on those tabs, and Settings chrome use a single Spendrift Cyan accent `#06DEFF`.
Category colour is a separate, curated world.
It tints atmosphere and chips on Categories (and Accounts via user enamel), not primary buttons.

Onboarding and the Pro paywall stay in the same night family (NeatPass night).
They keep the wash-and-hero idea, but swap enamel squircles for circular liquid-glass plates.
Their Cyan Signal `#02dfff` is the sibling of Spendrift Cyan, not a second chrome accent on ledger screens.

---

## 2. Color Palette & Roles

Name colours by job.
Use the hex, not a nearby system equivalent, whenever the token is stored or painted as enamel.

### Canvas and ink

- **Ledger Canvas Light** (`UIColor.systemGroupedBackground`) - Grey page behind grouped lists, empty states, and summary headers.
- **Ledger Surface Light** (`UIColor.secondarySystemGroupedBackground`) - Raised grouped-list rows, inset cards, settings groups, date capsule fill.
- **Night Canvas** (`#0A0A0B`) - Page fill for every ledger tab, editor, and settings screen. Also the ink inside enamel glyphs.
- **Hero Ink** (`#111111`) - Light-mode titles, hero fields, inverted-chrome fill. Dark-mode inverted-chrome type.
- **Hero Paper** (`#FFFFFF`) - Light-mode inverted-chrome type. Dark-mode titles.
- **Inverted Chrome Fill Dark** (`#FFFFFF` at 92% opacity) - Plus and Save fill in dark mode.
- **Secondary Label** (`UIColor.secondaryLabel`) - Captions, meta, empty-state body, settings values.
- **Tertiary Label** (`UIColor.tertiaryLabel`) - Version footer, placeholders, disabled chrome.
- **Whisper Hairline** (`Color.primary` at 8% opacity) - Editor meta-row dividers.
- **Track Fill** (`Color.black` at 8% light / 30% dark) - Segmented picker well.

### Product accent (one)

- **Spendrift Cyan** (`#06DEFF`) - Home wash, Settings wash, Settings enamel rows, Explore wash, Feature Request enamel, Settings toggles, Capture/Help/Notifications chrome, and selected tab tint on Home and Settings.
This is the only chrome accent on ledger and settings surfaces.
Do not use it as a category colour.

### Enamel palette (the colour world)

These twelve swatches are the only colours a user is offered as category fills.
They also map account icons and name-based fallbacks.
Store them as `#RRGGBB` on the model.

| Token | Hex | Role |
| --- | --- | --- |
| Coral Ember | `#FF6B6B` | Food, default expense enamel, destructive inline text, Mastercard accounts |
| Warm Apricot | `#FF9F6B` | Transport / fuel name matches |
| Honey Gold | `#FFC94D` | Bills, education-adjacent gold, UPI accounts |
| Leaf Green | `#8BD17C` | Groceries, default expense hex in the editor, Cash accounts |
| Sea Mint | `#4FC3A1` | Salary / income default, sport, Home wash on Transactions |
| Sky Cyan | `#4FB8E8` | Travel, health name matches, Branch accounts |
| Periwinkle | `#6C8CFF` | Rent, Bank accounts, AccountEnamel fallback |
| Soft Violet | `#9B7BFF` | Entertainment, education, Visa in list enamel |
| Orchid | `#E27BD8` | Shopping |
| Blush | `#FF8FA8` | Beauty, baby |
| Clay | `#C3A17A` | Tax, savings / safe accounts |
| Slate Mist | `#8E9AA8` | Miscellaneous, uncategorized, unknown |

**Editor defaults**

- New expense category: Leaf Green `#8BD17C`.
- New income category: Sea Mint `#4FC3A1`.
- Uncategorized chip: Slate Mist `#8E9AA8`.
- Income amount in a ledger row: Sea Mint `#4FC3A1`.
- Expense amount in a ledger row: primary label, not Coral Ember.

**Name-to-swatch map** (when `colorHex` is nil): Food orange, Groceries green, Transport indigo, Bills blue, Rent/Salary/income family teal, Shopping/Clothing/Beauty/Baby pink, Electronics/Entertainment purple, Health red, Sport mint, Education yellow, Investments/Dividend cyan, Tax brown, Miscellaneous gray.
Custom names hash into the fallback set: orange, green, indigo, blue, teal, pink, purple, red, mint, cyan, brown.

### Semantic money (summary headers only)

Period summaries still use system semantic colour, not enamel:

- Expenses: system red.
- Income: system green.
- Savings / balance: green when >= 0, red when negative.

Do not replace these with enamel on the summary strip.
Do not use them as button fills.

### Onboarding / Pro night family

Use only on onboarding, the Pro paywall, and other forced-dark marketing sheets.

- **Night Studio** (`#0D0B14`) - Full-bleed backdrop.
- **Night Card** (`#1A1825`) - Feature card fill.
- **Cyan Signal** (`#02dfff`) - Onboarding/Pro accent, trial chip, selected plan, primary CTA fill on those sheets.
- **Seal Green** (`#34C759`) - Success rows, final onboarding CTA, Get Started hero glow.
- **Night Primary** (white) - Headlines.
- **Night Secondary** (white at 55%) - Body, legal links.
- Page glows: Welcome Cyan Signal, Shortcuts Soft Iris `#A78BFA`, Get Started Seal Green.

### Pro stats rings (quota only)

Concentric usage rings need four distinguishable hues, so they are allowed to leave Spendrift Cyan:

- `#EC4899`, `#22C55E`, `#22C3E6`, `#9B7BFF`.

Do not reuse this set as a second product accent.

### Banned colours

- Pure black `#000000` as a canvas or type colour.
- Generic AI purple/blue neon gradients, outer glows, mesh blobs on ledger screens.
- A second chrome accent (do not add orange Plus buttons, blue Save pills, or green empty-state CTAs).
- Mixing warm stone greys with cool zinc greys on the same screen.
- Painting enamel with raw SwiftUI `.orange` / `.green` when a palette hex exists. Enamel always comes from `CategoryPalette` or `AccountEnamel`.

---

## 3. Typography Rules

Spendrift uses the San Francisco system stack.
That is the correct choice here: this is a native iOS ledger, not a marketing site.
Do not introduce Inter, Geist, or a serif display face on product screens.

### Weights and jobs

- **Hero display** - 28pt bold, tracking `-0.8`. Editor name and amount fields. Explore titles. Feature Request title.
- **Empty-state title** - 22pt bold, tracking `-0.5`.
- **Row title** - 16pt semibold, primary colour, one line.
- **Row subtitle** - 12pt regular, secondary, one line.
- **Section label** - 12pt semibold, uppercase, tracking `+0.8`, secondary. Used above Color and Icon pickers.
- **Capsule / Save / empty CTA** - 14pt semibold.
- **Plus glyph** - 15pt semibold.
- **Meta line under a hero** - 13pt regular, hero ink at 60% opacity.
- **Settings value** - 14pt regular, secondary, tabular digits.
- **Summary caption** - `.caption`, secondary.
- **Summary figure** - `.headline`, tabular digits.
- **Picker segment** - 13.5pt semibold.
- **Icon-cell caption** - 10.5pt semibold, secondary.
- **Category grid name** - 12.5pt medium, up to two lines, minimum scale 0.85.
- **Primary account mark** - 11pt medium, secondary.
- **Version footer** - 12pt, tertiary, centered.
- **Onboarding / Pro display** - `.title` / `.title2` bold, white, centered. Not used on ledger screens.

### Numbers

Every money figure and clock uses `.monospacedDigit()`.
Summary headers round to whole units once a period has more than 10 transactions.
Do not set amount type in a proportional font.

### Tracking

Negative tracking belongs on large titles only (`-0.8` at 28pt, `-0.5` at 22pt).
Positive tracking belongs on microscopic uppercase labels (`+0.8`).
Do not track body copy.

### Copy register

Write short, specific, sentence-case UI.
Empty states name the missing object and the next action: "No transactions" / "Add one for April 2026." / "Add transaction".
Do not use "Elevate", "Seamless", "Unleash", "Next-Gen", or "Scroll to explore".
Do not put emojis in UI, code, or alt text.

---

## 4. Signature Materials

These three materials *are* the brand.
If a new screen is missing any of them, it is not in the system yet.

### 4.1 Colour wash (the top-right tint)

Implemented by `ColorWashBackground`.

Shape: a plain rectangle. The tint dies out in the gradient, so there is no corner radius.

Paint, back to front:

1. Linear gradient, top to bottom:
   - Enamel colour at 22% (light) / 30% (dark).
   - Enamel colour at 8% (light) / 10% (dark).
   - The same enamel at 0% opacity, so the wash fades into whatever canvas sits behind it.
2. Radial spotlight:
   - Center `UnitPoint(x: 0.85, y: 0.0)` (top-right).
   - Start radius 8, end radius 260.
   - Enamel colour at 28% (light) / 42% (dark) fading to the same enamel at 0% opacity.

Heights:

- Ledger tabs (Accounts, Categories): 360pt wash, pinned top.
- Settings atmosphere: 320pt.
- Transactions: 280pt, Spendrift Cyan wash, no watermark.
- Editors: full-bleed behind the hero, pulled up `-120pt` so the tint sits in the toolbar.

Home and Settings wash is static Spendrift Cyan.
Categories and Accounts follow the object in play:

- Categories: first visible category enamel, or the type default.
- Accounts: primary account enamel, else first account, else Periwinkle fallback.
- Transactions (Home): Spendrift Cyan `#06DEFF`.
- Settings / Explore / Feature Request: Spendrift Cyan `#06DEFF`.
- Editors: the selected category, account, or request accent.

### 4.2 Ultra-light watermark (the image)

A decorative SF Symbol, never tappable, hidden from VoiceOver.

- Weight: `.ultraLight`.
- Size: **176pt** on tabs and Settings, **160pt** on editors.
- Colour: Hero Ink / white at **8%** light, **10%** dark.
- Placement: `ZStack(alignment: .topTrailing)`.
- Offset: tabs `x: 40, y: -28`. Editors `x: 36, y: 8`.

The glyph matches the screen:

- Categories: first visible category icon, or the type default.
- Accounts: primary (else first) account icon, or `building.columns`.
- Settings: `gearshape`.
- Explore: current carousel page icon, springing when the page changes.
- Editors: the live category / account / lightbulb icon.

Transactions currently ships the wash without a watermark.
If that tab gains one, use `tray.fill` or the period's dominant category icon, at the same 176pt recipe.
Do not invent a new size or opacity.

### 4.3 Enamel squircle (category icons)

Implemented by `CategoryEnamelTile`.
This is the only icon plate on ledger, settings, empty states, and editor heroes.

Geometry:

- Always square.
- Continuous corner radius **33% of the side** (`side * 0.33`).
  - 80pt tray chip → ~26pt radius.
  - 70pt editor / empty hero → ~23pt (editors that inline the recipe use a fixed 23pt).
  - 42pt list / settings chip → ~14pt.
  - 88pt empty-state / Explore carousel → ~29pt.

Finish, back to front:

1. Solid enamel fill.
2. Sheen: linear gradient white 35% → clear, from `.topLeading` to `UnitPoint(x: 0.55, y: 0.7)`.
3. Hairline: white 28%, **0.8pt** `strokeBorder`.
4. Glyph: SF Symbol, semibold, size `max(14, side * 0.38)`, colour Night Canvas `#0A0A0B`.
5. Shadow (hero / tray / empty / Explore center only): enamel colour at 32%, radius `side * 0.12`, y `side * 0.08`.
   List and settings chips set `showsShadow: false`.

Sizes in product:

| Surface | Side |
| --- | --- |
| Category tray | 80 |
| Editor hero, Feature Request hero | 70 |
| Empty state, Explore carousel | 88 (Transactions empty uses 72) |
| Transaction row, Account row, Settings row | 42 |

Press: `CategoryTilePressStyle` scales to 0.96 with spring `response: 0.28, dampingFraction: 0.72`.

Do not put icons in circles on ledger screens.
Do not outline a squircle with a grey stroke instead of the white hairline.
Do not invert the glyph to white. Ink on enamel is the system.

---

## 5. Component Stylings

### 5.1 Plus button (toolbar add)

Circular inverted chrome.
Shared by Transactions, Accounts, and Categories.

- Glyph: `plus`, 15pt semibold.
- Frame: **32 × 32**.
- Shape: `Circle()`.
- Fill: Hero Ink `#111111` in light, white 92% in dark.
- Glyph colour: white in light, Hero Ink in dark.
- Placement: trailing navigation bar.
- iOS 26: `.sharedBackgroundVisibility(.hidden)` so Liquid Glass does not wrap a second plate around it.

Accessibility label names the object: "Add transaction", "Add account", "Add category".

Do not use `plus.circle.fill`.
Do not tint Plus with Spendrift Cyan or enamel.

### 5.2 Save, Done, Send (toolbar confirm)

Capsule inverted chrome.
Same ink/paper pair as Plus.
Shared by category, account, and transaction editors, Feature Request ("Send"), and Notifications ("Done") via `SettingsCapsuleLabel`.

- Label: 14pt semibold.
- Padding: 16 horizontal, 8 vertical.
- Shape: `Capsule()`.
- Fill / type: identical to Plus.
- Placement: `.confirmationAction`.
- iOS 26: hide the shared toolbar background.

Disabled (account editor): opacity 0.4, `.disabled(true)`.
Other editors currently stay optically enabled and no-op when invalid. Match the account treatment when touching those screens.

Do not use bordered text "Save".
Do not fill Save with Spendrift Cyan or enamel.
Do not put Save in the hero.

### 5.3 Screen-level primary button

`SettingsPrimaryButton` and empty-state capsules.

- Empty-state CTA: same type and padding as Save, capsule, inverted chrome. Label is a verb + noun ("Add transaction").
- Full-width primary (Explore "Add shortcut"): 14pt semibold, 8pt icon gap, 14pt vertical padding, max width, capsule, inverted chrome. Icon uses `.contentTransition(.symbolEffect(.replace))` when the page changes.

Onboarding / Pro CTAs are the night-family exception: full-width capsule, 16pt vertical padding, `.headline`, Night Studio type on Cyan Signal or white / Seal Green fill.

### 5.4 Close

Circular chrome plate. Same geometry as Plus, secondary weight, because Close never
competes with the confirm action.

- Glyph: `xmark`, 14pt semibold.
- Frame: **32 × 32**.
- Shape: `Circle()`.
- Fill: Hero Ink 8% in light, white 14% in dark.
- Glyph colour: Hero Ink 70% in light, white 80% in dark.
- Placement: `.cancellationAction`, leading navigation bar.
- iOS 26: `.sharedBackgroundVisibility(.hidden)`, same as Plus and Save.

Accessibility label is "Close"; the identifier stays `xmark` for UI tests.

Every dismissible sheet carries one, because drag-to-dismiss is unreliable on current
iOS. Use `CustomSheetCloseToolbarItem()` inside `.toolbar { }` - it owns the placement and
the iOS 26 branch, so no call site repeats them. Sheets with no navigation bar
(`ProPaywallView`, `AppUpdateSheet`) overlay `CustomSheetCloseButton` in the top
leading corner instead. Sheets that should carry the native glass cross use
`LiquidGlassSheetCloseToolbarItem()` instead. The transaction editor is the current case.

Blocking presentations are the exception and stay closeless: onboarding, and mandatory
update. UIKit pickers (photo library, camera, mail, share) keep their own system chrome.

Do not draw a second close on editor heroes.
Do not use `xmark.circle.fill`, and do not give Close the inverted Plus fill.

### 5.5 Segmented picker

`ChromeSegmentedPicker`.
Two-up control for Expense / Income, Primary / Standard, and any future pair.

- Well: continuous rounded rect, corner 13, 3pt padding, black 8% (light) / 30% (dark).
- Segment: continuous rounded rect, corner 10, 9pt vertical padding, 13.5pt semibold.
- Selected fill: Hero Ink light / white 90% dark.
- Selected type: white light / Hero Ink dark.
- Unselected type: hero ink at 70%.
- Motion: spring `response: 0.42, dampingFraction: 0.86`, skipped when Reduce Motion is on.
- Haptic: `.selection`.

Do not use `Picker` with `.segmented` on these surfaces.

### 5.6 Date capsule

`CapsuleDateSelector` on Transactions.

- Full pill of Ledger Surface.
- 16pt vertical, 20pt horizontal padding.
- Headline semibold period title, chevrons in primary.
- Press scale 0.94, spring `response: 0.25, dampingFraction: 0.6`.
- Double-tap title: jump to current period.
- Long-press: jump sheet.

Analytics toggle sits inside the same capsule.
Do not restyle this as a segmented control.

### 5.7 Ledger rows

`TransactionListItem`, `AccountListItem`, `SettingsListItem` are one row:

- Enamel 42, `showsShadow: false`.
- 14pt gap, 6pt horizontal row padding.
- Title 16 semibold, subtitle 12 secondary, 3pt stack gap.
- Trailing: tabular money, settings value, or chevron at primary 28%.
- Position padding via `listItemPositioned`: first/only 12/12, middle 6/6, last 6/12.

Grouped lists use `.insetGrouped`, hidden scroll background, `.softScrollEdge()` on iOS 26.
Row chrome is the system grouped surface, not a custom card.

Settings chevron: 11pt semibold, primary 28% (`SettingsTokens.chevron`).
Toggles tint Spendrift Cyan.

### 5.8 Editor hero

Category, Account, Transaction, and Feature Request sheets share one layout.

```
[enamel 70]  [28pt field]
             [13pt meta]
[ChromeSegmentedPicker]
colour wash + 160pt watermark behind
```

- Horizontal padding 20, top 8, bottom 26.
- Field tracking `-0.8`, caret tinted Hero Ink / white.
- While the hero field is focused, the details block drops to 45% opacity (200ms).
- Navigation bar is transparent. Toolbar colour scheme follows appearance.

Transaction hero field is the amount (currency symbol 22 bold at 42% opacity + 28 bold amount).
Category / Account hero field is the name.
Feature Request hero is a static title, not a field.

Details below the hero are either:

- Uppercase section + grid (category colour/icon, account icon), or
- Meta rows with a 1pt whisper divider (transaction category/account/when/note, account balance).

### 5.9 Colour chips and icon cells

Category colour grid: 7 columns, 11pt gutters.
Each chip is a continuous rounded rect, corner 14, height 40.
Selected: 2pt stroke of the same hex, padded -4 (halo, not an inner border).
Custom slot: plus glyph, or checkmark on Night Canvas when a custom colour is active.

Icon cells (`CategoryIconCell`, `AccountIconCell`):

- Continuous rounded rect, corner **18**.
- Fill: enamel 15% when selected, primary 6% when idle.
- Selected stroke: enamel, 1.5pt.
- Glyph 22 regular, enamel when selected, primary 62% when idle.
- Optional 10.5 semibold caption.

Custom colour sheet: 56pt continuous 18pt preview, 6×3 shade grid of continuous 12pt cells, capsule hue slider, medium detent, Night Canvas `#16161A` in dark.

### 5.10 Empty states

New ledger empty states (Transactions, Accounts, Categories):

1. Enamel tile (72-88) of the object’s default icon and colour.
2. 22pt bold title.
3. 15pt secondary sentence.
4. Inverted capsule CTA.

Do not use the legacy `EmptyStateView` (64pt grey symbol, accent rounded-rect button) on new work.
Category and Account drill-in lists still use it; migrate them to the enamel recipe when those screens are touched.

### 5.11 Floating capture chrome

Voice bar and receipt processing sit above the tab bar:

- Material: `.ultraThinMaterial`.
- Voice: continuous rounded rect, corner 24, black shadow 12% radius 12 y -4, 16pt side inset.
- Receipt: capsule, shadow 12% radius 10 y 4.
- Stop control: system red. Cancel: hierarchical secondary.
- Errors: orange hierarchical symbol, not enamel.

Banners (SMS import) are material rows with a hierarchical message icon, not enamel chips.

### 5.12 Analytics cards

Analytics is the one ledger surface that still uses 20pt continuous cards of Ledger Surface, system chart colours, and semantic summary tints.
When this screen is redesigned, reuse enamel for category legend rows and the wash atmosphere already behind Transactions.
Do not introduce a third card radius.

### 5.13 Category find field

`CategoryFindField` shares the `ChromeSegmentedPicker` well. Not system `.searchable`.

- Well: continuous rounded rect, corner 13, Track Fill (black 8% light / 30% dark).
- Height: 44pt min. Horizontal padding 14. Magnifying glass 14 semibold at 42% hero ink.
- Field: 14 regular, Hero Ink / white, caret tinted the same. Placeholder "Find a category".
- Clear: hierarchical `xmark.circle.fill` at 42% hero ink, reserved in-layout even when empty.
- No cyan tint.

**Categories tab:** one chrome row. Search is a 44pt track-fill circle beside `ChromeSegmentedPicker`, same well as the type control. Opening it swaps the picker for the find field and shows every category. The glyph becomes `xmark` to close. Search matches name, then icon label and keywords (`CategorySearch`). Miss uses the enamel empty recipe and can create from the query.

**Category picker sheet:** find field stays above the type-filtered grid.

Do not restyle this as a pill, a material drawer, or `.searchable`.
Do not stack the find field under the type picker on Categories.

---

## 6. Layout Principles

### Shell

Four tabs plus a search-role Speak control that never becomes a fifth page.
Tab icons: `house.fill`, `creditcard`, `folder`, `gearshape.fill`, `mic.fill`.
Tab tint follows the visible tab's atmosphere: Spendrift Cyan on Home and Settings, user enamel on Accounts and Categories.
Speak mic is pre-tinted (cannot rely on tab foreground):

- Active: rgb(0.96, 0.47, 0.45).
- Disabled: tertiary label.

Inline navigation titles.
Hidden toolbar background on every colour-wash screen.
Canvas ignores the safe area so the wash reaches the status bar.

### Spacing scale (what the app actually uses)

4, 6, 8, 10, 11, 12, 14, 16, 20, 24, 26, 28, 32, 40, 44.

Heroes: 16 between enamel and type, 26 under the picker, 20 side inset.
Grids: 11 (editors) or 12-16 (category tray).
Lists: 14 icon gap (`SettingsTokens.iconGap`).
Empty states: 16 stack, 24 side inset.
Section stacks: 28.

### Grids

- Categories tray: 3 flexible columns, 16 gutter, 12 row gap.
- Featured icons: 4 columns.
- Icon browser: 5 columns.
- Account icons: 3 columns.
- Colour chips: 7 columns.
- Analytics summary: 2 columns of 20pt cards.

A 3-up category tray is correct here. It is a tray of enamel objects, not a marketing feature row.

### Shape scale (lock this)

| Token | Value | Use |
| --- | --- | --- |
| Enamel squircle | `side * 0.33` continuous | Category / account / settings chips |
| Editor enamel (inline) | 23 continuous | 70pt hero tiles that have not switched to `CategoryEnamelTile` |
| Icon cell | 18 continuous | Icon pickers |
| Colour chip | 14 continuous | Palette grid |
| Picker well / thumb | 13 / 10 continuous | ChromeSegmentedPicker |
| Wash | none | ColorWashBackground fades to transparent || Voice plate | 24 continuous | Recording bar |
| Analytics card | 20 continuous | Summary / chart cards |
| Screenshot clip | 14 continuous | Feature Request image |
| Plus | Circle 32 | Toolbar add |
| Close | Circle 32 | Sheet dismiss |
| Save / primary / date | Capsule | Confirm, empty CTA, date selector |

Do not add a new radius without a job.

### iOS 26 chrome

- `.scrollEdgeEffectStyle(.soft)` on scrolling content (`softScrollEdge()`).
- `.safeAreaBar` for pinned headers (date capsule, account summary). Pre-26: `safeAreaInset` plus `.bar`.
- Hide shared toolbar backgrounds on Plus, Save, and Close so the custom plate is the only one.

---

## 7. Motion & Interaction

Default spring: `response: 0.42, dampingFraction: 0.86`.
Used for type picker, wash/watermark changes, settings disclosure chevron, banner dismiss, Explore page.

Other springs:

- Tile press: `0.28 / 0.72`.
- Date title press: `0.25 / 0.6`.
- Gesture hint: `0.4 / 0.78`.
- Voice bar: `.bouncy`.
- Analytics toggle: 200ms ease-in-out.
- Onboarding page / sheet tint: 350-480ms ease-in-out.
- Pro rings: 850ms easeOut, 70ms stagger, skipped under Reduce Motion.

Rules:

- Honour Reduce Motion on pickers and Pro rings.
- Animate transform and opacity, not layout frames.
- Selection on the type picker fires `.sensoryFeedback(.selection)`.
- First-transaction reminder and onboarding completion use notification haptics.
- Do not add infinite pulse, marquee, or scroll-hijack on ledger screens.
- Explore carousel is the one place a hero enamel scales and fades with drag (`scale 1 → 0.54`, `opacity 1 → 0.26` by distance). Neighbors stay visible. Rubber-band 0.3 past the ends.

---

## 8. Iconography

SF Symbols only, one family.
Filled variants inside enamel (`basket.fill`, `house.fill`, `creditcard.fill`).
UltraLight only for watermarks.
Semibold for enamel glyphs, Plus, chevrons, Save.

Account icons stay in the enamel world via fixed hexes:

| Icon | Label | Hex (editor `enamelHex`) |
| --- | --- | --- |
| `building.2` | Bank | `#6C8CFF` |
| `bolt.circle` | UPI | `#FFC94D` |
| `indianrupeesign.circle` | Rupee | `#4FC3A1` |
| `building.columns` | Branch | `#4FB8E8` |
| `creditcard` | Card | `#FF6B6B` |
| `creditcard.fill` | Visa | `#6C8CFF` editor / `#9B7BFF` list (`AccountEnamel`) |
| `banknote` | Cash | `#8BD17C` |
| `wallet.pass` | Wallet | `#9B7BFF` editor / `#FF9F6B` list |
| `lock.circle` | Safe | `#C3A17A` |
| `questionmark.circle` | Other | `#8E9AA8` |

When unifying Visa and Wallet, keep the editor hex and point `AccountEnamel` at it.

Onboarding heroes may use the bundled `OnboardingHeroMark` asset on a circular liquid-glass plate.
That plate is not enamel.
Do not put `OnboardingHeroMark` on ledger tabs.

---

## 9. Screen Recipes

Use these as the checklist when adding a screen.

### Ledger tab

1. Night Canvas or Ledger Canvas Light.
2. Colour wash (height 280-360) in the object’s enamel.
3. Ultra-light watermark, top-trailing (Transactions may omit until it is given one).
4. Inline title, hidden bar background.
5. Trailing Plus circle, inverted chrome, shared-background hidden on iOS 26.
6. Inset grouped list or 3-up enamel tray.
7. Matching empty state (enamel + 22pt title + capsule CTA).

### Editor sheet

1. Same canvas.
2. Hero: 70 enamel + 28pt field + 13pt meta + segmented picker.
3. Wash + 160pt watermark, offset top-trailing, pulled `-120`.
4. Trailing Save capsule.
5. Details: uppercase labels + continuous-18 cells, or whisper-divider meta rows.
6. Focus dims the details to 45%.

### Settings hub / drill-in

1. `SettingsScreen` + `SettingsAtmosphere` (Spendrift Cyan wash, gear or screen watermark).
2. `SettingsListItem` enamel at 42, Spendrift Cyan fill.
3. Capsule labels for Done / Send.
4. `SettingsPrimaryButton` for page-level actions.

### Onboarding / Pro (night family only)

1. Night Studio + top-heavy accent wash (`OnboardingSheetAtmosphericBackground`).
2. Circular liquid-glass plate, glow rings, Cyan Signal or page glow.
3. Dark card `#1A1825` for feature lists.
4. Full-width capsule CTA in white, Seal Green, or Cyan Signal.
5. Forced dark colour scheme.

---

## 10. Layout Containment & Responsive

This is an iPhone-first SwiftUI app.
There is no 1440px marketing grid.

- Side inset 20 on editors and summaries, 24 on trays and empty states.
- Category names may scale to 0.85 rather than wrap under the chip.
- Money trails `minimumScaleFactor(0.8)` / amounts in the hero `0.45`, still one line.
- Touch targets: Plus is 32pt visually; keep the toolbar hit area at system size. Empty CTAs and Save padding already exceed 32pt height. Do not ship 32pt text-only buttons in scrolling content.
- Never use `h-screen`. Sheets and tabs use the system safe area plus `ignoresSafeArea` only on the wash canvas.
- Reduce Motion disables picker springs and Pro ring fills.

Widgets and Live Activities sit outside this enamel system today.
If they are redesigned, reuse enamel at 42 and inverted capsules, not a new glyph-in-circle language.

---

## 11. Motion Intent for Implementation

Stitch-style reminder for anyone building a new surface:

- Physics: spring `0.42 / 0.86` unless a recipe above specifies otherwise.
- Lists do not stagger-in on appear. The ledger is a tool; content is already there.
- The wash and watermark *do* spring when the selected type, account, or Explore page changes.
- Press feedback is scale, not opacity (except picker segments, which dip to 88%).
- Animate `transform` and `opacity` only.

---

## 12. Anti-Patterns (Banned)

- A second chip shape (circles, rounded-rect 8pt, squircle with a different ratio).
- A second Plus or Save (blue pills, green checkmarks, `plus.circle.fill`, text-only trailing buttons).
- Spendrift Cyan as a category fill or Save fill.
- Enamel glyph in white or primary, instead of Night Canvas `#0A0A0B`.
- Wash without a top-right radial (flat linear only).
- Watermark at Regular or Semibold weight, or at a random size.
- Pure `#000000` canvases.
- AI purple neon, mesh blobs, or outer glow on ledger chrome.
- Inter, Geist, or serif display on product UI.
- Emojis in UI.
- "Scroll to explore", bouncing chevrons, version stamps in heroes.
- Legacy `EmptyStateView` on any new screen.
- System `.segmented` Picker on type / role controls.
- System `.searchable` on Categories or the category picker. Use `CategoryFindField`.
- Drop shadows in pure black on enamel. Tint them with the fill.
- Mixing onboarding Cyan Signal into Plus, Save, or enamel chips.
- Three equal marketing cards. (The category tray is not this.)
- Centered editor heroes. The enamel stays leading, type stays left of the remaining width.
- Invisible button type. Inverted chrome is high-contrast on purpose: dark-on-light or light-on-dark, never white-on-white.

---

## 13. Token Map (where to change things)

Change tokens here, not by restyling one screen.

| Token | Source |
| --- | --- |
| Spendrift Cyan atmosphere, list canvas, list surface | `Theme/AppTheme.swift` |
| Hex parser | `Extensions/Color+Extensions.swift` |
| Enamel palette, defaults, name suggestions | `Utilities/CategoryPalette.swift` |
| Name fallback swatches | `Utilities/ColoredCategories.swift` |
| Wash + top-right radial | `Views/Components/ColorWashBackground.swift` |
| Enamel squircle | `CategoryEnamelTile` in `Views/Categories/CategoryGridItem.swift` |
| Account enamel | `AccountEnamel` in `Views/Accounts/AccountListItem.swift` and `AccountIcon.enamelHex` |
| Ink chrome, wash canvas, hero type | `SettingsChrome` in `Views/Settings/SettingsComponents.swift` |
| Capsule Save label, full-width primary, atmosphere | `SettingsCapsuleLabel`, `SettingsPrimaryButton`, `SettingsAtmosphere` |
| Type picker | `Views/Components/ChromeSegmentedPicker.swift` |
| Category find field | `CategoryFindField` in `Views/Categories/CategoryFindField.swift` |
| Category search matching | `Utilities/CategorySearch.swift` |
| Row padding | `Views/Components/ListItemPositionedModifier.swift` |
| Soft scroll edge / pinned headers | `Views/Components/ScrollEdgeStyle.swift` |
| Close | `Utilities/SheetCloseButtons.swift` |
| Onboarding / Pro night family | `Views/Onboarding/OnboardingComponents.swift` |

---

## 14. Open Gaps

Documented so new work closes them instead of copying the wrong variant.

1. **Visa / Wallet enamel** - `AccountIcon.enamelHex` and `AccountEnamel` disagree. Unify on the editor hex.
2. **Transaction and Category hero tiles** still inline the enamel recipe instead of `CategoryEnamelTile`. Route them through the shared tile.
3. **Transactions watermark** is missing. Add the 176pt ultra-light glyph if the tab should match Accounts and Categories.
4. **Save disabled state** is only on the account editor. Transaction and category Save should dim the same way.
5. **`EmptyStateView`** is the pre-enamel empty state. Replace remaining call sites.
6. **Analytics** still uses a sequential system palette for pie slices instead of `CategoryEnamel.color(for:)`.
7. **Onboarding Cyan Signal vs ledger Spendrift Cyan** are siblings. Do not "unify" them by painting ledger Plus buttons cyan.
8. **Widget chrome** is still generic accent pills. Bring enamel and inverted capsules across when widgets are touched.

---

## 15. Pre-flight for a new screen

- [ ] Canvas is Night Canvas `#0A0A0B`, not pure black.
- [ ] Top-right wash uses `ColorWashBackground` and enamel (or Spendrift Cyan on Home and Settings).
- [ ] Watermark is ultra-light 160/176, 8-10% hero ink, top-trailing, not in VoiceOver.
- [ ] Icons sit in `CategoryEnamelTile` (33% continuous radius, sheen, white hairline, `#0A0A0B` glyph).
- [ ] Plus is a 32pt inverted circle. Save / primary is an inverted capsule. Same ink/paper pair.
- [ ] Every dismissible sheet has `CustomSheetCloseToolbarItem()`, unless it blocks on purpose.
- [ ] iOS 26 toolbar shared background is hidden on those controls.
- [ ] Type control is `ChromeSegmentedPicker`, not `.segmented`.
- [ ] Row titles are 16 semibold. Money is tabular.
- [ ] Empty state is enamel + 22pt title + inverted capsule.
- [ ] Motion is the 0.42/0.86 spring, or a recipe listed above.
- [ ] No second accent, no emoji, no Inter, no circular category icons.
- [ ] Dark-only. Contrast on Plus/Save holds on Night Canvas.

If a single box cannot be ticked, the screen is not in the system yet.
Fix it before shipping.

---

## 16. Home Shell

One screen carries the app.
`HomeShellView` holds the Spendrift Cyan editor-hero wash behind the status bar and title, a search bar and a tab strip that pin together, four panes, and a bottom tray.
Sections 1 to 15 still describe the editors, sheets and enamel language; this section describes the chrome around them, and its surfaces win wherever the two disagree.

**Surfaces.** Every value is a token on `AppTheme`, defined once with a dark and a light resolution.

| Token | Dark | Role |
| --- | --- | --- |
| `canvas` | `#17171C` | Page behind every pane. |
| `card` | `#202027` | Raised block: Home cards, ledger rows, search results. |
| `cardAlternate` | `#2B2B33` | Glyph plates, chips, the current month in the picker. |
| `searchField` | `#26261F` | Fill of the Home search bar, which sits on the wash. |
| `actionBackground` / `actionForeground` | `#FFFFFF` at 92% / `#111111` | The one primary action on screen. |

**Header.** The title, search bar and tab strip sit above the pane, outside its scroll view, so the status bar and header always wear the wash and nothing can scroll out from under them.
Only the title row collapses as the pane scrolls, the way a title does elsewhere in the app; it returns once the pane is back near the top, and switching tabs always starts there.
The header's background is `ColorWashBackground(color: AppTheme.atmosphere, isDark:)`, the identical top-down tint and top-right radial bloom the editor heroes use, extended under the status bar with `ignoresSafeArea(edges: .top)`.
The selected Transactions tab reads as its month and the selected Categories tab as its type, and a second tap on either opens the matching picker.
Nothing in a title bar creates a record: Settings is the only control up there.

**Creating.** The bottom pill reads "Add transaction" on every tab and is the only control that makes one.
Accounts and Categories each open with a dashed slot, first in the list so a long list never hides it, and each slot creates the thing its own list holds.
The tray orb holds the slower paths: scan a receipt, import a statement, bank SMS.

**Home is analytics.** The hero is the month's spend and its cumulative curve, bleeding to both gutters with no card around it.
Under it sit the persona, four stat tiles, budgets, insights, where it went, and three recent rows.
Every block recomputes for the month picked in the hero.

**Budgets.** Two independent caps: one for the month, one per expense category.
Income is never capped.
A cap repeats every month until changed and applies to past months when looked back on.
The total lives in `MonthlyBudget.total`, a category's in `TransactionCategory.monthlyBudget`, and a bar in the entity's own colour shows spend against it, turning red past the cap.

**Search is global.** Tapping the bar pushes a screen; the active tab never influences the results.
Back lives inside the field, with the query and a clear plate, and nothing else.
