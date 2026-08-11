# Cairn

Cairn is a Flutter habit-tracking app where each completion is proven with an AI-verified photo. Completed habits add stones to task-specific cairns, earn metres, build streaks, and advance the user's rank.

The app is local-first, with drift-backed offline data, Supabase account and record sync, a server-side proof verifier, RevenueCat premium entitlements, and local notifications.

## Contributing

[AGENTS.md](AGENTS.md) is the sole canonical instruction source for all human and AI contributors. It records the architecture, domain invariants, phase history, and human-gated constraints.

The `.dc.html` files in `design/` are canonical for all real UI. Do not invent or restyle screens outside those designs.

Before handing off a change, inspect the actual diff and run:

```sh
flutter analyze
flutter test
```
