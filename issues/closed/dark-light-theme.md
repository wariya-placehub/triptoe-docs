# Dark/Light Theme Support

## Status: Implemented
## Completed: 2026-04-05

## Architecture

### ThemeProvider (`src/providers/ThemeProvider.tsx`)
Single source of truth for all colors. Two flat objects (`lightColors`, `darkColors`) with identical keys. No shade-indexed objects — every token is a semantic flat string.

```tsx
const colors = useColors();
// colors.bg, colors.text, colors.guideAccent, colors.btnPrimary, etc.
// colors.isDark — boolean flag for conditional logic
```

### How It Works
1. `ThemeProvider` wraps the app in `_layout.tsx`
2. Uses `useColorScheme()` from React Native to detect device theme
3. Returns the appropriate color set via `useColors()` hook
4. `isDark` boolean included in the return value for non-color conditional logic (e.g., map styles, image opacity)

### Token Categories

| Category | Tokens | Purpose |
|----------|--------|---------|
| Surfaces | `bg`, `surface`, `border`, `headerBg`, `stickyFooterBg`, `modalOverlay` | Page/card/modal backgrounds |
| Typography | `text`, `textSecondary`, `textMuted`, `white` | Text hierarchy |
| Accents | `guideAccent`, `guestAccent` | Text, icons, links per role |
| Buttons | `btnPrimary`, `btnOcean` | Button backgrounds (dark enough for white text) |
| Highlights | `subtleBg`, `highlightBg`, `highlightActiveBg`, `guestHighlightBg`, `guestChipBg`, `successBg` | Subtle tinted backgrounds |
| Status | `success`, `warning`, `completed`, `pinOrange`, `danger` | Status indicators |
| Messaging | `guideMessageBg`, `guideMsgBg`, `guestMessageBg`, `guestMsgBg`, `msgText` | Message bubbles |
| Utility | `star`, `guestPin`, `myLocationPin`, `tipGreen`, `loader`, `placeholder` | Specific use cases |

### Color Values

| Token | Light | Dark |
|-------|-------|------|
| `bg` | `#e5e7eb` | `#0f172a` |
| `surface` | `#ffffff` | `#1e293b` |
| `border` | `#d1d5db` | `#334155` |
| `headerBg` | `#ffffff` | `#293548` |
| `text` | `#333333` | `#f1f5f9` |
| `textSecondary` | `#666666` | `#94a3b8` |
| `textMuted` | `#999999` | `#64748b` |
| `guideAccent` | `#1A4B7D` | `#75a5cf` |
| `guestAccent` | `#82c4da` | `#a5dbed` |
| `btnPrimary` | `#1A4B7D` | `#1A4B7D` |
| `btnOcean` | `#5eaec8` | `#5eaec8` |
| `success` | `#4CAF50` | `#a5d5ab` |
| `warning` | `#d97706` | `#fbbf24` |
| `danger` | `#E53935` | `#f87171` |

### Non-Component Code
`STATIC_COLORS` in `src/constants.ts` provides `guideAccent` and `guestAccent` for services/hooks that can't use React hooks (e.g., background location foreground service notification color).

## Design Decisions

### Why Not NativeWind `dark:` Classes
The app uses inline `style={{ color: colors.text }}` instead of Tailwind `dark:` variants. This was a deliberate choice:
- Single source of truth (ThemeProvider) vs. scattered `dark:` classes across 40+ files
- Easier to add new themes (just add another color object)
- No NativeWind/CSS variable configuration needed
- `isDark` flag available for non-color conditional logic

### Button Background vs. Accent Text
`guideAccent` (`#75a5cf` dark) is bright enough for text readability but too light for button backgrounds with white text. `btnPrimary` (`#1A4B7D`) stays dark in both themes for white text contrast. Same pattern for guest: `guestAccent` for text, `btnOcean` for buttons.

### Image Opacity
Large images (cover photos, thumbnails) use `opacity: 0.95` in dark mode to reduce the "glow" effect of bright images against dark backgrounds. Applied in `TourSessionHeader` and `GuideTourTemplateCard`.

### Google Maps Dark Mode
`DARK_MAP_STYLE` constant in `TourMapView.tsx` applies Google Maps night theme via `customMapStyle` prop when `colors.isDark` is true. Applied to both inline and fullscreen map views.

### Active Tour Banners
In dark mode, status-tinted backgrounds (`activeBg`, `checkInBg`) use the same `surface` color with a colored left border accent instead of tinted backgrounds that looked muddy.

## Open Items

### Tailwind CSS Variables Integration
Currently 100% JS-inline styles. Could map semantic tokens to CSS variables in `global.css` so NativeWind classes like `text-text` work, but this adds configuration complexity for minimal benefit since the inline approach is working reliably. Consider if NativeWind v4+ makes this easier.

### Splash Screen
Splash screen background is static. Consider matching the theme or using a neutral dark color that works in both modes.
