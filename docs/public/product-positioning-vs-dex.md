# Galaxy Bridge vs Samsung DeX (product logic)

Galaxy Bridge is a **Mac↔Galaxy companion bridge**, not a DeX clone.
Treating “UI should look like DeX” as a requirement confuses two products.

## Concepts (do not mix)

| Term | DeX | Galaxy Bridge |
|------|-----|----------------|
| Desktop | Phone OS desktop on an external display + launcher/apps | Mac-native companion app (pair, mirror, files, gallery, notifications) |
| Session owner | Samsung / Android DeX stack | Mac app + paired phone helper |
| Screen | Primary workspace metaphor | One capability among others (mirror window) |

## Faulty arguments to avoid

1. **Homonymy / four terms** — “desktop” means different things in DeX vs Bridge.
2. **Ignoratio elenchi** — screen mirroring does not prove product identity with DeX.
3. **Hasty generalization** — one empty-state polish issue does not prove “worse than DeX overall”.

## Design rule

Compare by **user jobs** (pair, mirror, files, notifications), not by visual cloning.
Keep Mac-native shell: one primary CTA on empty state, devices in sidebar, workspace in detail.
Borrow DeX-like density sparingly; do not rebuild a DeX launcher on macOS.
