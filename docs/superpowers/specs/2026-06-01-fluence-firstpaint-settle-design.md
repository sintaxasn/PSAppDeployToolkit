# Fluence first-paint & settle hardening (iNKORE-modeled)

- **Date:** 2026-06-01
- **Branch:** `fluenceWpf4`
- **Status:** Approved design; ready for phased implementation by subagents.
- **Scope choice (user):** Root-cause the remaining flash **+** iNKORE-modeled robustness. **No** visual overhaul (no in-app acrylic, no WPF-drawn shadow, no `ElevationBorder`, no Card shadow caching).
- **Shadow decision (user):** Accept **flat, no DWM shadow** on the software-rendered path (rounded corners retained via the corner attribute).

## 1. Background & symptom

PSADT Fluent dialogs are hosted by `Fluence.Wpf` (`FluenceWindow`). `DialogManager` forces `RenderOptions.ProcessRenderMode = SoftwareOnly` for **every** dialog (RDP issue #1762). Prior work this branch (already in the working tree, pending module redeploy):

- `WindowCapabilities.BackdropCompositionAvailable` runtime gate (`DwmIsCompositionEnabled` AND `RegistryHelper.IsTransparencyEnabled`) → `WindowPolicy.ResolveEffectiveBackdrop` downgrades to opaque `None` when false. (The original gate also included `ProcessRenderMode != SoftwareOnly`; this was removed after hardware verification -- see the Gate Correction section below.)
- `FluenceWindow.ApplyBackdrop` sets both `Window.Background` and `HwndSource.CompositionTarget.BackgroundColor` to the plan color.
- `ListView` entrance animation fixed to hold containers hidden from first realization.
- `FluentDialog` layout + positioning moved into `OnSourceInitialized`.

**Remaining symptom:** the dialog still flashes black on first paint on the user's **composition-capable hardware**, but is **clean on a VM**. PSADT forces `SoftwareOnly` on both, so the gate yields an opaque background on both; the difference is **desktop DWM composition** (present on hardware, absent on the VM).

## 2. Root cause (confirmed in code)

`FluenceWindow.UpdateWindowChrome` derives the glass frame from the **requested** backdrop DP, not the **effective** (gated) backdrop:

```csharp
_windowChrome.GlassFrameThickness = WindowPolicy.GetGlassFrameThickness(SystemBackdropType, HasShadow);
```

`WindowPolicy.GetGlassFrameThickness(backdrop, hasShadow)` returns `-1` (extend glass through the whole client) whenever `backdrop != None || hasShadow`, and `HasShadow` defaults `true`. So even when the gate has resolved to an **opaque** background, the window still tells DWM (via `WindowChrome` → `DwmExtendFrameIntoClientArea(-1)`) to extend glass across the client.

On composition-capable hardware, the window is mapped before WPF's *software-rendered* (slower) first opaque frame is presented; DWM composites that not-yet-painted extended-glass region as black for the gap → the flash. On the VM there is no composition, so the glass-extend is a no-op and the gap is not black → clean. This is the classic "chrome keyed off the *requested* backdrop, not the *effective* one" inconsistency that the iNKORE review showed iNKORE avoids.

Audit result: `ApplyBackdrop` (caption color, system-backdrop type, immersive dark, suppress-caption), `ApplyCornerPreference`, and `ApplyFrame` already key off the effective plan. **The glass frame is the only mis-keyed chrome input.**

## 3. Guiding principle

**Every chrome/DWM decision follows the *effective* (gated) backdrop and the real composition state — never the *requested* DP.** Keep an opaque surface, and never ask DWM to extend glass, unless DWM is genuinely compositing a backdrop.

## 4. Phases

### Phase 0 — Verify the cause on target hardware (gates Phases 1+)

Only the user's composition-capable machine reproduces this. Add a throwaway repro to the **Fluence demo** (`Fluence.Wpf.Demo`): a menu/button that opens a `FluenceWindow` with `SystemBackdropType = Mica` after setting `RenderOptions.ProcessRenderMode = SoftwareOnly`, positioned so the first-paint can be observed/recorded. The user runs it on their hardware to confirm (a) the flash reproduces with the current glass-frame logic and (b) the Phase 1 change eliminates it.

- **Deliverable:** demo harness + a short README note in the demo on how to run it.
- **Risk:** none (throwaway/demo-only).
- **Gate:** no later phase is *finalized/redeployed* until the user confirms Phase 1 on hardware. (Phases 3/4 may be *implemented* in parallel since they are orthogonal, but the flash fix is validated first.)

### Phase 1 — Glass frame follows the effective backdrop (the fix) — Fluence library

1. **`WindowPolicy.GetGlassFrameThickness`**: add a `bool backdropCompositionAvailable` parameter. New behavior:
   - If `!backdropCompositionAvailable` → return `new Thickness(0.00001)` (resize-border-alive, **no** glass-extend), **regardless of `hasShadow`**.
   - Else unchanged: `effectiveBackdrop != BackdropType.None || hasShadow ? new Thickness(-1) : new Thickness(0.00001)`.
2. **`FluenceWindow`**: add a single private `GetEffectiveBackdrop()` helper wrapping `WindowPolicy.ResolveEffectiveBackdrop(SystemBackdropType, WindowCapabilities.Current)`. `UpdateWindowChrome` computes the glass frame from the **effective** backdrop **and** `WindowCapabilities.Current.BackdropCompositionAvailable`. All existing `UpdateWindowChrome` callers (`OnSystemBackdropTypeChanged`, `OnHasShadowChanged`, `OnTitleBarHeightChanged`, `OnExtendsContentIntoTitleBarChanged`, ctor) inherit the fix.
3. **Net effect:** on the PSADT/software-rendered path, DWM is never asked to extend glass into the client → no black-glass gap → flash gone, matching the VM. Flat, shadowless, rounded-corner dialog (corners via `DWMWA_WINDOW_CORNER_PREFERENCE`, unchanged).
4. **Tests** (`WindowPolicyTests`, both TFMs): extend the `GetGlassFrameThickness` matrix — `!composition` always returns `0.00001` even with `hasShadow:true`; composition-available cases unchanged. Update any existing `GetGlassFrameThickness_*` tests to pass `backdropCompositionAvailable: true` so they keep asserting `-1`. The existing `SoftwareRendering_…_PaintsOpaqueBackground` test still asserts the opaque base; optionally add an assertion that the window's `WindowChrome.GlassFrameThickness` is the thin value under forced `SoftwareOnly`.
5. **Risk:** low/surgical; only the non-composited path changes.

### Phase 2 -- First-paint hold (IMPLEMENTED; supersedes the original "settle kick")

Hardware frame-by-frame analysis revealed a deeper gap the glass-frame fix alone cannot cover: the dialog HWND is mapped and visible in the OS several display frames before WPF produces its first CPU-rendered frame. During that gap DWM shows the window's default (black) surface at its default (unpositioned) location. `PositionWindow` and `SizeToContent` then move and grow it while still black, and finally WPF's first frame lands. Net visible effect: a black window that slides and grows into place over approximately five frames. Hardware rendering hides this because WPF's first frame arrives almost instantly; forced software rendering makes it multi-frame and visible.

**Fix: first-paint hold.** `FluenceWindow` hides the HWND in `OnSourceInitialized` (after `ApplyWindowShell` commits chrome, backdrop, and background) and reveals it in `OnContentRendered` (after WPF's first paint, by which point `UpdateLayout` + `PositionWindow` + `SizeToContent` have all settled in any subclass's `OnSourceInitialized` continuation). The reveal is idempotent and guarded by a 1000 ms safety timer so the window can never stay hidden permanently.

**Gate:** `ShouldGuardFirstPaint()` = `ProcessRenderMode == SoftwareOnly || !IsCompositionEnabled()`. Hardware-composited, hardware-rendered sessions are excluded (the gap is negligible and the hold is unnecessary on that path).

**Hide mechanism:** cloak (`DWMWA_CLOAK`) when DWM composition is available -- the window is fully composited off-screen including any Mica/Acrylic backdrop, so the backdrop is ready the moment the window is revealed. Falls back to `WS_EX_LAYERED` + `SetLayeredWindowAttributes(alpha=0)` when composition is unavailable (opaque path only, so layered mode does not interfere with backdrop compositing).

**Reveal trigger:** `OnContentRendered` (primary) + 1000 ms `DispatcherTimer` safety fallback.

**Ordering for FluentDialog (confirmed in code):** `ShowDialog` creates HWND -> `FluenceWindow.OnSourceInitialized`: `ApplyWindowShell` then `HideForFirstPaint` (window hidden) -> `FluentDialog.OnSourceInitialized` continuation: `UpdateLayout` + `PositionWindow` (runs while hidden, so the final geometry is committed before first paint) -> WPF renders first frame -> `FluenceWindow.OnContentRendered` -> `RevealAfterFirstPaint` (window shown, fully-formed). `FluentDialog` does not override `OnContentRendered` (confirmed by grep), so the base reveal runs unconditionally.

**Residual Mica-composite-race risk:** on the Mica path (composition available, transparency on), the revealed frame may arrive at the OS compositor fractionally ahead of the DWM Mica frame for that VBlank. In practice `DWMWA_CLOAK` keeps the window composited with Mica behind it while hidden, so the Mica surface should already be ready at reveal. The user must verify on hardware whether any residual sub-frame flash is visible. The opaque path (no backdrop) has no such race.

The original "settle kick" (`SetWindowPos + SWP_FRAMECHANGED`) described in the earlier version of this phase is superseded by this hold. If the hold resolves the black-slide completely the settle kick adds no additional value.

### Phase 3 — Content-entrance discipline (codify + audit) — Fluence + PSADT

Principle (iNKORE `Frame`): content held hidden from *first realization* (never gated on `IsLoaded`), revealed via a deferred storyboard; **first content appears instantly, not faded**.

1. **`ListView`** (Fluence): confirm the existing fix conforms; add a regression test asserting a freshly-prepared container is never presented at full opacity before its fade (e.g., immediately after a `CollectionChanged` Reset on a loaded list, the new container's `Opacity` is `0` before the animation runs).
2. **`FluentDialog`** (PSADT): audit for elements that flash-then-settle. Known: the countdown shows the XAML-default `00:00:00` for a frame before the first timer tick. Pre-populate the countdown display value in `OnSourceInitialized` (after layout) so the first frame shows the real value. Verify no other content (button text, list) flashes.
3. **Docs:** add the "hold content hidden from first realization; first content appears instantly" rule to `lib/Fluence.Wpf/AGENTS.md` §9 (Common pitfalls).
4. **Risk:** low.

### Phase 4 — Structural resource-init guarantee (library-only) — Fluence

Add `FluenceResources : ResourceDictionary, ISupportInitialize` (in `Fluence.Wpf`) whose `EndInit()` calls `ApplicationThemeManager.Apply(ApplicationTheme.Auto)` once (idempotent via the engine's existing guards). Declarative consumers add it to `App.xaml` `MergedDictionaries` and get "resources present before any window" as a structural guarantee instead of a "call `Apply` first" convention. Demonstrate in the demo's `App.xaml`. **PSADT is unaffected** (it has no `App.xaml`; it already calls `Apply` in the dialog ctor) — this is a rule-out-the-class-of-issue library hardening, not a PSADT flash fix. PSADT `Apply`-at-startup amortization is **out of scope** (deferred).

- **Tests:** a test that constructing/showing a window after only `EndInit()` (no explicit `Apply`) yields resolved theme brushes.
- **Risk:** low; additive.

## 5. Build / test gates (apply to every phase)

- `Fluence.Wpf` builds with `TreatWarningsAsErrors`, `AnalysisLevel=latest-all`, `EnforceCodeStyleInBuild`, banned APIs (no `string.IsNullOrEmpty`), XML docs on public API, BSD header on new files, UTF-8 BOM, no em/en dashes in `.cs`/`.md`. **Both TFMs must build and test green:** `net472` and `net10.0-windows10.0.26100.0`.
- Authored XAML is auto-formatted by the repo hook; do not hand-fight it.
- New/changed behavior ships with MSTest coverage; do not lower the HEAD-of-branch test count.
- PSADT changes (Phase 3 countdown): rebuild `PSADT.UserInterface` clean (both TFMs).
- Follow `lib/Fluence.Wpf/AGENTS.md` conventions throughout.

## 6. Verification strategy

1. Per-phase unit/integration tests, both TFMs.
2. Phase 0 demo harness on the user's composition machine: confirm flash before / gone after Phase 1.
3. **Redeploy the module artifacts** (`src/Artifacts/**/PSAppDeployToolkit/lib/Fluence.Wpf.dll` and the client exe bins) — the stale-DLL trap that masked the gate fix earlier. The dialog loads the packaged copy, not the solution build output.
4. User confirms on hardware **and** VM: (a) no black first-paint flash, (b) no content flash-then-settle, (c) dialog appears settled.

## 7. Out of scope (recorded future options)

In-app composition-independent acrylic fallback; cached WPF-drawn shadow for the non-composited path; height-aware `ElevationBorder` primitive; `Card` `DropShadowEffect` bitmap-caching/gating; PSADT `Apply`-once-at-startup amortization.

## 8. Gate Correction (post-hardware-verification, 2026-06-01)

Hardware verification confirmed the glass-frame fix (Phase 1) eliminates the black flash. It also surfaced a flaw in the original `BackdropCompositionAvailable` gate: the term `ProcessRenderMode != SoftwareOnly` was incorrect.

**Why it was wrong:** WPF's `RenderOptions.ProcessRenderMode` controls how WPF rasterizes its own content (CPU or GPU). DWM desktop composition is a separate kernel-mode subsystem: it composites Mica and Acrylic behind a transparent window regardless of how WPF renders. A FluenceWindow with forced software rendering (`SoftwareOnly`) still receives a real DWM Mica backdrop on a composition-capable desktop with transparency enabled. PSADT sets `SoftwareOnly` on every dialog (RDP issue #1762), so the original gate silently forced every PSADT dialog to the opaque solid fallback, suppressing Mica entirely -- even on hardware where DWM would have composited it correctly.

**Corrected gate:** `WindowCapabilities.BackdropCompositionAvailable` now evaluates only `DwmIsCompositionEnabled AND RegistryHelper.IsTransparencyEnabled`. The `ProcessRenderMode` check is removed. The flash fix (glass-frame following the effective backdrop) remains in place and is unaffected by this correction -- it now prevents the black flash on the composited Mica path rather than forcing an opaque path.

**Net effect:** PSADT dialogs render real DWM Mica/Acrylic on composition-capable hardware with transparency enabled, matching iNKORE's behavior. The opaque solid fallback still applies when DWM composition is disabled or transparency is off.

## 9. iNKORE source reference (for implementers)

Local at `F:\FRebuild\iNKORE\source\iNKORE.UI.WPF.Modern`. Key files behind this design: `Controls/Helpers/WindowHelper.cs` (chrome + `WindowChrome` re-clone on Loaded = the settle kick), `Helpers/Styles/BackdropHelper.cs` (`IsManualBackgroundNeeded`), `Controls/Frame.cs` (content-entrance discipline), `ThemeManager.cs` + `ThemeResources.cs` (`ISupportInitialize` parse-time init), `Controls/Primitives/ThemeShadowChrome.cs` (the WPF shadow technique, deferred/out-of-scope).
