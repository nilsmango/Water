# Wind route regression fixtures

These CSV files preserve the GPS positions, timestamps, and reported speeds of
the supplied GPX sessions. Times are seconds from each file's first point.

| Fixture | Status | Direction evidence supplied by the rider |
| --- | --- | --- |
| `carqueiranne-2026-09-18.csv` | **Pending**; see [case notes](Pending/Carqueiranne18Pending.md) | Wind **from 310°**; waves **from 220°**. Several marked legs are still mislabeled. The shallow 17°/19° apparent bend is one leg, not a tack. |
| `carqueiranne-2026-09-17.csv` | Passing | Existing classification was nearly correct: eastward runs are downwind; southwest and northwest tacks are upwind. Two short-bridge turns near 43.073153, 6.054232 and 43.077236, 6.081494 should also be detected. |
| `carqueiranne-2026-09-16.csv` | Passing | Earlier confirmed route with eight upwind angles and three major downwind runs. |
| `yverdon-2026-07-09.csv` | Passing | Earlier direction correction: northeast travel is upwind and southwest travel is downwind. |
| `biel-2026-08-18.csv` | Passing | Earlier angle review; a long and a very short leg had been missed. |
| `ipsach-2026-06-06.csv` | Passing | Earlier angle and pumping interruption review. |

Only the first session has a rider supplied compass wind bearing. The remaining
direction labels are route section labels from the earlier review, not weather
measurements.
