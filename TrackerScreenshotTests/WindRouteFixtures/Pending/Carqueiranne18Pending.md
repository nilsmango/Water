# Pending wind route case: Carqueiranne, 18 September 2026

- Original recording: [carqueiranne-2026-09-18.gpx](carqueiranne-2026-09-18.gpx)
- Fast regression fixture: [carqueiranne-2026-09-18.csv](../carqueiranne-2026-09-18.csv)
- Rider's marked map: [carqueiranne-2026-09-18-marked.png](carqueiranne-2026-09-18-marked.png)

This UDW Parawing run had wind from about 310° and waves from about 220°.
The route axis is nearly perpendicular to the wind. The white circles mark
legs whose upwind/downwind colors need to flip relative to the marked map.
The current algorithm, including its global direction reversal, still does
not label all of them correctly. Slow wing-powered sections add ambiguity.
The angle-like 17° and 19° bends are part of one leg, not real turns.

The automated test currently checks only the false-angle result. **Directional
classification for this GPX is not a passing regression case yet.** Revisit
the marked legs with the rider before adding direction expectations.
