# IRON YARD — Original PBR on warehouse roof + Android owner verification

**13 November 2026** · Source baseline `0fe0ceb9d37b0e787669c4bf88510cea0fb1ccfc` · published baseline **v61 / Roblox place 57**.

## Confirmed code discrepancy

The 3 approved proprietary surface families already cover the arena floor,
freight containers and warehouse cover, but the two large overhead roof sheets
were still rendered with default `Enum.Material.Metal`. They occupy much
of the player's upward view and can appear uniformly repetitive on mobile.

## Delivered code changes

- Apply the existing owner-approved `warehouse_steel` 4-map MaterialVariant
  to the 2 large `ROOF / pitched corrugated shell` parts.
- Preserve their **visual-only** collisionless and non-queryable properties,
  `CastShadow=false`, geometry, rotation, LOD Core tier and skylight apertures.
  No new asset upload; the already loaded warehouse steel texture is reused.
- In **owner-only PERF**, expose local material assignment counts for
  `freight_steel`, `warehouse_steel` and `yard_asphalt`, plus `Roof: N/M`.
  These are client-side assignments, **not proof that the GPU rendered maps**.
- The ECO setting keeps native Metal by the existing
  `WorldPbrPolicy.clientVariant(..., "ECO")` rule. BALANCED and QUALITY use
  approved variants only when registered and available locally.
- Strengthen CI source contracts: 2 roof surfaces under the same bounded
  loop, server-owned MaterialVariant, no collision/hitbox modifications,
  per-family private diagnosis.

## Acceptance criteria in a real Android session

1. Owner joins the existing PUBLIC game and opens PERF (owner-only).
2. Observe `Decor: CONFIGURED`. In BALANCED, compare
   `warehouse_steel: N/M`, `yard_asphalt: N/M` and `Roof: 2/2`
   after the roof has streamed in; ECO should report `Roof: 0/2`.
3. Compare roof/floor screenshots at the same position in ECO/BALANCED/QUALITY;
   ensure consistent metal appearance without z-fighting or flickering.
4. Verify stable 30 FPS target and P95 frame time on the actual Android
   hardware; the CI does **not** measure these.
5. Test spawning, firing into walls, sliding, mantling and jumping; no roof
   part may become a physical or raycast obstacle.
6. If `Roof: 0/0`, first inspect streaming and the current location;
   the absence of local roof surfaces is not automatically an asset failure.

A completed CI or positive MaterialVariant count does not verify visual quality.
Public Roblox publication is a separate owner-authorized, guarded workflow.
