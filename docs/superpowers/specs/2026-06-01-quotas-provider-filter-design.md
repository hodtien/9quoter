# Quotas Provider Filter Design

## Goal

Add a compact provider filter to the Quotas tab so users can quickly switch between all quota accounts and a single provider such as Github or Codex.

## Selected direction

Use a compact icon chip row directly under the existing search field:

```text
All 54 · [Github icon] Github 1 · [Codex icon] Codex 53
```

This keeps `Quotas / Usage` as the primary navigation and treats provider selection as a local filter, not a second top-level tab system.

## Behavior

- `All` is selected by default.
- `All` keeps the current grouped provider layout.
- Selecting a provider shows only that provider's accounts.
- The search field continues to filter within the selected provider.
- Provider chips are generated from the same provider groups shown in the quota list.
- Counts show total accounts per provider.
- If provider count grows beyond available width, the chip row scrolls horizontally.

## Icon source

Provider icons must come from the 9router API data when available. The app should not hardcode provider-to-icon mappings as the primary source of truth.

If the API does not provide an icon for a provider, the UI may use the existing generic fallback presentation after confirming the current data shape.

## Visual treatment

- Active chip uses the same purple accent as the selected `Quotas` tab.
- Inactive chips use the existing dark panel surface with a subtle border.
- Chips include provider icon, provider display name, and account count.
- The `All` chip uses a neutral aggregate icon or no icon if that reads cleaner in the final SwiftUI implementation.
- Existing provider section headers remain visible in `All` mode with icon, active count, and total count.

## Components

- Provider filter state lives in the Quotas view state alongside `searchText`.
- A small provider filter chip row is extracted into its own SwiftUI view.
- Existing provider grouping remains the source for both the chip data and the quota sections.
- Account card rendering remains unchanged except for receiving already-filtered data.

## Data flow

1. Fetch quota accounts from the existing API flow.
2. Apply the existing inactive-account visibility rule.
3. Build provider filter chip models from all visible accounts before search is applied.
4. Apply the selected provider filter.
5. Apply search filtering within the selected provider scope.
6. Build provider groups from the resulting accounts.
7. Render grouped sections for the resulting provider groups.

## Empty states

- If a selected provider has no search matches, show the existing empty/filter result state.
- If provider data has no icon, use the existing fallback icon behavior.
- If there is only one provider, still show `All` plus that provider only if it helps clarity; otherwise the implementation may hide the row to avoid visual noise.

## Testing

- Verify default `All` mode matches the current grouped quota list.
- Verify selecting Github shows only Github accounts.
- Verify selecting Codex shows only Codex accounts.
- Verify search filters within the selected provider.
- Verify inactive accounts and `Show inactive` still behave correctly.
- Verify provider icons are sourced from API-provided data when present.
- Verify horizontal scrolling when provider chips exceed the available width.
