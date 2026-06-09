import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Html, OrbitControls } from '@react-three/drei';
import { Bloom, EffectComposer } from '@react-three/postprocessing';
import { createXRStore, useXR, useXRControllerLocomotion, XR, XROrigin } from '@react-three/xr';
import * as THREE from 'three';
import { api, type BinaryCompanion, type DerivedMeasurementRow, type DiscoveryPaper, type OrbitalGeometryRecord, type SceneResponse } from '../api';
import LoadingBar from '../components/LoadingBar';
import { estimateStarRadiusRsun, planetVisual } from '../procedural';
import { humanizeHours } from '../lib/units';

// Single module-level XR store. Persists across viewMode toggles even when
// the Canvas re-mounts (the store's session state lives in module scope).
// Surfacing controllers but skipping hand-tracking — Quest 3 has both, but
// the v0 experience is "look around with your head and use a controller
// to point at planets to jump to them."
const xrStore = createXRStore({
  hand: false,
  controller: true,
});

export default function ScenePage() {
  const { plName = '' } = useParams<{ plName: string }>();
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';

  const [scene, setScene] = useState<SceneResponse | null>(null);
  const [paper, setPaper] = useState<DiscoveryPaper | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [paused, setPaused] = useState(true);          // start paused (per plan)
  const [speed, setSpeed] = useState(1);               // 0.25 / 1 / 4 / 16
  const [panelCollapsed, setPanelCollapsed] = useState(false);
  // Stellar reference frame (spin axis + equator ring) on/off. Defaults on so
  // obliquity systems keep their existing visual; the toggle lets the user
  // hide the overlay for a clean view or when it gets noisy.
  const [showStellarReference, setShowStellarReference] = useState(true);
  // Debris-disk axis (normal vector perpendicular to the disk plane). Separate
  // toggle from the stellar spin axis so the user can show one without the
  // other — useful on systems like HR 8799 that have both, or systems with
  // a disk but no measured stellar rotation.
  const [showDebrisDiskAxis, setShowDebrisDiskAxis] = useState(true);
  // Align the camera so the (first) debris disk normal is "up" on screen.
  // Off by default — the user opts in to this reorientation when they want
  // a physics-natural view (disk horizontal, axis vertical) instead of the
  // arbitrary default camera angle.
  const [alignToDiskAxis, setAlignToDiskAxis] = useState(false);
  // In-scene ruler: two-endpoint interactive measurement tool in the
  // orbital plane. User drags the endpoints to read AU distances between
  // arbitrary points. Off by default. `rulerDragging` lifts the drag
  // state so OrbitControls can be disabled while an endpoint is being
  // dragged (otherwise the camera fights the handles).
  const [showRuler, setShowRuler] = useState(false);
  const [rulerDragging, setRulerDragging] = useState(false);
  // Companion-star HUD: a fixed-position panel listing companions with
  // arrows that rotate to point toward each body's actual 3D position.
  // Default on — the whole point is awareness of companions that sit
  // outside the focal planet's orbital plane. The shared ref is the
  // bridge between the in-Canvas tracker (writer) and the panel
  // (reader); see CompanionHUDTracker / CompanionHUDPanel.
  const [showCompanions, setShowCompanions] = useState(true);
  const companionDirectionsRef = useRef<
    Map<string, { deg: number; inView: boolean }>
  >(new Map());
  // Persistent labels above each wide companion star (the bodies outside
  // the planet's orbit). Off by default since they add visual noise;
  // user opts in when they need to disambiguate which star is which in
  // a system with multiple visible companions.
  const [showStarLabels, setShowStarLabels] = useState(false);

  // Parse the URL hash once on initial mount. viewMode + orbital clock are
  // initialized from it (must happen before Canvas first renders so the
  // viewMode key picks the right OrbitControls/FirstPersonLook branch);
  // camera angle is applied later by HashWriter once OrbitControls is wired.
  const initialHash = useMemo(
    () => (typeof window === 'undefined' ? {} : parseSceneHash(window.location.hash)),
    [],
  );
  const [viewMode, setViewMode] = useState<'system' | 'surface'>(initialHash.v ?? 'system');

  // Shared ref written by SceneContents each frame with the focal planet's
  // animated world position. Read by CameraFollowFocal in surface mode so
  // the camera rides along with the planet as it orbits.
  // The sun is always at scene origin — its position is constant.
  // BOTH hooks must be declared before any early returns (React rules of hooks).
  const focalPosRef = useRef(new THREE.Vector3());
  const sunWorldPos = useMemo(() => new THREE.Vector3(0, 0, 0), []);
  // Ref to the OrbitControls instance so HashWriter can read its live target
  // (which moves with right-click pan) when computing the camera spherical.
  const orbitControlsRef = useRef<unknown>(null);
  // Orbital animation clock — accumulates real seconds × speed when not paused.
  // Lifted from SceneContents so it can be (a) initialized from the URL hash,
  // (b) read each frame by HashWriter, and (c) survive Canvas remounts on
  // viewMode toggle (the clock would otherwise reset every time).
  const clockRef = useRef<number>(initialHash.t ?? 0);

  useEffect(() => {
    setScene(null);
    setPaper(null);
    setError(null);
    setPaused(true);
    setSpeed(1);
    api.planetScene(plName)
      .then(setScene)
      .catch((e: Error) => setError(e.message));
    // Paper fetch is best-effort — many planets don't have ADS data, that's fine
    api.planetPaper(plName).then(setPaper).catch(() => {});
  }, [plName]);

  if (error) {
    return (
      <div style={{ padding: '1rem' }}>
        <p><Link to={`/planets/${encodeURIComponent(plName)}${themeQuery}`} replace>← exit 3D scene</Link></p>
        <div className="error">Could not load scene: {error}</div>
      </div>
    );
  }

  if (!scene) {
    // Just the loading bar — no premature "exit" link cluttering the screen.
    // The header search bar above is still available for navigation.
    return (
      <div style={{ padding: '1rem' }}>
        <LoadingBar loading={true} />
      </div>
    );
  }

  // Camera setup: pull the camera WAY back from the system so the sun and
  // focal planet are both fully visible at once. Previous positions parked
  // the camera so close that the sun was mostly clipped by the FOV — making
  // the visible photosphere look like a thin crescent against the corona's
  // wider visible area, which read as "two distinct suns."
  const orbsmax = scene.planet.pl_orbsmax ?? 1;
  const focalSunRadius = sunDisplayRadius(scene.planet.st_rad, innermostPeriapsis(scene), orbsmax);
  const focalRadius = planetDisplayRadius(scene.planet.pl_rade, orbsmax, scene.planet.st_rad, focalSunRadius);
  // Distance from focal target. Big enough that sun + planet both fit in FOV.
  const camPos: [number, number, number] = [
    orbsmax * 1.8,
    orbsmax * 0.7,
    orbsmax * 1.4,
  ];
  const focalPos: [number, number, number] = [orbsmax, 0, 0];

  // Far plane must include the Gaia starfield sphere at STAR_SPHERE_AU.
  // logarithmicDepthBuffer keeps depth precision sane across the 0.001-AU
  // planet body to 5000-AU starfield range (would otherwise z-fight badly).
  const maxOrbit = Math.max(orbsmax, ...scene.siblings.map((s) => s.pl_orbsmax ?? 0));
  // Wide-binary / triple-star systems: companions are placed at their true
  // projected separation in AU (separation_arcsec × system distance pc). For
  // 16 Cyg B that's 815 AU; for GJ 667 C, 290 AU; for GJ 229, 27/53 AU.
  // The default OrbitControls maxDistance caps zoom-out at maxOrbit×4+5
  // — about 1.5 AU for a TRAPPIST-1-class system, way short of any wide
  // companion. Computing the maximum companion separation and folding it
  // into the zoom-out limit lets the user pull back far enough to see
  // those second/third suns instead of having them silently off-frame.
  const systemDistancePc = scene.host_star?.distance_gspphot_pc ?? scene.planet.sy_dist ?? scene.planet.distance_manual_pc ?? null;
  const maxCompanionSepAU = systemDistancePc != null
    ? Math.max(0, ...scene.binary_companions.map(
        (c) => (c.separation_arcsec ?? 0) * systemDistancePc,
      ))
    : 0;
  const maxOrbitOrCompanion = Math.max(maxOrbit, maxCompanionSepAU);
  // Far plane normally just needs to cover the starfield skydome (5000 AU).
  // For ultra-wide-orbit systems like 2MASS J0249-0557 c (orbsmax 1950 AU,
  // OrbitControls maxDistance 7800 AU) the orbit ellipse extends well past
  // the skydome, and zoom-out would chop off the far half of the orbit
  // ring against the camera's far plane. Push the far plane to cover both
  // the skydome and the camera-to-orbit-far-side distance.
  const farPlane = Math.max(STAR_SPHERE_AU * 1.2, maxOrbitOrCompanion * 8);

  const backTo = `/planets/${encodeURIComponent(plName)}${themeQuery}`;
  // Initialize the shared position to the focal planet's t=0 location so the
  // first surface-mode frame doesn't snap from origin to its actual position.
  if (focalPosRef.current.x === 0 && focalPosRef.current.z === 0) {
    focalPosRef.current.set(orbsmax, 0, 0);
  }
  // The focal planet's display radius — used as the camera's vertical offset
  // above the planet center in surface mode (so we're standing ON it, not in it).
  const surfaceOffset = focalRadius * 1.1;
  // Whether the focal scene has anything for the spin-axis toggle to control.
  // Drives whether the toggle button appears in PlaybackControls at all, so
  // there is no dangling control on systems where it would do nothing.
  const hasStellarReference =
    focalObliquity(scene.derived_measurements, scene.planet.pl_name) != null
    || focalStellarRotationDays(scene.derived_measurements, scene.planet.pl_name) != null;
  // Whether the focal scene has at least one debris disk with a MEASURED
  // inclination (the axis indicator + axis-aligned view only make sense for
  // measured tilts; ε Eri / 51 Eri belts have no inclination so they don't
  // contribute). Drives the disk-axis + align-to-disk toggles' visibility.
  const debrisDisksForFocal = focalDebrisDisks(scene.derived_measurements, scene.planet.pl_name);
  const hasInclinedDebrisDisk = debrisDisksForFocal.some((b) => b.inclinationDeg != null);
  // sunWorldPos was declared at the top of the component (alongside other
  // hooks) to satisfy React's rules-of-hooks. It's used here to point the
  // surface-view camera tracker at the sun, which always lives at origin.
  return (
    <>
      {!panelCollapsed && (
        <InfoPanel scene={scene} paper={paper} onCollapse={() => setPanelCollapsed(true)} />
      )}
      {panelCollapsed && (
        <ExpandTab onExpand={() => setPanelCollapsed(false)} />
      )}
      <TopRightHUD to={backTo} />
      <PlaybackControls
        paused={paused} setPaused={setPaused}
        speed={speed} setSpeed={setSpeed}
        viewMode={viewMode} setViewMode={setViewMode}
        showStellarReference={showStellarReference} setShowStellarReference={setShowStellarReference}
        hasStellarReference={hasStellarReference}
        showDebrisDiskAxis={showDebrisDiskAxis} setShowDebrisDiskAxis={setShowDebrisDiskAxis}
        alignToDiskAxis={alignToDiskAxis} setAlignToDiskAxis={setAlignToDiskAxis}
        hasInclinedDebrisDisk={hasInclinedDebrisDisk}
        showRuler={showRuler} setShowRuler={setShowRuler}
        showCompanions={showCompanions} setShowCompanions={setShowCompanions}
        hasCompanions={scene.binary_companions.length > 0}
        showStarLabels={showStarLabels} setShowStarLabels={setShowStarLabels}
      />
      {showCompanions && scene.binary_companions.length > 0 && (
        <CompanionHUDPanel
          companions={fillCompanionPositionAngles(
            dropUnpointableCompanions(
              dropSelfReferenceCompanions(scene.planet.hostname, scene.binary_companions),
            ),
          )}
          hostname={scene.planet.hostname}
          systemDistancePc={scene.host_star?.distance_gspphot_pc ?? scene.planet.sy_dist ?? scene.planet.distance_manual_pc ?? null}
          directionsRef={companionDirectionsRef}
        />
      )}
      {/* Re-mount the Canvas on viewMode change so the camera + controls swap
          cleanly. Slight perf hit on toggle, but no stale-state bugs. */}
      <Canvas
        key={viewMode}
        style={{ position: 'fixed', inset: 0, background: '#000', zIndex: 0 }}
        camera={
          viewMode === 'system'
            ? { position: camPos, fov: 50, near: focalRadius * 0.01, far: farPlane }
            : {
                // Surface: start at the focal planet's t=0 position. CameraFollowFocal
                // updates this every frame as the planet orbits.
                position: [orbsmax, surfaceOffset, 0],
                fov: 75,
                near: focalRadius * 0.01,
                far: farPlane,
              }
        }
        gl={{
          logarithmicDepthBuffer: true,
          toneMapping: THREE.ACESFilmicToneMapping,
          toneMappingExposure: 1.0,
        }}
      >
        {/* <XR> wraps the whole scene so it can render in immersive mode
            when the user enters VR. xrStore is a module-level singleton —
            the same store survives Canvas re-mounts on viewMode toggle. */}
        <XR store={xrStore}>
          <XRDepthFar />
          <VRAutoPlay setPaused={setPaused} />
          <ambientLight intensity={0.04} />
          {viewMode === 'system' && (
            <OrbitControls
              ref={orbitControlsRef as React.MutableRefObject<null>}
              target={focalPos}
              enablePan={true}
              minDistance={focalRadius * 1.5}
              maxDistance={maxOrbitOrCompanion * 4 + 5}
              enabled={!rulerDragging}
            />
          )}
          {viewMode === 'surface' && (
            <>
              <FirstPersonLook trackTarget={sunWorldPos} />
              <CameraFollowFocal focalPosRef={focalPosRef} surfaceOffset={surfaceOffset} />
            </>
          )}
          {/* Hash writer runs in both modes so simulation time + viewMode are
              captured; the cam= field is only updated in system mode (where
              OrbitControls drives the camera). */}
          <HashWriter
            controlsRef={orbitControlsRef}
            viewMode={viewMode}
            clockRef={clockRef}
          />
          {/* Visual scene content sits inside VRSceneScale so it scales up
              in VR (AU → meters mapping) without affecting the desktop view.
              Starfield lives OUTSIDE the scale group — its skydome follows
              the camera each frame, and being outside the scale means we
              can write camera.position directly to the mesh without having
              to divide by the scale factor. */}
          <VRSceneScale maxOrbit={maxOrbit}>
            {viewMode === 'system' ? (
              <SceneContents
                scene={scene} paused={paused} speed={speed} clockRef={clockRef}
                focalPosOut={focalPosRef}
                showStellarReference={showStellarReference}
                showDebrisDiskAxis={showDebrisDiskAxis}
                alignToDiskAxis={alignToDiskAxis}
                showRuler={showRuler}
                onRulerDragChange={setRulerDragging}
                showCompanions={showCompanions}
                companionDirectionsRef={companionDirectionsRef}
                showStarLabels={showStarLabels}
              />
            ) : (
              <SceneContents
                scene={scene} paused={paused} speed={speed}
                clockRef={clockRef}
                hideFocal
                focalPosOut={focalPosRef}
                showStellarReference={showStellarReference}
                showDebrisDiskAxis={showDebrisDiskAxis}
                alignToDiskAxis={alignToDiskAxis}
                showRuler={showRuler}
                onRulerDragChange={setRulerDragging}
                showCompanions={showCompanions}
                companionDirectionsRef={companionDirectionsRef}
                showStarLabels={showStarLabels}
              />
            )}
          </VRSceneScale>
          <Starfield plName={plName} />
          {/* VRRig is OUTSIDE VRSceneScale — its position/speed are in
              world meters, unaffected by scene scaling. 3m from origin
              looks at a ~6m-wide scaled system; 1.5 m/sec is comfortable
              walking pace inside VR.
              In surface mode, surfaceProps is passed so the rig tracks the
              focal planet each frame and locomotion is disabled — the user
              rides the planet, not walks around. */}
          {viewMode === 'surface' ? (
            <VRRig
              initialPos={[3, 0.5, 1.5]}
              speed={1.5}
              surfaceProps={{ focalPosRef, surfaceOffset, maxOrbit }}
            />
          ) : (
            <VRRig initialPos={[3, 0.5, 1.5]} speed={1.5} />
          )}
          <PostProcessing />
        </XR>
      </Canvas>
    </>
  );
}

const STAR_SPHERE_AU = 5000;

// ── scale conventions ────────────────────────────────────────────────────
// Orbital distances: TRUE AU scale, no fudging.
// Bodies (sun + planets + companion stars): EXAGGERATED by the same factor
// so their natural proportions (Sun is ~109× Earth's diameter) survive.
// Without exaggeration, planets are invisible specks; without matching the
// sun's exaggeration to the planets, the sun looks pathetic next to bloated
// worlds. Caps prevent the sun from engulfing inner planets.
// Surface-view mode (M4) will switch back to TRUE sizes — that's where the
// "what does this sun look like in the sky" data point lives.
const RSUN_IN_AU = 0.004650467;     // 1 R_sun
const REARTH_IN_AU = 0.0000426353;  // 1 R_earth
const BODY_EXAG = 500;               // applied uniformly to sun + planets + companion stars
const MIN_PLANET_AU = 0.0008;        // visibility floor — sub-Earth rocks need this
const ORBIT_CAP_FRAC = 1 / 25;       // planet body capped at this fraction of orbital distance
const SUN_PERIAPSIS_FRAC = 1 / 4;    // sun capped at this fraction of the focal planet's PERIAPSIS

// Solve M = E − e·sin(E) for E (the eccentric anomaly) given the mean
// anomaly M and eccentricity e. Newton's method, converges in 3-6 iters
// for e < 0.99. Used per-frame so it has to be cheap.
function solveKepler(M: number, e: number): number {
  let E = M + e * Math.sin(M);   // good initial guess for moderate e
  for (let i = 0; i < 8; i++) {
    const f  = E - e * Math.sin(E) - M;
    const fp = 1 - e * Math.cos(E);
    const dE = f / fp;
    E -= dE;
    if (Math.abs(dE) < 1e-9) break;
  }
  return E;
}

// Position on an ellipse with one focus at the origin (the sun). Same
// parameterization as OrbitRing — guarantees the rendered planet sits exactly
// on its rendered orbital path. Mean anomaly M comes from the animation clock.
function keplerPosition(a: number, e: number, M: number): [number, number, number] {
  const ec = Math.max(0, Math.min(0.99, e));
  const E = solveKepler(M, ec);
  const x = a * (Math.cos(E) - ec);
  const z = a * Math.sqrt(1 - ec * ec) * Math.sin(E);
  return [x, 0, z];
}

// Per-planet orbit tilts from measured mutual inclinations. Each row in
// scene.orbital_geometry says "planet X is tilted θ° relative to reference
// planet Y." The reference planet is treated as the system's flat plane
// (i=0) and every other planet with a measurement is tilted by its θ.
// Longitude of ascending node Ω isn't usually measured (RV/transit can
// only get the inclination, not the orientation), so we derive a
// deterministic Ω per planet from a hash of its name — that spreads
// multiple tilted planets to visually distinct orientations instead of
// stacking their tilts along a single shared line of nodes.
function buildOrbitTiltMap(
  geometry: OrbitalGeometryRecord[],
): Map<string, { inc: number; omega: number }> {
  const map = new Map<string, { inc: number; omega: number }>();
  for (const g of geometry) {
    if (g.mutual_inclination_deg == null || g.mutual_inclination_deg === 0) continue;
    const inc = (g.mutual_inclination_deg * Math.PI) / 180;
    // FNV-1a hash of the planet name → Ω in [0, 2π). Deterministic per name.
    let h = 2166136261;
    for (let i = 0; i < g.pl_name.length; i++) {
      h = Math.imul(h ^ g.pl_name.charCodeAt(i), 16777619);
    }
    const omega = (((h >>> 0) % 360) * Math.PI) / 180;
    map.set(g.pl_name, { inc, omega });
  }
  return map;
}

// Tilt a position originally in the (x, 0, z) orbital plane by inclination i
// around a line of nodes oriented at angle Ω from +X (measured around Y).
// Applies R = Ry(Ω) · Rx(i) (Y-up convention).
function applyOrbitTilt(
  x: number, z: number, inc: number, omega: number,
): [number, number, number] {
  if (inc === 0) return [x, 0, z];
  const cosI = Math.cos(inc), sinI = Math.sin(inc);
  const cosO = Math.cos(omega), sinO = Math.sin(omega);
  return [
    x * cosO + z * cosI * sinO,
    -z * sinI,
    -x * sinO + z * cosI * cosO,
  ];
}

// Rotate a position within the orbital plane by the argument of periastron ω.
// keplerPosition produces orbits with periapsis on +X by construction; the
// catalog's measured pl_orblper says where periapsis really points in the
// orbital plane (measured from the ascending node in the direction of motion).
// This rotation is applied BEFORE applyOrbitTilt so periapsis ends up in the
// correct direction within the eventually-tilted plane.
function rotateInPlane(x: number, z: number, argPeriRad: number): [number, number] {
  if (argPeriRad === 0) return [x, z];
  const c = Math.cos(argPeriRad), s = Math.sin(argPeriRad);
  return [x * c - z * s, x * s + z * c];
}

// Convert a catalog pl_orblper (degrees, may be null) to radians for the
// in-plane rotation. Null/undefined falls back to 0 (no rotation) so planets
// without a measured value keep the existing arbitrary periapsis at +X.
function argPeriRad(deg: number | null | undefined): number {
  return deg == null ? 0 : (deg * Math.PI) / 180;
}

// Spin-orbit obliquity (Rossiter-McLaughlin) for the focal planet: the angle
// between the host star's spin axis and the planet's orbital plane. This is
// NOT the planet's own axial tilt — it describes how the orbit sits relative
// to the star's equator. Prefer the de-projected 3-D angle (true obliquity ψ)
// where it exists; otherwise fall back to the sky-projected angle (λ), which
// only fixes the tilt as seen on the sky. The true line-of-nodes orientation
// is unknown either way, so the rendered tilt DIRECTION is a deterministic
// visual choice (see OBLIQUITY_NODE_OMEGA), the same honesty convention as
// the Ω-from-name-hash used for mutual inclinations.
type Obliquity = {
  deg: number; // measured value, verbatim (can be negative or >180)
  kind: 'true' | 'projected';
  bibcode: string | null;
  note: string | null;
  provenance: string; // 'curated' | 'nasa_exoplanet_archive'
};

// Best derived row for a quantity on the focal planet, preferring a curated
// deep-dive over a catalog bulk-promote when both exist for the same planet.
function bestDerived(
  derived: DerivedMeasurementRow[], plName: string, quantity: string,
): DerivedMeasurementRow | undefined {
  // Selection priority:
  //   1. provenance = 'curated' beats everything else (curated deep dives win
  //      over catalog bulk-promotes for the same planet+quantity).
  //   2. Within the same provenance class, prefer the bibcode that sorts
  //      lexicographically LAST. NASA EA bibcodes start with the publication
  //      year (e.g. 2021PNAS..., 2014Natur...), so this picks the most recent
  //      paper. More importantly it gives a stable, deterministic choice
  //      independent of DB row order / array order: without a tie-breaker,
  //      two same-provenance rows would resolve to whichever came first in
  //      the scene payload, which is undefined.
  let best: DerivedMeasurementRow | undefined;
  for (const d of derived) {
    if (d.pl_name !== plName || d.value == null || d.quantity !== quantity) continue;
    if (!best) { best = d; continue; }
    const dCurated = d.provenance === 'curated';
    const bestCurated = best.provenance === 'curated';
    if (dCurated && !bestCurated) { best = d; continue; }
    if (!dCurated && bestCurated) continue;
    // Same provenance class: most-recent bibcode wins (stable tie-breaker).
    if ((d.bibcode ?? '') > (best.bibcode ?? '')) best = d;
  }
  return best;
}

function focalObliquity(
  derived: DerivedMeasurementRow[], plName: string,
): Obliquity | null {
  const trueObl = bestDerived(derived, plName, 'true_obliquity');
  const projected = bestDerived(derived, plName, 'projected_obliquity');
  const pick = trueObl ?? projected; // true (de-projected 3-D) wins when present
  if (!pick || pick.value == null) return null;
  return {
    deg: pick.value,
    kind: trueObl ? 'true' : 'projected',
    bibcode: pick.bibcode,
    note: pick.curator_note,
    provenance: pick.provenance,
  };
}

// Host-star rotation period (days) for the focal planet, if catalog/curated
// data carries it. Drives the visible star rotation in the scene.
function focalStellarRotationDays(
  derived: DerivedMeasurementRow[], plName: string,
): number | null {
  const row = bestDerived(derived, plName, 'stellar_rotation_period');
  return row?.value ?? null;
}

// Centrifugal flattening of a rotating star: f = (R_eq − R_pol)/R_eq. For a
// rigid Maclaurin spheroid in the slow-rotation limit, f ≈ q/2 where the
// rotational parameter q = Ω²R³/(GM). Inputs are observable quantities —
// stellar_rotation_period or stellar_vsini for Ω, st_rad for R, st_mass for
// M — so no curation step is needed. Returns null when any input is missing
// or when the derived flattening is below a visibility threshold (0.5%),
// which keeps Sun-like rotators (Sun f ~ 9e-6) from triggering a render.
//
// Examples in the catalog:
//   KELT-9      vsini ~111 km/s, R = 2.4 R_sun, M = 2.5 M_sun  →  f ~ 0.03
//   beta Pic    vsini ~125 km/s, R = 1.8 R_sun, M = 1.75 M_sun →  f ~ 0.05
//   Vega-class  vsini ~200 km/s, R = 2.4 R_sun, M = 2.1 M_sun  →  f > 0.1
function focalStellarOblateness(
  derived: DerivedMeasurementRow[], plName: string,
  stRadRsun: number | null, stMassMsun: number | null,
): number | null {
  if (stRadRsun == null || stRadRsun <= 0 || stMassMsun == null || stMassMsun <= 0) return null;
  // Prefer measured rotation period (days). Fall back to v sin i (km/s) via
  // P_rot = 2π R / v sin i, treating sin i ≈ 1 — this overestimates P_rot
  // (underestimates Ω, underestimates f) when the spin axis is inclined, so
  // the rendered flattening is a lower bound from v sin i.
  let omegaRadSec: number | null = null;
  const rotp = bestDerived(derived, plName, 'stellar_rotation_period');
  if (rotp?.value != null && rotp.value > 0) {
    omegaRadSec = (2 * Math.PI) / (rotp.value * 86400);
  } else {
    const vsini = bestDerived(derived, plName, 'stellar_vsini');
    if (vsini?.value != null && vsini.value > 0) {
      const Rm = stRadRsun * 6.957e8;
      omegaRadSec = (vsini.value * 1000) / Rm;
    }
  }
  if (omegaRadSec == null) return null;
  const R = stRadRsun * 6.957e8;          // meters
  const GM = 6.674e-11 * stMassMsun * 1.989e30;
  const q = (omegaRadSec * omegaRadSec * R * R * R) / GM;
  const f = q / 2;
  if (!Number.isFinite(f) || f < 0.005) return null;
  // Cap at 0.35 (extreme break-up rotators). Beyond f≈0.35 the slow-rotation
  // Maclaurin approximation breaks down anyway, and visually 35% squash is
  // already at the limit of "credibly a star, not a disc."
  return Math.min(0.35, f);
}

// Thermal emission color for a body at temperature T (Kelvin). Stylized for
// visibility — below ~800K the surface is essentially dark (peak emission in
// the IR, no visible glow); above ~1500K it reads as cherry-red; above
// ~4000K it's near-white. Brightness ramps sub-linearly so day/night
// contrast reads dramatically without saturating mid-range. Channel values
// above 1.0 (very hot) trigger bloom — correct for ultra-hot Jupiters.
function thermalEmissionColor(T: number): THREE.Color {
  if (T < 800) return new THREE.Color(0.04, 0.03, 0.02); // below visible emission
  const brightness = Math.min(2.0, Math.max(0.1, (T - 700) / 1700));
  const r = 1.0;
  const g = Math.min(1.0, Math.max(0.0, (T - 1000) / 2200));
  const b = Math.min(0.8, Math.max(0.0, (T - 2800) / 2500));
  return new THREE.Color(r * brightness, g * brightness, b * brightness);
}

type PhaseCurve = { dayside: THREE.Color; nightside: THREE.Color };

// Circumplanetary disk presence + dust mass for the focal planet. Currently
// only PDS 70 c has a resolved CPD measurement (Benisty et al. 2021, ~0.031
// M_earth of dust); PDS 70 b has a measured accretion rate which we treat
// as a softer indicator that *something* dusty surrounds the forming planet.
// When this returns non-null, the renderer draws a flat dust ring around the
// planet body (the canonical "disk-feeding-a-forming-planet" look from the
// VLT/ALMA images of PDS 70).
type CircumplanetaryDisk = {
  dustMassMEarth: number | null;       // null when only an accretion-rate hint exists
  bibcode: string | null;
  curatorNote: string | null;
};

function focalCircumplanetaryDisk(
  derived: DerivedMeasurementRow[], plName: string,
): CircumplanetaryDisk | null {
  const mass = bestDerived(derived, plName, 'circumplanetary_disk_dust_mass');
  if (mass) {
    return {
      dustMassMEarth: mass.value,
      bibcode: mass.bibcode,
      curatorNote: mass.curator_note,
    };
  }
  // Fall back to accretion-rate evidence (PDS 70 b has Wagner 2018 accretion
  // but no resolved disc yet). Still warrants a disk render — the accretion
  // requires a feeding reservoir.
  const accretion = bestDerived(derived, plName, 'accretion_rate');
  if (accretion) {
    return {
      dustMassMEarth: null,
      bibcode: accretion.bibcode,
      curatorNote: accretion.curator_note,
    };
  }
  return null;
}

// Day/night thermal-emission colors for the focal planet, when measured
// dayside_temperature exists and is hot enough (~1200K+) that thermal
// radiation dominates the visible appearance rather than reflected light.
// Below that threshold, reflected starlight is the right model and the
// standard reflection-based shader path stays in charge.
// If nightside_temperature is missing, we estimate it from the dayside via
// a simple heat-redistribution falloff: ultra-hot atmospheres lose energy
// to radiation faster than circulation can redistribute it, so they carry
// larger day-night contrast (KELT-9 b-class); cooler hot Jupiters
// (WASP-43 b-class) redistribute more efficiently.
function focalPhaseCurve(
  derived: DerivedMeasurementRow[], plName: string,
): PhaseCurve | null {
  const day = bestDerived(derived, plName, 'dayside_temperature');
  if (!day?.value || day.value < 1200) return null;
  const night = bestDerived(derived, plName, 'nightside_temperature');
  const T_night = night?.value ?? day.value * Math.exp(-day.value / 4000);
  return {
    dayside: thermalEmissionColor(day.value),
    nightside: thermalEmissionColor(T_night),
  };
}

// Atmospheric mass loss for the focal planet. Drives the comet-like exosphere
// tail rendered downstream of (or upstream of, for HAT-P-67 b) the planet body.
// Currently 8 planets carry a mass_loss_rate row in derived_measurements
// (migration 088 + Kepler-1520 b from 036). Mechanism classification reads
// the `model` column to color the tail: hydrogen-escape tails are blue
// (Lyman-alpha-tracer palette), helium-escape tails are pink/red (He I 10833
// metastable palette), Kepler-1520 b's dust is warm gray-brown.
type EscapeMechanism = 'hydrogen' | 'helium' | 'dust';
type FocalMassLoss = {
  value: number;                  // M_earth / Gyr
  uncHi: number | null;
  uncLo: number | null;
  mechanism: EscapeMechanism;
  leading: boolean;               // tail extends ahead of orbital motion (HAT-P-67 b)
  model: string | null;
  bibcode: string | null;
  curatorNote: string | null;
  provenance: string;
};

function classifyEscapeMechanism(model: string | null): EscapeMechanism {
  const m = (model ?? '').toLowerCase();
  if (m.includes('helium') || m.includes('he ') || m.includes('roche-lobe')) return 'helium';
  if (m.includes('hydrogen') || m.includes('hydrodynamic') || m.includes('lyman')) return 'hydrogen';
  if (m.includes('dust')) return 'dust';
  return 'hydrogen';
}

function focalMassLoss(
  derived: DerivedMeasurementRow[], plName: string,
): FocalMassLoss | null {
  const row = bestDerived(derived, plName, 'mass_loss_rate');
  if (!row?.value || row.value <= 0) return null;
  const note = (row.curator_note ?? '').toLowerCase();
  // HAT-P-67 b is the canonical pre-transit (leading) tail case; the curator
  // note for those rows says so explicitly.
  const leading = note.includes('leading') || note.includes('pre-transit');
  return {
    value: row.value,
    uncHi: row.unc_hi,
    uncLo: row.unc_lo,
    mechanism: classifyEscapeMechanism(row.model),
    leading,
    model: row.model,
    bibcode: row.bibcode,
    curatorNote: row.curator_note,
    provenance: row.provenance,
  };
}

// Curated reflective albedo for the focal planet. Modulates the planet body's
// reflected-light brightness in the renderer's "reflective" lighting mode
// (the phase-curve / thermal-emission path is left alone — those planets are
// emission-dominated and albedo doesn't drive their visible appearance).
// Reference albedo of 0.30 is treated as the baseline (factor = 1.0); higher
// values brighten reflection, lower values darken it. Prefer geometric_albedo
// when present; fall back to bond_albedo.
//
// HD 189733 b carries a wavelength-dependent albedo (high in the blue,
// suppressed beyond ~450 nm by sodium absorption). The curator note flags
// this and the helper returns a non-null `reflectionTint` so the renderer
// can tint reflected starlight blue — the famous "deep cobalt" visual.
type FocalAlbedo = {
  value: number;                  // 0-1 fraction
  kind: 'geometric' | 'bond';
  uncHi: number | null;
  uncLo: number | null;
  isUpperLimit: boolean;          // true when stored value is a non-detection bound
  model: string | null;
  bibcode: string | null;
  curatorNote: string | null;
  provenance: string;
  reflectionTint: string | null;  // hex color for blue-leaning reflection (HD 189733 b)
};

function focalAlbedo(
  derived: DerivedMeasurementRow[], plName: string,
): FocalAlbedo | null {
  // Geometric is the direct measurement of dayside reflectivity, so prefer
  // it when both are available. Bond is what's reported for Kepler-10 b and
  // a few others.
  const geom = bestDerived(derived, plName, 'geometric_albedo');
  const bond = bestDerived(derived, plName, 'bond_albedo');
  const row = geom ?? bond;
  if (!row?.value || row.value < 0) return null;
  const kind: 'geometric' | 'bond' = geom != null ? 'geometric' : 'bond';
  const note = (row.curator_note ?? '').toLowerCase();
  const model = (row.model ?? '').toLowerCase();
  // Wavelength-dependent / blue-tinted reflection (HD 189733 b). The
  // curator note explicitly describes the deep-blue visual; we encode
  // that as a reflection color the shader can mix into the body color.
  const reflectionTint = (note.includes('blue') && note.includes('tint'))
    || note.includes('deep-blue')
    || note.includes('cobalt')
    ? '#1a55c8' : null;
  return {
    value: row.value,
    kind,
    uncHi: row.unc_hi,
    uncLo: row.unc_lo,
    isUpperLimit: model.includes('upper limit'),
    model: row.model,
    bibcode: row.bibcode,
    curatorNote: row.curator_note,
    provenance: row.provenance,
    reflectionTint,
  };
}

function provenanceLabel(p: string): string {
  // Explicit mapping rather than "curated vs not-curated", because the DB
  // column intentionally has no CHECK constraint (so future provenance
  // sources can be added freely without a migration). An unknown value
  // falls through to the raw string instead of being silently mislabelled
  // as NASA EA.
  switch (p) {
    case 'curated': return 'curated deep-dive';
    case 'nasa_exoplanet_archive': return 'NASA Exoplanet Archive (default parameter set)';
    default: return p;
  }
}

// Stylized axial-spin angular velocity (rad/sec) for the scene's animation
// clock, derived from a measured rotation_velocity (km/s) + planet radius
// (R_Earth). Real spin periods range from 2 h (AB Pic b) to 24 h (Earth)
// — we compress that into a 0.5..200 h clamped range and then map to a
// 10 sec equivalent at the bottom of the clamp so the rotation reads at
// our animation pacing without being either invisibly slow or strobing.
// Shared by the focal-planet spin and the sibling-planet spin so PDS 70
// b's rotation is visible whether viewed as focal or as sibling.
function stylizedSpinOmega(rotationVelocityKmS: number, pl_rade: number): number | null {
  if (rotationVelocityKmS <= 0 || pl_rade <= 0) return null;
  const R_km = pl_rade * 6371; // 1 R_Earth
  const periodHours = (2 * Math.PI * R_km) / rotationVelocityKmS / 3600;
  const clamped = Math.min(200, Math.max(0.5, periodHours));
  return ((2 * Math.PI) / 12) * (10 / clamped); // rad/sec
}

// Curated effective temperature for the focal planet, when pl_eqt is
// null. Self-luminous directly-imaged objects (AB Pic b, β Pic b, HR 8799
// a-e, 51 Eri b, etc.) have no equilibrium temperature in NASA EA because
// they're not equilibrium-heated by their host; instead their atmospheric
// model fits give an effective temperature in `planet_derived_measurements`.
// Without this fallback the whole directly-imaged class renders as the
// pl_eqt-null grey default.
function focalEffectiveTeff(
  derived: DerivedMeasurementRow[], plName: string,
): number | null {
  const row = bestDerived(derived, plName, 'effective_temperature');
  if (!row || row.value == null || row.unit !== 'K') return null;
  return row.value;
}

// System-level debris disk for the focal planet's host star. 5 systems
// currently carry curated debris_disk_* rows (migration 090): bet Pic b,
// HR 8799 b, HD 95086 b, eps Eri b, 51 Eri b (which has two belts —
// warm at 5.5 AU, cold at 82 AU). Each belt's rows share one bibcode
// (the primary source paper), so grouping by bibcode reconstructs the
// per-belt geometry. A belt with no debris_disk_outer_au row is a
// single-radius SED fit (Patel/Riviere-Marichalar for 51 Eri); the
// renderer draws it as a narrow ring centered on the inner_au value.
type FocalDebrisDiskBelt = {
  innerAu: number;
  outerAu: number | null;          // null for SED-fit single-radius belts
  inclinationDeg: number | null;   // null when no source paper quotes one
  inclinationUncHi: number | null;
  inclinationUncLo: number | null;
  model: string | null;            // "Kepler bandpass occultation", etc.
  bibcode: string | null;
  curatorNote: string | null;
  provenance: string;
  // Curated dust temperature (migration 091). Drives the renderer's
  // per-belt color: ~45-55 K is cool blue-gray (sub-mm cold dust), ~85 K
  // is neutral, ~180 K reads as warm orange-brown (mid-IR warm dust).
  // Null for belts where no paper quotes a temperature (eps Eri b).
  dustTemperatureK: number | null;
  dustTemperatureUncHi: number | null;
  dustTemperatureUncLo: number | null;
  // Temperature paper bibcode — often DIFFERENT from the geometry paper
  // (HR 8799 geometry from Booth 2016, temperature from Su 2009; HD 95086
  // geometry from Su 2017, temperature from Su 2015). Both deserve their
  // own citation in the InfoPanel.
  dustTemperatureBibcode: string | null;
};

function focalDebrisDisks(
  derived: DerivedMeasurementRow[], plName: string,
): FocalDebrisDiskBelt[] {
  // Pull all debris_disk_* rows for this planet, then group by bibcode —
  // each unique bibcode is one belt. (β Pic has one belt with 3 rows
  // sharing Dent 2014; 51 Eri has two belts, each its own bibcode.)
  const rows = derived.filter(
    (r) => r.pl_name === plName && r.quantity.startsWith('debris_disk_'),
  );
  if (rows.length === 0) return [];
  const byBibcode = new Map<string, DerivedMeasurementRow[]>();
  for (const r of rows) {
    const key = r.bibcode ?? `__nobib_${r.quantity}_${r.value}`;
    const list = byBibcode.get(key) ?? [];
    list.push(r);
    byBibcode.set(key, list);
  }
  const belts: FocalDebrisDiskBelt[] = [];
  for (const group of byBibcode.values()) {
    const inner = group.find((r) => r.quantity === 'debris_disk_inner_au');
    const outer = group.find((r) => r.quantity === 'debris_disk_outer_au');
    const inc = group.find((r) => r.quantity === 'debris_disk_inclination_deg');
    const temp = group.find((r) => r.quantity === 'debris_disk_dust_temperature_k');
    if (!inner?.value) continue;
    const anchor = inner;
    belts.push({
      innerAu: inner.value,
      outerAu: outer?.value ?? null,
      inclinationDeg: inc?.value ?? null,
      inclinationUncHi: inc?.unc_hi ?? null,
      inclinationUncLo: inc?.unc_lo ?? null,
      model: anchor.model,
      bibcode: anchor.bibcode,
      curatorNote: anchor.curator_note,
      provenance: anchor.provenance,
      dustTemperatureK: temp?.value ?? null,
      dustTemperatureUncHi: temp?.unc_hi ?? null,
      dustTemperatureUncLo: temp?.unc_lo ?? null,
      dustTemperatureBibcode: temp?.bibcode ?? null,
    });
  }
  // Orphan-temperature fallback: when a planet's temperature row has a
  // DIFFERENT bibcode from the geometry row (HR 8799: Booth 2016 geometry
  // + Su 2009 temperature; HD 95086: Su 2017 geometry + Su 2015 temperature),
  // the bibcode-grouping above puts the temperature in a separate group
  // without inner_au, so it gets dropped. For single-belt planets we
  // attach the orphan temperature to that belt. Multi-belt systems
  // (51 Eri) get bibcode-matched temperatures via the loop above.
  const orphanTemps = rows.filter(
    (r) => r.quantity === 'debris_disk_dust_temperature_k'
      && !belts.some((b) => b.dustTemperatureBibcode === r.bibcode),
  );
  if (orphanTemps.length === 1 && belts.length === 1 && belts[0].dustTemperatureK == null) {
    const t = orphanTemps[0];
    belts[0].dustTemperatureK = t.value;
    belts[0].dustTemperatureUncHi = t.unc_hi;
    belts[0].dustTemperatureUncLo = t.unc_lo;
    belts[0].dustTemperatureBibcode = t.bibcode;
  }
  // Sort by inner radius so the warm/inner belt renders first; helps the
  // 51 Eri case (warm 5.5 AU + cold 82 AU) look ordered in the InfoPanel.
  belts.sort((a, b) => a.innerAu - b.innerAu);
  return belts;
}

// Dust color from temperature (K). Cold dust (~40-60 K, sub-mm regime)
// reads as cool blue-gray; warm dust (~150-250 K, mid-IR regime) reads as
// warm orange-brown. Two-segment linear interpolation through a neutral
// brown midpoint at ~100 K. Returns the legacy generic-dust brown when
// temperature is not measured. Output is a hex string for ShaderMaterial
// uColor uniform.
function dustColorHex(tKelvin: number | null): string {
  if (tKelvin == null) return '#9a8060'; // legacy generic dust
  const cold: [number, number, number] = [90, 106, 136];   // 40 K — cool blue-gray
  const mid:  [number, number, number] = [154, 128, 96];   // 100 K — neutral brown (= #9a8060)
  const warm: [number, number, number] = [192, 128, 80];   // 200 K — warm orange-brown
  const lerp = (a: [number,number,number], b: [number,number,number], t: number) =>
    [0,1,2].map((i) => Math.round(a[i] + Math.max(0, Math.min(1, t)) * (b[i] - a[i])));
  const channels = tKelvin <= 100
    ? lerp(cold, mid, (tKelvin - 40) / 60)
    : lerp(mid, warm, (tKelvin - 100) / 100);
  const hex = (n: number) => n.toString(16).padStart(2, '0');
  return `#${hex(channels[0])}${hex(channels[1])}${hex(channels[2])}`;
}

// Starspot parameters derived from the host's rotation period and identifier:
// - latitude (Strassmeier-Hathaway correlation: fast rotators carry high-
//   latitude / near-polar spots; slow Sun-like rotators carry low-latitude
//   ones). Now a smooth exponential decay (lat ≈ 80·exp(-P/15)) instead of a
//   linear-then-clamped formula — the previous clamp at P=25 piled most of
//   the catalog at exactly 15°, which made every slow rotator look the same.
// - hemisphere + longitude from a well-mixed parity hash of the hostname.
//   The previous implementation read bit 9 of an FNV hash for hemisphere and
//   that bit was ~80% one-sided across real hosts; XORing all bits down gives
//   a genuine 50/50 split, and the longitude pulls from a separately-mixed
//   slice so the two aren't correlated.
// - angular size: spot radius scales with rotation rate (fast → big polar
//   cap, slow → small spot), which mirrors the magnetic activity scaling
//   (faster = more active = larger spot coverage).
type StarSpotProps = {
  dir: THREE.Vector3;
  innerCos: number; // cos of inner-edge angular radius (full-dark center)
  outerCos: number; // cos of outer-edge angular radius (zero spot beyond)
};

function starSpotProps(rotationPeriodDays: number, hostKey: string): StarSpotProps {
  const P = Math.max(0.5, rotationPeriodDays);

  // Smooth latitude distribution, ~80° at very fast → 0° at very slow.
  const latMag = 80 * Math.exp(-P / 15);

  // FNV-1a hash, then collapse to parity for hemisphere so the split is
  // genuinely 50/50; use a higher slice for longitude so the two are
  // independent.
  let h = 2166136261;
  for (let i = 0; i < hostKey.length; i++) h = Math.imul(h ^ hostKey.charCodeAt(i), 16777619);
  let parity = h >>> 0;
  parity ^= parity >>> 16; parity ^= parity >>> 8;
  parity ^= parity >>> 4;  parity ^= parity >>> 2; parity ^= parity >>> 1;
  const hemisphere = (parity & 1) ? 1 : -1;
  const lonDeg = ((h >>> 8) >>> 0) % 360;

  const lat = (hemisphere * latMag * Math.PI) / 180;
  const lon = (lonDeg * Math.PI) / 180;
  const dir = new THREE.Vector3(
    Math.cos(lat) * Math.cos(lon),
    Math.sin(lat),
    Math.cos(lat) * Math.sin(lon),
  );

  // Angular size, also rotation-rate driven. Fast rotators are magnetically
  // active and carry big polar caps; slow Sun-like rotators carry tiny low-
  // latitude spots. Range ~3° (very slow) to ~22° (very fast); calibrated
  // closer to real sunspot-group sizes (~3-10° on the Sun) rather than the
  // generously visual range of the previous formula. Soft edge ~30% of total.
  const outerDeg = 3 + 20 / (1 + P / 10);
  const innerDeg = outerDeg * 0.7;
  const outerCos = Math.cos((outerDeg * Math.PI) / 180);
  const innerCos = Math.cos((innerDeg * Math.PI) / 180);

  return { dir, innerCos, outerCos };
}

// Line of nodes for the obliquity tilt, chosen perpendicular to the default
// camera azimuth so a polar/retrograde orbit swings up/down across the view
// (legible) instead of edge-on. Derived from camPos = [orbsmax·1.8, ·0.7,
// ·1.4] looking at [orbsmax, 0, 0]: azimuth = atan2(Δz, Δx) = atan2(1.4, 0.8);
// the orbsmax scale cancels, so this is a constant.
const OBLIQUITY_NODE_OMEGA = Math.atan2(1.4, 0.8) + Math.PI / 2;

function planetDisplayRadius(
  pl_rade: number | null,
  pl_orbsmax: number | null,
  st_rad?: number | null,
  sunDisplayAU?: number,
): number {
  const truthAU = (pl_rade ?? 1) * REARTH_IN_AU;
  const exaggerated = truthAU * BODY_EXAG;
  const orbsmax = pl_orbsmax ?? 1;
  const orbitCap = orbsmax * ORBIT_CAP_FRAC;
  // Visibility floor for ultra-wide-orbit imaged planets (2MASS J0249-0557 c at
  // 1950 AU, etc.). Default camera distance is ~2.4 × orbsmax; without a floor
  // a Jupiter-class body at 1950 AU shrinks to ~0.005° apparent diameter and
  // disappears below sub-pixel even on a 4K screen. Floor at ~0.5° apparent
  // ensures the planet renders as at least a small visible disc.
  const visibilityFloor = orbsmax * 0.007;
  let radius = Math.max(MIN_PLANET_AU, Math.min(Math.max(exaggerated, visibilityFloor), orbitCap));

  // Star-vs-planet hierarchy cap. When the catalog says the host star is
  // genuinely larger than the planet (essentially every main-sequence host,
  // 5-100× the planet's true radius), cap the rendered planet at the rendered
  // sun so the visual hierarchy matches reality. Necessary mainly for
  // high-eccentricity orbits (HD 80606 b at e=0.93, etc.): the sun's display
  // gets squeezed by its periapsis-fraction cap, and without this rule the
  // planet would dwarf the star on screen — opposite of reality.
  // Truth-gated: the check trueSunAU > truePlanetAU exempts the handful of
  // systems where the planet really IS bigger (DP Leo b around a white dwarf;
  // WISEP J1217+1626 A b around a Y/T brown dwarf), so we don't distort those.
  if (st_rad != null && pl_rade != null && sunDisplayAU != null) {
    const trueSunAU = st_rad * RSUN_IN_AU;
    const truePlanetAU = pl_rade * REARTH_IN_AU;
    if (trueSunAU > truePlanetAU && radius > sunDisplayAU) {
      radius = sunDisplayAU;
    }
  }
  return radius;
}

// Smallest periapsis (closest approach to the star) across all planets in the
// system. Used to cap the sun's glow size so it doesn't reach past adjacent
// orbits in tight inner systems.
function innermostPeriapsis(scene: SceneResponse): number {
  const all: { a: number; e: number }[] = [
    { a: scene.planet.pl_orbsmax ?? 1, e: scene.planet.pl_orbeccen ?? 0 },
    ...scene.siblings
      .filter((s) => s.pl_orbsmax != null)
      .map((s) => ({ a: s.pl_orbsmax!, e: s.pl_orbeccen ?? 0 })),
  ];
  return Math.min(...all.map(({ a, e }) => a * (1 - Math.max(0, Math.min(0.99, e)))));
}

// Sun gets the same exaggeration so it stays proportionally huge vs planets,
// but capped so EVERY planet in the system — not just the focal one — stays
// comfortably outside the photosphere at periapsis. Floor at true radius;
// never shrink a star. For ultra-wide-orbit systems (2MASS J0249-0557 c at
// 1950 AU, b Cen AB b, etc.) the camera sits at ~2.4 × focalOrbsmax from
// origin, and the default exaggerated solar disc becomes sub-pixel from
// there — bump the floor so the host is always at least ~1° apparent.
function sunDisplayRadius(
  st_rad_solar: number | null,
  innermostPeriapsisAu: number,
  focalOrbsmaxAu: number,
): number {
  const truthAU = (st_rad_solar ?? 1) * RSUN_IN_AU;
  const exaggerated = truthAU * BODY_EXAG;
  const periapsisCap = innermostPeriapsisAu * SUN_PERIAPSIS_FRAC;
  const visibilityFloor = focalOrbsmaxAu * 0.022;
  return Math.max(truthAU, Math.min(Math.max(exaggerated, visibilityFloor), periapsisCap));
}


// ── HUD layout ────────────────────────────────────────────────────────────
// Top-left:  InfoPanel (collapsible, sectioned with per-section expand)
// Top-right: CloseButton (X — exit to planet detail page)
// Bottom-right: PlaybackControls (play/pause, speed, help text)
// All overlays sit BELOW the site header (CSS-sticky, ~130px tall).

const HEADER_OFFSET_PX = 130;   // safe vertical offset below the sticky header

function InfoPanel({
  scene, paper, onCollapse,
}: {
  scene: SceneResponse;
  paper: DiscoveryPaper | null;
  onCollapse: () => void;
}) {
  const { planet, scene_hints, host_star } = scene;
  // Per-section expand state. Quick stats + planet name always visible.
  const [openSections, setOpenSections] = useState<Set<string>>(new Set());
  const toggle = (k: string) => setOpenSections((prev) => {
    const next = new Set(prev);
    if (next.has(k)) next.delete(k); else next.add(k);
    return next;
  });

  const distance_pc = host_star?.distance_gspphot_pc ?? planet.sy_dist ?? planet.distance_manual_pc;
  const obliquity = focalObliquity(scene.derived_measurements, planet.pl_name);
  const rotp = bestDerived(scene.derived_measurements, planet.pl_name, 'stellar_rotation_period');
  const vsini = bestDerived(scene.derived_measurements, planet.pl_name, 'stellar_vsini');
  const planetSpin = bestDerived(scene.derived_measurements, planet.pl_name, 'rotation_velocity');
  const cpdDustMass = bestDerived(scene.derived_measurements, planet.pl_name, 'circumplanetary_disk_dust_mass');
  const cpdAccretion = bestDerived(scene.derived_measurements, planet.pl_name, 'accretion_rate');
  const massLoss = focalMassLoss(scene.derived_measurements, planet.pl_name);
  const albedo = focalAlbedo(scene.derived_measurements, planet.pl_name);
  const debrisDisks = focalDebrisDisks(scene.derived_measurements, planet.pl_name);
  const oblateness = focalStellarOblateness(
    scene.derived_measurements, planet.pl_name, planet.st_rad, planet.st_mass,
  );
  const planetSpinPeriodHours = planetSpin?.value && planet.pl_rade
    ? (2 * Math.PI * planet.pl_rade * 6371) / planetSpin.value / 3600
    : null;

  return (
    <div
      style={{
        position: 'fixed', top: HEADER_OFFSET_PX, left: 16, zIndex: 10,
        background: 'rgba(11, 13, 18, 0.85)', color: 'var(--fg)',
        padding: '0.85rem 1rem 0.7rem', borderRadius: 4,
        fontSize: '0.85rem', width: 320, maxHeight: `calc(100vh - ${HEADER_OFFSET_PX + 32}px)`,
        overflowY: 'auto', lineHeight: 1.5, backdropFilter: 'blur(4px)',
        border: '1px solid var(--border)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '0.5rem' }}>
        <h2 style={{ margin: 0, fontSize: '1rem' }}>{planet.pl_name}</h2>
        <button
          onClick={onCollapse}
          title="Collapse panel (full-screen scene)"
          style={{ background: 'transparent', color: 'var(--fg-muted)', border: '1px solid var(--border)', padding: '0.05rem 0.4rem', borderRadius: 3, cursor: 'pointer', fontSize: '0.85rem', flexShrink: 0 }}
        >
          ‹
        </button>
      </div>
      <p style={{ margin: '0.1rem 0 0.6rem', fontSize: '0.75rem', color: 'var(--fg-muted)' }}>
        orbiting {planet.hostname}{planet.disc_year && <> · discovered {planet.disc_year}</>}
      </p>

      {/* Quick stats — always visible */}
      <dl style={{ margin: 0, display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0.2rem 0.7rem', fontSize: '0.78rem' }}>
        <dt style={{ color: 'var(--fg-muted)' }}>body</dt>
        <dd style={{ margin: 0 }}>{scene_hints.body_type}</dd>
        <dt style={{ color: 'var(--fg-muted)' }}>sun in sky</dt>
        <dd style={{ margin: 0 }}>
          {scene_hints.sun_angular_size_deg != null
            ? `${scene_hints.sun_angular_size_deg.toFixed(2)}° diameter`
            : 'unknown'}
        </dd>
        <dt style={{ color: 'var(--fg-muted)' }}>day length</dt>
        <dd style={{ margin: 0 }}>
          {(() => {
            const d = humanizeHours(scene_hints.day_length_hours);
            return d ? `${d.value} ${d.unit}` : 'unknown';
          })()}
        </dd>
        <dt style={{ color: 'var(--fg-muted)' }}>brightness</dt>
        <dd style={{ margin: 0 }}>{scene_hints.insolation_label ?? 'unknown'}</dd>
        <dt style={{ color: 'var(--fg-muted)' }}>survival</dt>
        <dd style={{ margin: 0 }}>
          {scene_hints.death_seconds != null
            ? scene_hints.death_seconds < 60
              ? `~${scene_hints.death_seconds} sec`
              : `~${Math.round(scene_hints.death_seconds / 60)} min`
            : 'survivable on temperature alone'}
        </dd>
      </dl>

      {/* Spin-orbit obliquity. Lights up for any focal planet with a
          projected or true obliquity in derived_measurements — that is the
          5 curated "Tilted & Tumbling" deep dives plus the ~228 systems
          bulk-promoted from the NASA Exoplanet Archive (migration 086). The
          scene tilts the orbit relative to the star's equator to match this
          angle, and the provenance line distinguishes curated from catalog. */}
      {obliquity && (
        <Section
          label="Spin-orbit obliquity"
          open={openSections.has('obliq')}
          onToggle={() => toggle('obliq')}
        >
          <p style={{ margin: '0 0 0.3rem', fontSize: '0.82rem' }}>
            {obliquity.kind === 'true' ? 'True obliquity ψ' : 'Projected obliquity λ'}
            {' = '}
            <strong>{obliquity.deg.toFixed(1)}°</strong>
          </p>
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.74rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
            {obliquity.kind === 'projected'
              ? 'Sky-projected angle between the stellar spin axis and the orbital plane (Rossiter-McLaughlin). The true 3-D node orientation is unknown, so the tilt direction shown is illustrative; the magnitude is the measurement.'
              : 'De-projected 3-D angle between the stellar spin axis and the orbital plane. The scene tilts the orbit, not the planet body.'}
          </p>
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
            Source: {provenanceLabel(obliquity.provenance)}
          </p>
          {obliquity.provenance === 'curated' && obliquity.note && (
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              {obliquity.note}
            </p>
          )}
          {obliquity.bibcode && (
            <a
              href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(obliquity.bibcode)}/abstract`}
              target="_blank"
              rel="noopener noreferrer"
              style={{ fontSize: '0.74rem' }}
            >
              ADS →
            </a>
          )}
        </Section>
      )}

      {/* Host-star rotation — catalog/curated st_rotp + st_vsin. The rotation
          period drives the visible star spin in the scene. */}
      {(rotp || vsini) && (
        <Section
          label="Host-star rotation"
          open={openSections.has('starspin')}
          onToggle={() => toggle('starspin')}
        >
          <dl style={{ margin: '0 0 0.4rem', display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0.15rem 0.6rem', fontSize: '0.8rem' }}>
            {rotp?.value != null && (
              <>
                <dt style={{ color: 'var(--fg-muted)' }}>rotation period</dt>
                <dd style={{ margin: 0 }}><strong>{rotp.value.toFixed(rotp.value < 10 ? 2 : 1)}</strong> days</dd>
              </>
            )}
            {vsini?.value != null && (
              <>
                <dt style={{ color: 'var(--fg-muted)' }}>v sin i</dt>
                <dd style={{ margin: 0 }}><strong>{vsini.value.toFixed(1)}</strong> km/s</dd>
              </>
            )}
          </dl>
          {rotp?.value != null && (
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              The star's visible rotation in the scene is driven by this period (rate stylized, like the orbit pacing), about the same spin axis the orbit tilts against.
            </p>
          )}
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
            Source: {provenanceLabel((rotp ?? vsini)!.provenance)}
          </p>
          <div style={{ display: 'flex', gap: '0.6rem', fontSize: '0.74rem' }}>
            {rotp?.bibcode && (
              <a href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(rotp.bibcode)}/abstract`} target="_blank" rel="noopener noreferrer">period: ADS →</a>
            )}
            {vsini?.bibcode && vsini.bibcode !== rotp?.bibcode && (
              <a href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(vsini.bibcode)}/abstract`} target="_blank" rel="noopener noreferrer">v sin i: ADS →</a>
            )}
          </div>
        </Section>
      )}

      {/* Stellar oblateness — centrifugal flattening from the host's spin,
          derived live from rotation_period (or v sin i) + st_rad + st_mass.
          Lights up for any host whose computed f exceeds 0.5%; below that
          the squash is visually imperceptible and the section stays hidden
          (Sun-like rotators sit there). The scene compresses the photosphere
          along its spin axis (+Y) by the same factor. */}
      {oblateness != null && (
        <Section
          label="Stellar oblateness"
          open={openSections.has('starsquash')}
          onToggle={() => toggle('starsquash')}
        >
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.82rem' }}>
            Flattening <strong>f = {(oblateness * 100).toFixed(oblateness < 0.05 ? 2 : 1)}%</strong>
            <span style={{ color: 'var(--fg-muted)' }}> ({((1 / (1 - oblateness)) - 1).toFixed(2)}× equatorial bulge)</span>
          </p>
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.74rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
            Centrifugal flattening from the host's measured spin: f ≈ Ω²R³/(2GM). The scene squashes the photosphere along its spin axis by the same factor — the equator stays at the catalog radius, the poles shrink. Below 0.5% the section doesn't appear because the squash isn't visible.
          </p>
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
            Derived from <strong>{rotp?.value != null ? 'rotation period' : 'v sin i'}</strong>, <strong>st_rad</strong>, <strong>st_mass</strong> — no new curation step, but the rotation input has a paper.
          </p>
          {(() => {
            // Surface the underlying rotation paper directly in this section.
            // Researchers hitting "Stellar oblateness" first shouldn't have to
            // open "Host-star rotation" separately to find the citation.
            const source = rotp?.value != null ? rotp : vsini;
            if (!source?.bibcode) return null;
            return (
              <a
                href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(source.bibcode)}/abstract`}
                target="_blank" rel="noopener noreferrer"
                style={{ fontSize: '0.74rem' }}
              >
                {rotp?.value != null ? 'rotation period' : 'v sin i'}: ADS →
              </a>
            );
          })()}
        </Section>
      )}

      {/* Planet axial rotation — currently only bet Pic b and AB Pic b have
          measured rotation_velocity in derived_measurements. The body in the
          scene visibly spins about a +Y reference axis at a stylized rate. */}
      {planetSpin?.value != null && (
        <Section
          label="Planet rotation"
          open={openSections.has('planetspin')}
          onToggle={() => toggle('planetspin')}
        >
          <dl style={{ margin: '0 0 0.4rem', display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0.15rem 0.6rem', fontSize: '0.8rem' }}>
            <dt style={{ color: 'var(--fg-muted)' }}>rotation velocity</dt>
            <dd style={{ margin: 0 }}>
              <strong>{planetSpin.value.toFixed(0)}</strong> km/s
              {planetSpin.unc_hi != null && planetSpin.unc_lo != null && (
                <span style={{ color: 'var(--fg-muted)' }}> +{planetSpin.unc_hi.toFixed(0)} / -{planetSpin.unc_lo.toFixed(0)}</span>
              )}
            </dd>
            {planetSpinPeriodHours != null && (
              <>
                <dt style={{ color: 'var(--fg-muted)' }}>rotation period</dt>
                <dd style={{ margin: 0 }}>
                  <strong>{planetSpinPeriodHours.toFixed(planetSpinPeriodHours < 5 ? 2 : 1)}</strong> hours
                </dd>
              </>
            )}
          </dl>
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
            The planet visibly spins about a +Y reference axis. The true spin-axis orientation is not generally measured for exoplanets, so the axis shown is a convention; the rate is stylized like the orbit pacing, with relative rates preserved.
          </p>
          {planetSpin.model === 'CO line broadening' || (planetSpin.curator_note ?? '').toLowerCase().includes('vsin') ? (
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              Note: catalog v sin i bounds the true equatorial speed from below, so the period shown is an upper bound when the spin axis is inclined to our line of sight.
            </p>
          ) : null}
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
            Source: {provenanceLabel(planetSpin.provenance)}
          </p>
          {planetSpin.provenance === 'curated' && planetSpin.curator_note && (
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              {planetSpin.curator_note}
            </p>
          )}
          {planetSpin.bibcode && (
            <a
              href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(planetSpin.bibcode)}/abstract`}
              target="_blank"
              rel="noopener noreferrer"
              style={{ fontSize: '0.74rem' }}
            >
              ADS →
            </a>
          )}
        </Section>
      )}

      {/* Circumplanetary disc — currently only PDS 70 b and c (the famous
          forming-planet system). Explains what the dust ring in the scene
          IS, so first-time viewers aren't left wondering why this planet has
          a halo and others don't. */}
      {(cpdDustMass || cpdAccretion) && (
        <Section
          label="Circumplanetary disk"
          open={openSections.has('cpd')}
          onToggle={() => toggle('cpd')}
        >
          <p style={{ margin: '0 0 0.5rem', fontSize: '0.78rem', lineHeight: 1.5 }}>
            This planet is still forming and is surrounded by a disc of dust and
            gas it accretes from. The dust band in the scene is a stylized
            rendering of that circumplanetary disc — same physical structure
            VLT/ALMA imaged directly around the PDS 70 planets, the first ever
            resolved.
          </p>
          <dl style={{ margin: '0 0 0.4rem', display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0.15rem 0.6rem', fontSize: '0.8rem' }}>
            {cpdDustMass?.value != null && (
              <>
                <dt style={{ color: 'var(--fg-muted)' }}>dust mass</dt>
                <dd style={{ margin: 0 }}>
                  <strong>{cpdDustMass.value}</strong> M⊕
                </dd>
              </>
            )}
            {cpdAccretion?.value != null && (
              <>
                <dt style={{ color: 'var(--fg-muted)' }}>accretion rate</dt>
                <dd style={{ margin: 0 }}>
                  <strong>{cpdAccretion.value.toExponential(1)}</strong> M♃/yr
                </dd>
              </>
            )}
          </dl>
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
            Source: {provenanceLabel((cpdDustMass ?? cpdAccretion)!.provenance)}
          </p>
          {(cpdDustMass ?? cpdAccretion)?.curator_note && (
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              {(cpdDustMass ?? cpdAccretion)!.curator_note}
            </p>
          )}
          <div style={{ display: 'flex', gap: '0.6rem', fontSize: '0.74rem' }}>
            {cpdDustMass?.bibcode && (
              <a
                href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(cpdDustMass.bibcode)}/abstract`}
                target="_blank" rel="noopener noreferrer"
              >dust mass: ADS →</a>
            )}
            {cpdAccretion?.bibcode && cpdAccretion.bibcode !== cpdDustMass?.bibcode && (
              <a
                href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(cpdAccretion.bibcode)}/abstract`}
                target="_blank" rel="noopener noreferrer"
              >accretion: ADS →</a>
            )}
          </div>
        </Section>
      )}

      {/* Atmospheric escape — currently 8 planets carry curated mass_loss_rate
          rows (migration 088 + Kepler-1520 b from 036). Explains the colored
          comet-like tail in the scene and credits the measurement paper. */}
      {massLoss && (
        <Section
          label="Atmospheric escape"
          open={openSections.has('escape')}
          onToggle={() => toggle('escape')}
        >
          <p style={{ margin: '0 0 0.5rem', fontSize: '0.78rem', lineHeight: 1.5 }}>
            {massLoss.mechanism === 'hydrogen'
              ? 'This planet is losing hydrogen from its upper atmosphere, traced in Lyman-alpha transit observations. The blue tail in the scene is a stylized rendering of that escaping exosphere.'
              : massLoss.mechanism === 'helium'
              ? 'This planet is losing helium from its upper atmosphere, traced via the 1083 nm metastable helium triplet. The pink tail in the scene is a stylized rendering of that escaping exosphere.'
              : 'This planet is disintegrating — surface material vaporizes and forms a trailing dust cloud, occulting the host star asymmetrically each transit.'}
            {massLoss.leading && ' Unusually, the tail leads the planet in its orbit (pre-transit ingress), consistent with Roche-lobe overflow advected into the stellar rest frame.'}
          </p>
          <dl style={{ margin: '0 0 0.4rem', display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0.15rem 0.6rem', fontSize: '0.8rem' }}>
            <dt style={{ color: 'var(--fg-muted)' }}>mass loss</dt>
            <dd style={{ margin: 0 }}>
              <strong>{massLoss.value < 0.01 ? massLoss.value.toExponential(1) : massLoss.value.toFixed(massLoss.value < 1 ? 3 : 1)}</strong> M⊕/Gyr
              {massLoss.uncHi != null && massLoss.uncLo != null && (
                <span style={{ color: 'var(--fg-muted)' }}> ± {massLoss.uncHi.toFixed(massLoss.uncHi < 1 ? 2 : 1)}</span>
              )}
            </dd>
            {massLoss.model && (
              <>
                <dt style={{ color: 'var(--fg-muted)' }}>mechanism</dt>
                <dd style={{ margin: 0, fontSize: '0.78rem' }}>{massLoss.model}</dd>
              </>
            )}
          </dl>
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
            Source: {provenanceLabel(massLoss.provenance)}
          </p>
          {massLoss.curatorNote && (
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              {massLoss.curatorNote}
            </p>
          )}
          {massLoss.bibcode && (
            <a
              href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(massLoss.bibcode)}/abstract`}
              target="_blank" rel="noopener noreferrer"
              style={{ fontSize: '0.74rem' }}
            >
              ADS →
            </a>
          )}
        </Section>
      )}

      {/* Reflective albedo — currently 11 planets carry a curated
          geometric_albedo or bond_albedo row (migration 089 + WASP-80 b /
          GJ 1214 b from prior migrations). The scene modulates the planet
          body's reflected-light brightness by the measured value; HD 189733 b
          also gets a blue reflection tint (wavelength-dependent albedo,
          high in blue, suppressed in red by sodium). Phase-curve planets
          (KELT-9 b-class) bypass the reflective path entirely so albedo
          isn't applied to them. */}
      {albedo && (
        <Section
          label="Albedo"
          open={openSections.has('albedo')}
          onToggle={() => toggle('albedo')}
        >
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.82rem' }}>
            {albedo.isUpperLimit ? (
              <>
                {albedo.kind === 'geometric' ? 'Geometric albedo A_g' : 'Bond albedo A_B'}{' '}
                <strong>&lt; {albedo.value.toFixed(3)}</strong>{' '}
                <span style={{ color: 'var(--fg-muted)' }}>(non-detection)</span>
              </>
            ) : (
              <>
                {albedo.kind === 'geometric' ? 'Geometric albedo A_g' : 'Bond albedo A_B'}{' '}
                <strong>= {albedo.value.toFixed(albedo.value < 0.1 ? 4 : 2)}</strong>
                {albedo.uncHi != null && albedo.uncLo != null && (
                  <span style={{ color: 'var(--fg-muted)' }}>
                    {' '}{albedo.uncHi === albedo.uncLo
                      ? `± ${albedo.uncHi.toFixed(albedo.uncHi < 0.1 ? 3 : 2)}`
                      : `+${albedo.uncHi.toFixed(2)} / -${albedo.uncLo.toFixed(2)}`}
                  </span>
                )}
              </>
            )}
          </p>
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.74rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
            {albedo.kind === 'geometric'
              ? "Geometric albedo: ratio of brightness at zero phase angle to a flat Lambertian surface. The scene scales reflected-light brightness by this measurement; the reference baseline is 0.30."
              : "Bond albedo: fraction of incident bolometric energy reflected by the planet. Drives reflected-light brightness in the scene relative to the 0.30 reference baseline."}
            {albedo.reflectionTint && ' Because this planet\'s albedo is much higher in the blue than the red (sodium absorption in the upper atmosphere), its reflected starlight is tinted blue in the scene — the famous deep-cobalt color reported by Evans et al.'}
          </p>
          {albedo.model && (
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.74rem', color: 'var(--fg-muted)' }}>
              Method: {albedo.model}
            </p>
          )}
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
            Source: {provenanceLabel(albedo.provenance)}
          </p>
          {albedo.curatorNote && (
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              {albedo.curatorNote}
            </p>
          )}
          {albedo.bibcode && (
            <a
              href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(albedo.bibcode)}/abstract`}
              target="_blank" rel="noopener noreferrer"
              style={{ fontSize: '0.74rem' }}
            >
              ADS →
            </a>
          )}
        </Section>
      )}

      {/* System-level debris disk(s). Currently 5 systems qualify
          (migration 090): bet Pic, HR 8799, HD 95086, eps Eri, 51 Eri.
          51 Eri has TWO belts (warm + cold) — each entry in `debrisDisks`
          carries its own bibcode and is rendered as a separate row block.
          The scene draws each belt as a wide flat ring (or narrow ring
          for SED-fit single-radius belts) around the host star at AU
          scale. Inclination from the same paper tilts the ring when
          measured. */}
      {debrisDisks.length > 0 && (
        <Section
          label={debrisDisks.length > 1 ? `Debris disks · ${debrisDisks.length}` : 'Debris disk'}
          open={openSections.has('debris')}
          onToggle={() => toggle('debris')}
        >
          <p style={{ margin: '0 0 0.5rem', fontSize: '0.78rem', lineHeight: 1.5 }}>
            {debrisDisks.length === 1
              ? 'A resolved debris disk has been measured around the host star. The scene shows it as a wide dusty ring at the measured AU scale.'
              : `${debrisDisks.length} distinct debris belts have been measured around the host star (warm inner + cold outer, the same architecture as HR 8799 and HD 95086). Each is shown at its measured AU scale.`}
          </p>
          {debrisDisks.map((belt, i) => {
            const isSingleRadius = belt.outerAu == null;
            return (
              <div
                key={`belt-${belt.bibcode ?? i}`}
                style={{
                  margin: '0 0 0.6rem',
                  paddingTop: i === 0 ? 0 : '0.5rem',
                  borderTop: i === 0 ? 'none' : '1px solid var(--border)',
                }}
              >
                <dl style={{ margin: '0 0 0.3rem', display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0.15rem 0.6rem', fontSize: '0.8rem' }}>
                  {isSingleRadius ? (
                    <>
                      <dt style={{ color: 'var(--fg-muted)' }}>blackbody radius</dt>
                      <dd style={{ margin: 0 }}>
                        <strong>{belt.innerAu.toFixed(belt.innerAu < 10 ? 1 : 0)}</strong> AU
                      </dd>
                    </>
                  ) : (
                    <>
                      <dt style={{ color: 'var(--fg-muted)' }}>inner edge</dt>
                      <dd style={{ margin: 0 }}><strong>{belt.innerAu.toFixed(0)}</strong> AU</dd>
                      <dt style={{ color: 'var(--fg-muted)' }}>outer edge</dt>
                      <dd style={{ margin: 0 }}><strong>{belt.outerAu!.toFixed(0)}</strong> AU</dd>
                    </>
                  )}
                  {belt.inclinationDeg != null && (
                    <>
                      <dt style={{ color: 'var(--fg-muted)' }}>inclination</dt>
                      <dd style={{ margin: 0 }}>
                        <strong>{belt.inclinationDeg.toFixed(belt.inclinationDeg < 10 ? 2 : 1)}°</strong>
                        {belt.inclinationUncHi != null && belt.inclinationUncLo != null && (
                          <span style={{ color: 'var(--fg-muted)' }}>
                            {' '}{belt.inclinationUncHi === belt.inclinationUncLo
                              ? `± ${belt.inclinationUncHi}`
                              : `+${belt.inclinationUncHi}/-${belt.inclinationUncLo}`}
                          </span>
                        )}
                      </dd>
                    </>
                  )}
                  {belt.dustTemperatureK != null && (
                    <>
                      <dt style={{ color: 'var(--fg-muted)' }}>dust temperature</dt>
                      <dd style={{ margin: 0 }}>
                        <strong>{belt.dustTemperatureK}</strong> K
                        {belt.dustTemperatureUncHi != null && belt.dustTemperatureUncLo != null && (
                          <span style={{ color: 'var(--fg-muted)' }}>
                            {' '}{belt.dustTemperatureUncHi === belt.dustTemperatureUncLo
                              ? `± ${belt.dustTemperatureUncHi}`
                              : `+${belt.dustTemperatureUncHi}/-${belt.dustTemperatureUncLo}`}
                          </span>
                        )}
                      </dd>
                    </>
                  )}
                </dl>
                {belt.model && (
                  <p style={{ margin: '0 0 0.3rem', fontSize: '0.74rem', color: 'var(--fg-muted)' }}>
                    {isSingleRadius ? 'SED fit' : 'Method'}: {belt.model}
                  </p>
                )}
                {isSingleRadius && (
                  <p style={{ margin: '0 0 0.3rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
                    Single-radius blackbody fit, not resolved imaging — the rendered ring is intentionally narrow to reflect this.
                  </p>
                )}
                <p style={{ margin: '0 0 0.3rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
                  Source: {provenanceLabel(belt.provenance)}
                </p>
                {belt.curatorNote && (
                  <p style={{ margin: '0 0 0.3rem', fontSize: '0.72rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
                    {belt.curatorNote}
                  </p>
                )}
                <div style={{ display: 'flex', gap: '0.6rem', fontSize: '0.74rem' }}>
                  {belt.bibcode && (
                    <a
                      href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(belt.bibcode)}/abstract`}
                      target="_blank" rel="noopener noreferrer"
                    >
                      {belt.dustTemperatureBibcode && belt.dustTemperatureBibcode !== belt.bibcode
                        ? 'geometry: ADS →'
                        : 'ADS →'}
                    </a>
                  )}
                  {belt.dustTemperatureBibcode && belt.dustTemperatureBibcode !== belt.bibcode && (
                    <a
                      href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(belt.dustTemperatureBibcode)}/abstract`}
                      target="_blank" rel="noopener noreferrer"
                    >
                      temperature: ADS →
                    </a>
                  )}
                </div>
              </div>
            );
          })}
        </Section>
      )}

      {/* Sky position */}
      <Section
        label="Sky position"
        open={openSections.has('sky')}
        onToggle={() => toggle('sky')}
      >
        {planet.ra != null && planet.dec != null ? (
          <p style={{ margin: '0 0 0.3rem' }}>
            RA <code>{planet.ra.toFixed(3)}°</code> · Dec <code>{planet.dec.toFixed(3)}°</code>
          </p>
        ) : <p style={{ margin: '0 0 0.3rem', color: 'var(--fg-muted)' }}>position not in catalog</p>}
        {distance_pc != null && (
          <p style={{ margin: 0, color: 'var(--fg-muted)' }}>
            <strong style={{ color: 'var(--fg)' }}>{(distance_pc * 3.2616).toFixed(1)}</strong> light-years away
            ({distance_pc.toFixed(1)} pc)
            {host_star?.distance_gspphot_pc != null && <> · via Gaia DR3</>}
            {host_star?.distance_gspphot_pc == null && planet.sy_dist == null && planet.distance_manual_pc != null && (
              <> · literature distance{planet.distance_manual_source ? ` (${planet.distance_manual_source})` : ''}</>
            )}
          </p>
        )}
      </Section>

      {/* Companions — wide-binary / triple-star components from WDS etc.
          Only shown when the catalog records at least one companion. */}
      {scene.binary_companions.length > 0 && (
        <Section
          label={`Companions · ${scene.binary_companions.length}`}
          open={openSections.has('comp')}
          onToggle={() => toggle('comp')}
        >
          <p style={{ margin: '0 0 0.4rem', fontSize: '0.74rem', color: 'var(--fg-muted)' }}>
            {planet.cb_flag === 1
              ? <>{planet.pl_name} is circumbinary — it orbits the close
                  inner pair shown at the center of the scene, not a
                  single primary star. Wide companions (if any) are shown
                  at their projected positions.</>
              : <>{planet.pl_name} orbits the primary only. Other components
                  are shown in the scene at their projected positions.</>}
          </p>
          {scene.binary_companions.map((c, i) => {
            const sepAU = c.separation_arcsec != null && distance_pc != null
              ? c.separation_arcsec * distance_pc
              : null;
            const kind = companionKind(c.component_spectype);
            const insideOrbit = sepAU != null && planet.pl_orbsmax != null
              && sepAU < planet.pl_orbsmax;
            return (
              <div
                key={c.component_designation}
                style={{ marginTop: i === 0 ? 0 : '0.45rem', fontSize: '0.78rem' }}
              >
                <div style={{ fontWeight: 600 }}>
                  {c.component_designation}
                  {(c.component_spectype || kind) && (
                    <span style={{ fontWeight: 400, color: 'var(--fg-muted)', marginLeft: '0.4rem' }}>
                      {[c.component_spectype, kind].filter(Boolean).join(' · ')}
                    </span>
                  )}
                </div>
                <div style={{ color: 'var(--fg-muted)', fontSize: '0.74rem' }}>
                  {c.inner_binary ? (
                    <>inner-binary partner — {planet.pl_name} orbits both</>
                  ) : sepAU != null ? (
                    <>~{sepAU >= 10 ? sepAU.toFixed(0) : sepAU.toFixed(1)} AU projected
                      {c.position_angle_deg != null && <> · PA {c.position_angle_deg.toFixed(0)}°</>}
                    </>
                  ) : 'separation unknown'}
                  {c.source_catalog && <> · {c.source_catalog}</>}
                </div>
                {!c.inner_binary && insideOrbit && (
                  <div style={{ color: 'var(--tier-b)', fontSize: '0.72rem', marginTop: '0.15rem' }}>
                    inside {planet.pl_name}'s orbit — look toward the host, not past it
                  </div>
                )}
              </div>
            );
          })}
        </Section>
      )}

      {/* Discovery */}
      <Section
        label="Discovery"
        open={openSections.has('disc')}
        onToggle={() => toggle('disc')}
      >
        <dl style={{ margin: 0, display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '0.15rem 0.6rem', fontSize: '0.78rem' }}>
          {planet.disc_year && <><dt style={{ color: 'var(--fg-muted)' }}>year</dt><dd style={{ margin: 0 }}>{planet.disc_year}</dd></>}
          {planet.discoverymethod && <><dt style={{ color: 'var(--fg-muted)' }}>method</dt><dd style={{ margin: 0 }}>{planet.discoverymethod}</dd></>}
          {planet.disc_facility && <><dt style={{ color: 'var(--fg-muted)' }}>facility</dt><dd style={{ margin: 0 }}>{planet.disc_facility}</dd></>}
          {planet.disc_telescope && <><dt style={{ color: 'var(--fg-muted)' }}>telescope</dt><dd style={{ margin: 0 }}>{planet.disc_telescope}</dd></>}
          {planet.disc_instrument && <><dt style={{ color: 'var(--fg-muted)' }}>instrument</dt><dd style={{ margin: 0 }}>{planet.disc_instrument}</dd></>}
        </dl>
      </Section>

      {/* Citation */}
      <Section
        label={`Citation${paper?.citation_count != null ? ` · ${paper.citation_count.toLocaleString()} cites` : ''}`}
        open={openSections.has('cite')}
        onToggle={() => toggle('cite')}
      >
        {paper ? (
          <>
            <p style={{ margin: '0 0 0.3rem', fontSize: '0.8rem', fontWeight: 600, lineHeight: 1.35 }}>
              {paper.title ?? paper.bibcode}
            </p>
            {paper.authors.length > 0 && (
              <p style={{ margin: '0 0 0.3rem', fontSize: '0.74rem', color: 'var(--fg-muted)' }}>
                {paper.authors.slice(0, 3).join(', ')}
                {paper.authors.length > 3 && ` +${paper.authors.length - 3} more`}
              </p>
            )}
            <p style={{ margin: '0 0 0.4rem', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
              {[paper.journal, paper.pub_date?.slice(0, 4)].filter(Boolean).join(' · ')}
            </p>
            {paper.abstract && (
              <p style={{ margin: '0 0 0.4rem', fontSize: '0.74rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
                {paper.abstract.length > 240 ? paper.abstract.slice(0, 240).trimEnd() + '…' : paper.abstract}
              </p>
            )}
            <div style={{ display: 'flex', gap: '0.6rem', fontSize: '0.74rem' }}>
              <a href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(paper.bibcode)}/abstract`} target="_blank" rel="noopener noreferrer">ADS →</a>
              {paper.doi && <a href={`https://doi.org/${paper.doi}`} target="_blank" rel="noopener noreferrer">DOI →</a>}
              {paper.arxiv_id && <a href={`https://arxiv.org/abs/${paper.arxiv_id}`} target="_blank" rel="noopener noreferrer">arXiv →</a>}
            </div>
          </>
        ) : <p style={{ margin: 0, color: 'var(--fg-muted)', fontSize: '0.78rem' }}>No ADS record cached for this discovery paper.</p>}
      </Section>
    </div>
  );
}

function Section({
  label, open, onToggle, children,
}: {
  label: string; open: boolean; onToggle: () => void; children: React.ReactNode;
}) {
  return (
    <div style={{ marginTop: '0.6rem', paddingTop: '0.5rem', borderTop: '1px solid var(--border)' }}>
      <button
        onClick={onToggle}
        style={{ background: 'transparent', color: 'var(--fg)', border: 'none', padding: 0, cursor: 'pointer', width: '100%', textAlign: 'left', fontSize: '0.82rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.4rem' }}
      >
        <span style={{ color: 'var(--fg-muted)', display: 'inline-block', width: '0.7rem' }}>{open ? '▾' : '▸'}</span>
        {label}
      </button>
      {open && <div style={{ marginTop: '0.4rem' }}>{children}</div>}
    </div>
  );
}

function ExpandTab({ onExpand }: { onExpand: () => void }) {
  return (
    <button
      onClick={onExpand}
      title="Show planet info panel"
      style={{
        position: 'fixed', top: HEADER_OFFSET_PX, left: 0, zIndex: 10,
        background: 'rgba(11, 13, 18, 0.85)', color: 'var(--fg)',
        border: '1px solid var(--border)', borderLeft: 'none',
        padding: '0.5rem 0.6rem', borderTopRightRadius: 4, borderBottomRightRadius: 4,
        cursor: 'pointer', fontSize: '0.95rem',
        backdropFilter: 'blur(4px)',
      }}
    >
      ›
    </button>
  );
}

// Top-right HUD: copy-link button + exit button, grouped in a single
// fixed-position flex row so they share the same vertical baseline and
// don't have to know each other's widths to avoid overlap.
function TopRightHUD({ to }: { to: string }) {
  return (
    <div
      style={{
        position: 'fixed', top: HEADER_OFFSET_PX, right: 16, zIndex: 10,
        display: 'flex', alignItems: 'center', gap: '0.4rem',
      }}
    >
      <CopyLinkButton />
      <CloseButton to={to} />
    </div>
  );
}

function CopyLinkButton() {
  const [copied, setCopied] = useState(false);
  const handleClick = async () => {
    try {
      await navigator.clipboard.writeText(window.location.href);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1500);
    } catch {
      // clipboard API not available (insecure context, etc.); silently skip
    }
  };
  return (
    <button
      onClick={handleClick}
      title="Copy a link to this scene at the current camera angle"
      style={{
        background: 'rgba(11, 13, 18, 0.85)', color: 'var(--fg)',
        padding: '0.35rem 0.6rem', borderRadius: 4,
        fontSize: '0.85rem', fontWeight: 600,
        border: '1px solid var(--border)', backdropFilter: 'blur(4px)',
        cursor: 'pointer', fontFamily: 'inherit',
      }}
    >
      {copied ? 'link copied' : 'copy link'}
    </button>
  );
}

function CloseButton({ to }: { to: string }) {
  return (
    <Link
      to={to}
      replace
      title="Exit 3D scene"
      style={{
        background: 'rgba(11, 13, 18, 0.85)', color: 'var(--fg)',
        padding: '0.35rem 0.6rem', borderRadius: 4, textDecoration: 'none',
        fontSize: '0.85rem', fontWeight: 600,
        border: '1px solid var(--border)', backdropFilter: 'blur(4px)',
        display: 'flex', alignItems: 'center', gap: '0.35rem',
      }}
    >
      <span style={{ fontSize: '1rem', lineHeight: 1 }}>✕</span> exit
    </Link>
  );
}

// Minimal subset of the underlying three-stdlib OrbitControls API we need
// for hash sync. drei's <OrbitControls> forwards its ref to this instance.
type OrbitControlsHandle = {
  update: () => void;
  target: THREE.Vector3;
};

// Parse the URL hash into a structured scene state. Hash format is a flat
// `&`-separated list of `key=value` pairs (URLSearchParams-compatible, but
// we hand-parse to keep commas in `cam` unencoded):
//   cam=<cx>,<cy>,<cz>,<tx>,<ty>,<tz>   camera position + OrbitControls target,
//                                       both in scene AU. The target must be
//                                       captured separately from the camera —
//                                       right-click pan moves the target, which
//                                       a (camera − target) spherical offset
//                                       would silently roll up and discard.
//   t=<seconds>                         simulation clock (orbital phase)
//   v=surface                           view mode (omitted ⇒ system)
// All fields are independent; missing/malformed fields are skipped.
type ParsedSceneHash = {
  cam?: { cx: number; cy: number; cz: number; tx: number; ty: number; tz: number };
  t?: number;
  v?: 'system' | 'surface';
};
function parseSceneHash(hash: string): ParsedSceneHash {
  const result: ParsedSceneHash = {};
  const h = hash.replace(/^#/, '');
  if (!h) return result;
  for (const part of h.split('&')) {
    const eq = part.indexOf('=');
    if (eq < 0) continue;
    const key = part.slice(0, eq);
    const val = part.slice(eq + 1);
    if (key === 'cam') {
      const nums = val.split(',').map(parseFloat);
      if (nums.length === 6 && nums.every(isFinite)) {
        result.cam = {
          cx: nums[0], cy: nums[1], cz: nums[2],
          tx: nums[3], ty: nums[4], tz: nums[5],
        };
      }
    } else if (key === 't') {
      const t = parseFloat(val);
      if (isFinite(t)) result.t = t;
    } else if (key === 'v') {
      if (val === 'surface' || val === 'system') result.v = val;
    }
  }
  return result;
}

// Format a cam= field from a camera position + target. 4 decimal places gives
// ~0.0001 AU precision, enough to be visually indistinguishable from the
// captured state at any zoom level the OrbitControls min/maxDistance allows
// (down to TRAPPIST-1's sub-0.01-AU planets).
function formatCamField(cam: ParsedSceneHash['cam']): string | null {
  if (!cam) return null;
  return `cam=${cam.cx.toFixed(4)},${cam.cy.toFixed(4)},${cam.cz.toFixed(4)},`
    + `${cam.tx.toFixed(4)},${cam.ty.toFixed(4)},${cam.tz.toFixed(4)}`;
}

// Sync the full scene state with the URL hash. Each frame:
//   1) On first frame in system mode, apply the hash's cam (if any) to the
//      camera + OrbitControls target (viewMode and clock are already applied
//      at ScenePage mount — they have to be set before the Canvas first
//      renders).
//   2) Read current camera position, OrbitControls target, clock, viewMode,
//      and write them back to the URL hash via history.replaceState. Throttled
//      to ~5 Hz so back/forward history isn't flooded.
//
// useFrame polling avoids the timing/lifecycle fragility of subscribing to
// OrbitControls' 'change' event (where controlsRef.current can be null during
// the subscribe useEffect). Per-frame cost is bounded by a handful of Vector3
// reads and a short string compare.
function HashWriter({
  controlsRef, viewMode, clockRef,
}: {
  controlsRef: React.MutableRefObject<unknown>;
  viewMode: 'system' | 'surface';
  clockRef: React.MutableRefObject<number>;
}) {
  const { camera } = useThree();
  const applied = useRef(false);
  const lastWriteAt = useRef(0);
  const lastWrittenHash = useRef<string>('');

  useFrame(() => {
    const controls = controlsRef.current as OrbitControlsHandle | null;

    // First-frame apply (system mode only): drop the camera + target onto the
    // hash-specified vantage. useFrame instead of useEffect because
    // controlsRef.current is reliably wired by the first frame; drei's
    // ref-forwarding timing can leave it null in useEffect.
    if (!applied.current) {
      applied.current = true;
      if (viewMode === 'system' && controls) {
        const parsed = parseSceneHash(window.location.hash);
        if (parsed.cam) {
          camera.position.set(parsed.cam.cx, parsed.cam.cy, parsed.cam.cz);
          controls.target.set(parsed.cam.tx, parsed.cam.ty, parsed.cam.tz);
          controls.update();
        }
      }
      // fall through to write current state on this same frame
    }

    // Throttle URL writes to ~5 Hz.
    const now = performance.now();
    if (now - lastWriteAt.current < 200) return;

    // Build the new hash. cam is computed only in system mode (OrbitControls
    // drives both camera and target there). In surface mode we preserve the
    // previously captured cam so toggling surface→system doesn't lose it.
    const parts: string[] = [];
    if (viewMode === 'system' && controls) {
      const camField = formatCamField({
        cx: camera.position.x, cy: camera.position.y, cz: camera.position.z,
        tx: controls.target.x, ty: controls.target.y, tz: controls.target.z,
      });
      if (camField) parts.push(camField);
    } else {
      const existing = formatCamField(parseSceneHash(window.location.hash).cam);
      if (existing) parts.push(existing);
    }
    parts.push(`t=${clockRef.current.toFixed(2)}`);
    if (viewMode === 'surface') parts.push('v=surface');
    const newHash = parts.join('&');

    if (newHash === lastWrittenHash.current) return;
    lastWrittenHash.current = newHash;
    lastWriteAt.current = now;
    history.replaceState(
      null, '',
      `${window.location.pathname}${window.location.search}#${newHash}`,
    );
  });

  return null;
}

function PlaybackControls({
  paused, setPaused, speed, setSpeed,
  viewMode, setViewMode,
  showStellarReference, setShowStellarReference,
  hasStellarReference,
  showDebrisDiskAxis, setShowDebrisDiskAxis,
  alignToDiskAxis, setAlignToDiskAxis,
  hasInclinedDebrisDisk,
  showRuler, setShowRuler,
  showCompanions, setShowCompanions, hasCompanions,
  showStarLabels, setShowStarLabels,
}: {
  paused: boolean; setPaused: (p: boolean) => void;
  speed: number; setSpeed: (s: number) => void;
  viewMode: 'system' | 'surface'; setViewMode: (v: 'system' | 'surface') => void;
  showStellarReference: boolean; setShowStellarReference: (v: boolean) => void;
  /** True when the focal system has at least one debris disk with a
      measured inclination (the toggles below only make sense in that case). */
  showDebrisDiskAxis: boolean; setShowDebrisDiskAxis: (v: boolean) => void;
  alignToDiskAxis: boolean; setAlignToDiskAxis: (v: boolean) => void;
  hasInclinedDebrisDisk: boolean;
  /** True when the focal scene has something for the spin-axis toggle to
      control (measured obliquity or a host-star rotation period). Used to
      hide the display row entirely on systems where the toggle would be a
      no-op, so the controls don't carry dangling buttons. */
  hasStellarReference: boolean;
  /** In-scene ruler toggle. Always available since every system has scale
      worth measuring, so no hasX gate. */
  showRuler: boolean; setShowRuler: (v: boolean) => void;
  /** Companion-direction HUD toggle. Gated on the system actually having
      binary/triple companions so we don't render an inert button. */
  showCompanions: boolean; setShowCompanions: (v: boolean) => void;
  hasCompanions: boolean;
  /** Persistent labels above each wide companion star — designation +
      host name floating in 3D so the user can disambiguate which star
      is which without hovering one by one. */
  showStarLabels: boolean; setShowStarLabels: (v: boolean) => void;
}) {
  const isSurface = viewMode === 'surface';
  const [collapsed, setCollapsed] = useState(false);

  // Collapsed: shrink to a small pill so the scene is unobstructed for small
  // screens or a clean, full-bleed screenshot.
  if (collapsed) {
    return (
      <button
        onClick={() => setCollapsed(false)}
        title="Show view controls"
        aria-label="Show view controls"
        style={{
          position: 'fixed', bottom: 56, right: 16, zIndex: 10,
          background: 'rgba(11, 13, 18, 0.85)', color: 'var(--fg)',
          padding: '0.4rem 0.65rem', borderRadius: 4,
          border: '1px solid var(--border)', backdropFilter: 'blur(4px)',
          fontSize: '0.75rem', fontWeight: 600, cursor: 'pointer',
        }}
      >
        ⚙ controls
      </button>
    );
  }

  return (
    <div
      style={{
        position: 'fixed', bottom: 56, right: 16, zIndex: 10,
        background: 'rgba(11, 13, 18, 0.85)', color: 'var(--fg)',
        padding: '0.7rem 0.9rem', borderRadius: 4, maxWidth: 360,
        border: '1px solid var(--border)', backdropFilter: 'blur(4px)',
        fontSize: '0.78rem',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '0.4rem' }}>
        <button
          onClick={() => setCollapsed(true)}
          title="Hide controls for a clean view / screenshot"
          aria-label="Hide controls"
          style={{
            background: 'transparent', color: 'var(--fg-muted)',
            border: 'none', cursor: 'pointer', fontSize: '0.72rem', padding: 0,
          }}
        >
          ✕ hide
        </button>
      </div>
      {/* View-mode toggle row */}
      <div style={{ display: 'flex', gap: '0.3rem', marginBottom: '0.55rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.55rem' }}>
        <button
          onClick={() => setViewMode('system')}
          style={{ flex: 1, background: !isSurface ? 'var(--fg)' : 'transparent', color: !isSurface ? '#0b0d12' : 'var(--fg-muted)', border: '1px solid var(--border)', padding: '0.2rem 0.5rem', borderRadius: 3, cursor: 'pointer', fontSize: '0.75rem', fontWeight: 600 }}
        >
          system view
        </button>
        <button
          onClick={() => setViewMode('surface')}
          style={{ flex: 1, background: isSurface ? 'var(--fg)' : 'transparent', color: isSurface ? '#0b0d12' : 'var(--fg-muted)', border: '1px solid var(--border)', padding: '0.2rem 0.5rem', borderRadius: 3, cursor: 'pointer', fontSize: '0.75rem', fontWeight: 600 }}
        >
          from surface
        </button>
      </div>

      {/* Playback — meaningful in BOTH modes. System: orbital animation.
          Surface: day/night cycle (sun arcs across the sky). */}
      <div style={{ display: 'flex', gap: '0.4rem', alignItems: 'center', flexWrap: 'wrap' }}>
        <button
          onClick={() => setPaused(!paused)}
          style={{ background: paused ? 'var(--accent)' : 'transparent', color: paused ? '#0b0d12' : 'var(--fg)', border: '1px solid var(--border)', padding: '0.25rem 0.7rem', borderRadius: 3, cursor: 'pointer', fontWeight: 600 }}
        >
          {paused ? '▶ play' : '❚❚ pause'}
        </button>
        <span style={{ color: 'var(--fg-muted)', marginLeft: '0.2rem' }}>speed</span>
        {[0.25, 1, 4, 16].map((s) => (
          <button
            key={s}
            onClick={() => setSpeed(s)}
            style={{ background: speed === s ? 'var(--fg)' : 'transparent', color: speed === s ? '#0b0d12' : 'var(--fg-muted)', border: '1px solid var(--border)', padding: '0.15rem 0.45rem', borderRadius: 3, cursor: 'pointer', fontSize: '0.75rem' }}
          >
            {s}×
          </button>
        ))}
      </div>

      {/* Display row: overlays toggles. Stellar reference frame and debris-
          disk axes are gated on the scene having something for them to
          control; the ruler is always available since every system has scale
          worth measuring. The row itself always renders now (the ruler
          guarantees at least one button is present). */}
      <div style={{ display: 'flex', gap: '0.4rem', alignItems: 'center', marginTop: '0.55rem', flexWrap: 'wrap' }}>
        <span style={{ color: 'var(--fg-muted)' }}>display</span>
        <button
          type="button"
          role="switch"
          aria-checked={showRuler}
          aria-label={`In-scene AU ruler, currently ${showRuler ? 'on' : 'off'}`}
          onClick={() => setShowRuler(!showRuler)}
          title="Toggle a glowing AU scale bar in the orbital plane"
          style={{
            background: showRuler ? 'var(--fg)' : 'transparent',
            color: showRuler ? '#0b0d12' : 'var(--fg-muted)',
            border: '1px solid var(--border)',
            padding: '0.15rem 0.5rem',
            borderRadius: 3,
            cursor: 'pointer',
            fontSize: '0.75rem',
          }}
        >
          ruler {showRuler ? 'on' : 'off'}
        </button>
        {hasCompanions && (
          <button
            type="button"
            role="switch"
            aria-checked={showCompanions}
            aria-label={`Off-screen companion-star indicators, currently ${showCompanions ? 'on' : 'off'}`}
            onClick={() => setShowCompanions(!showCompanions)}
            title="Toggle screen-edge markers pointing toward off-screen companion stars"
            style={{
              background: showCompanions ? 'var(--fg)' : 'transparent',
              color: showCompanions ? '#0b0d12' : 'var(--fg-muted)',
              border: '1px solid var(--border)',
              padding: '0.15rem 0.5rem',
              borderRadius: 3,
              cursor: 'pointer',
              fontSize: '0.75rem',
            }}
          >
            companions {showCompanions ? 'on' : 'off'}
          </button>
        )}
        {hasCompanions && (
          <button
            type="button"
            role="switch"
            aria-checked={showStarLabels}
            aria-label={`Persistent labels above companion stars, currently ${showStarLabels ? 'on' : 'off'}`}
            onClick={() => setShowStarLabels(!showStarLabels)}
            title="Toggle persistent name labels above each companion star in the scene"
            style={{
              background: showStarLabels ? 'var(--fg)' : 'transparent',
              color: showStarLabels ? '#0b0d12' : 'var(--fg-muted)',
              border: '1px solid var(--border)',
              padding: '0.15rem 0.5rem',
              borderRadius: 3,
              cursor: 'pointer',
              fontSize: '0.75rem',
            }}
          >
            star labels {showStarLabels ? 'on' : 'off'}
          </button>
        )}
        {hasStellarReference && (
          <button
            type="button"
            role="switch"
            aria-checked={showStellarReference}
            aria-label={`Stellar spin axis overlay, currently ${showStellarReference ? 'on' : 'off'}`}
            onClick={() => setShowStellarReference(!showStellarReference)}
            title="Toggle the stellar spin axis (and obliquity equator ring, when present)"
            style={{
              background: showStellarReference ? 'var(--fg)' : 'transparent',
              color: showStellarReference ? '#0b0d12' : 'var(--fg-muted)',
              border: '1px solid var(--border)',
              padding: '0.15rem 0.5rem',
              borderRadius: 3,
              cursor: 'pointer',
              fontSize: '0.75rem',
            }}
          >
            spin axis {showStellarReference ? 'on' : 'off'}
          </button>
        )}
        {hasInclinedDebrisDisk && (
          <>
            <button
              type="button"
              role="switch"
              aria-checked={showDebrisDiskAxis}
              aria-label={`Debris-disk axis overlay, currently ${showDebrisDiskAxis ? 'on' : 'off'}`}
              onClick={() => setShowDebrisDiskAxis(!showDebrisDiskAxis)}
              title="Toggle the line perpendicular to the debris-disk plane"
              style={{
                background: showDebrisDiskAxis ? 'var(--fg)' : 'transparent',
                color: showDebrisDiskAxis ? '#0b0d12' : 'var(--fg-muted)',
                border: '1px solid var(--border)',
                padding: '0.15rem 0.5rem',
                borderRadius: 3,
                cursor: 'pointer',
                fontSize: '0.75rem',
              }}
            >
              disk axis {showDebrisDiskAxis ? 'on' : 'off'}
            </button>
            <button
              type="button"
              role="switch"
              aria-checked={alignToDiskAxis}
              aria-label={`Align camera view to debris-disk axis, currently ${alignToDiskAxis ? 'on' : 'off'}`}
              onClick={() => setAlignToDiskAxis(!alignToDiskAxis)}
              title="Reorient the camera so the debris-disk axis points straight up on screen"
              style={{
                background: alignToDiskAxis ? 'var(--fg)' : 'transparent',
                color: alignToDiskAxis ? '#0b0d12' : 'var(--fg-muted)',
                border: '1px solid var(--border)',
                padding: '0.15rem 0.5rem',
                borderRadius: 3,
                cursor: 'pointer',
                fontSize: '0.75rem',
              }}
            >
              align to disk {alignToDiskAxis ? 'on' : 'off'}
            </button>
          </>
        )}
      </div>

      <p style={{ margin: '0.55rem 0 0', fontSize: '0.7rem', color: 'var(--fg-muted)', lineHeight: 1.45 }}>
        {isSurface
          ? "Drag to look around · zoom locked · you're standing on the planet, riding it as it orbits the sun. Hit play to watch the sun move across your sky."
          : 'Drag to orbit · scroll to zoom · pan with right-mouse · ~60 sec per focal-planet orbit at 1×.'}
      </p>
      <p style={{ margin: '0.35rem 0 0', fontSize: '0.68rem', color: 'var(--fg-muted)', lineHeight: 1.4 }}>
        <strong style={{ color: 'var(--fg-muted)' }}>Scale:</strong>{' '}
        {isSurface
          ? 'orbits at true AU, so the sun arcs across the sky at the true rate from your orbital position.'
          : `orbits at true AU; bodies exaggerated ~${BODY_EXAG}× so they're visible.`}
      </p>
      <EnterVRButton />
    </div>
  );
}

// Auto-plays the orbital animation when an XR session starts. The HTML
// playback controls (play/pause/speed) aren't reachable inside VR, so a
// user entering with the default paused=true would see a frozen system.
// Unpausing on session start makes the world come alive immediately.
function VRAutoPlay({ setPaused }: { setPaused: (p: boolean) => void }) {
  const session = useXR((s) => s.session);
  useEffect(() => {
    if (session) setPaused(false);
  }, [session, setPaused]);
  return null;
}

// Sets the WebXR session's render state so our scene doesn't get clipped.
// Defaults are depthNear=0.1m and depthFar=1000m — but our scene is at AU
// scale (1 AU per unit; starfield sphere at 5000) and we wrap visual
// content in <VRSceneScale> which multiplies further. depthFar=1e9 covers
// the worst case; depthNear=0.01 lets the user get close to small planets
// without them being clipped.
function XRDepthFar() {
  const session = useXR((s) => s.session);
  useEffect(() => {
    if (!session) return;
    session.updateRenderState({ depthNear: 0.01, depthFar: 1e9 });
  }, [session]);
  return null;
}

// Compute the VR scene scale factor: maps the system's max-orbit extent to
// ~6 world-meters so the whole system fits comfortably in the headset.
// Clamped [2, 200] to avoid degenerate values for very tight or very wide
// systems. Factor is 1 outside XR (no scale change for the desktop view).
// Shared by VRSceneScale and VRRig so they always use the same mapping.
function vrScaleFactor(maxOrbit: number): number {
  return Math.min(200, Math.max(2, 6 / maxOrbit));
}

// Scales the entire visual scene up while in VR so AU-scale units don't
// render as sub-millimeter specks in the headset. WebXR treats scene units
// as METERS, but our planets are sub-meter (TRAPPIST-1 b at 0.0008 AU is
// literally 0.8mm wide). We map the focal system's extent to ~6m — a
// comfortable "room-scale" view that fits the whole system in front of
// the user. Outside VR, factor=1 (no scale change, desktop view unaffected).
function VRSceneScale({ children, maxOrbit }: { children: React.ReactNode; maxOrbit: number }) {
  const inXR = useXR((s) => s.session != null);
  const factor = inXR ? vrScaleFactor(maxOrbit) : 1;
  return <group scale={factor}>{children}</group>;
}

// VR locomotion: drops an XROrigin (the user's feet reference frame) at
// a comfortable viewing position in world meters, then wires the controller
// thumbsticks to translate it. The XROrigin lives OUTSIDE VRSceneScale
// (its position is in world meters, not scene-AU), so initialPos and speed
// are in meters per second.
//
// Surface mode: when the surfaceProps bundle is provided, the rig tracks the
// focal planet's animated world position each frame instead of allowing free
// locomotion. XR owns the camera transform, so we must move the XROrigin
// (the user's "feet" reference frame) to keep the user standing on the
// planet as it orbits. focalPosRef is in scene-AU; vrScaleFactor converts
// to world meters using the same mapping VRSceneScale applies.
// All three surface props must be supplied together — they form a matched set.
type VRRigProps = {
  initialPos: [number, number, number];
  speed: number;
  surfaceProps?: {
    focalPosRef: React.MutableRefObject<THREE.Vector3>;
    surfaceOffset: number;  // in scene-AU
    maxOrbit: number;       // system's max orbit in AU (drives VR scale factor)
  };
};

function VRRig({
  initialPos,
  speed,
  surfaceProps,
}: VRRigProps) {
  const originRef = useRef<THREE.Group>(null);
  const inXR = useXR((s) => s.session != null);
  const syncToSurface = useCallback(() => {
    if (!surfaceProps) return;
    const origin = originRef.current;
    if (!origin) return;
    const { focalPosRef, surfaceOffset, maxOrbit } = surfaceProps;
    const scale = vrScaleFactor(maxOrbit);
    const yOffset = surfaceOffset * scale;
    origin.position.set(
      focalPosRef.current.x * scale,
      focalPosRef.current.y * scale + yOffset,
      focalPosRef.current.z * scale,
    );
  }, [surfaceProps]);

  // Callback form (instead of ref form) so we can apply the full XYZ velocity
  // vector. The default hook implementation only adds velocity.x and velocity.z
  // to target.position, dropping the Y component — which means if the user is
  // above the orbital plane and pushes the thumbstick forward while looking
  // down at the system, they slide horizontally instead of diving in.
  // In surface mode (surfaceProps provided), locomotion is disabled: the user
  // is locked to the planet's position and should not drift away from it.
  useXRControllerLocomotion(
    (velocity, rotationVelocityY, deltaTime) => {
      if (surfaceProps) return; // surface mode: planet tracking overrides locomotion
      const origin = originRef.current;
      if (!origin) return;
      origin.position.x += velocity.x * deltaTime;
      origin.position.y += velocity.y * deltaTime;
      origin.position.z += velocity.z * deltaTime;
      if (rotationVelocityY) origin.rotation.y += rotationVelocityY;
    },
    { speed },
  );

  // Snap the user onto the focal planet as soon as an XR session starts, so
  // the first immersive frame doesn't briefly render from the default spawn.
  useLayoutEffect(() => {
    if (!inXR) return;
    syncToSurface();
  }, [inXR, syncToSurface]);

  // Surface mode + VR: drive the XROrigin to the focal planet's current
  // world-meter position each frame. focalPosRef is written in scene-AU by
  // SceneContents; vrScaleFactor converts to world meters using the same
  // mapping VRSceneScale applies.
  // This must run after SceneContents' useFrame (which writes focalPosRef),
  // which is guaranteed because VRRig is mounted after SceneContents in JSX.
  useFrame(() => {
    if (!surfaceProps || !inXR) return;
    syncToSurface();
  });

  return <XROrigin ref={originRef} position={initialPos} />;
}

// Bloom post-process pipeline, skipped while in VR. The EffectComposer
// renders to a single 2D framebuffer, which black-screens stereo XR (the
// composer doesn't multiplex over the left/right eye buffers). useXR is
// only valid inside <XR>, which is why this component lives inside it.
function PostProcessing() {
  const inXR = useXR((s) => s.session != null);
  if (inXR) return null;
  return (
    <EffectComposer>
      <Bloom
        /* mipmapBlur produces the wide, smooth Gaussian-pyramid halo
           that reads as a real stellar corona. levels={4} keeps the
           pyramid shallow to prevent the frame-spanning dome bug.
           Threshold 0.60 is high enough that only the bright center of
           the photosphere disc feeds the bloom kernel — the limb-darkened
           edges fall below threshold, so the bloom no longer bleeds back
           across the disc and washes out surface detail (starspots,
           granulation). The StellarCorona billboard handles the soft
           visible halo on its own; this layer is just the extra glow
           atop the very brightest pixels. */
        intensity={1.0}
        luminanceThreshold={1.0}
        luminanceSmoothing={0.25}
        mipmapBlur
        radius={0.7}
        levels={4}
      />
    </EffectComposer>
  );
}

// "Enter VR" button. Calls into the module-level xrStore. WebXR requires
// HTTPS for non-localhost origins — on a Quest 3, this means the page must
// be served over HTTPS (Vercel deploy works; local dev needs an HTTPS tunnel
// like ngrok or vite-plugin-mkcert).
function EnterVRButton() {
  const [supported, setSupported] = useState<boolean | null>(null);
  useEffect(() => {
    const xr = (navigator as Navigator & { xr?: XRSystem }).xr;
    if (!xr) { setSupported(false); return; }
    xr.isSessionSupported('immersive-vr')
      .then((ok) => setSupported(ok))
      .catch(() => setSupported(false));
  }, []);
  if (supported === false) return null;   // hide entirely on non-XR browsers
  return (
    <button
      onClick={() => xrStore.enterVR()}
      disabled={supported === null}
      title="Enter immersive VR (Quest 3, Vision Pro, etc.). Requires a WebXR-capable headset/browser."
      style={{
        marginTop: '0.6rem', width: '100%',
        background: 'var(--accent)', color: '#0b0d12',
        border: '1px solid var(--border)',
        padding: '0.4rem 0.6rem', borderRadius: 3,
        cursor: supported === null ? 'wait' : 'pointer',
        fontWeight: 600, fontSize: '0.78rem',
        letterSpacing: '0.04em',
      }}
    >
      ⛶ Enter VR
    </button>
  );
}

// ── surface view ─────────────────────────────────────────────────────────
// "You're standing on the focal planet, riding it as it orbits."
//
// Architecture: the same SceneContents that powers system view ALSO powers
// surface view. The only differences are:
//   1) The camera follows the focal planet's animated position each frame
//      (CameraFollowFocal).
//   2) The focal planet body is hidden (you're on it).
//   3) FirstPersonLook starts oriented toward the sun and lets the user
//      drag-rotate from there.
//
// Net effect: hit play and you watch your planet revolve around its star,
// with the sun's apparent direction in your sky changing as you go around.
// Sibling planets continue their orbits — visible at their true angular
// positions in your sky from this vantage.

// Update the camera position to track the focal planet each frame. The
// caller passes a Vector3 ref that SceneContents writes to; we read from
// it and copy into the camera. A small Y offset puts the user "above" the
// planet center (functionally, on its surface) rather than embedded in it.
// In VR, the XR session owns camera.matrix so writes here are no-ops — planet
// tracking is handled instead by VRRig's useFrame (which moves the XROrigin).
function CameraFollowFocal({
  focalPosRef, surfaceOffset,
}: {
  focalPosRef: React.MutableRefObject<THREE.Vector3>;
  surfaceOffset: number;
}) {
  const { camera } = useThree();
  const inXR = useXR((s) => s.session != null);
  useFrame(() => {
    if (inXR) return; // XR session owns the camera; VRRig drives XROrigin instead
    camera.position.set(
      focalPosRef.current.x,
      focalPosRef.current.y + surfaceOffset,
      focalPosRef.current.z,
    );
  });
  return null;
}

// Default Three.js camera forward direction. Used by FirstPersonLook to
// compute "look at this point" base orientation as a quaternion delta from
// the default forward.
const FORWARD = new THREE.Vector3(0, 0, -1);

// First-person camera control: drag the canvas to rotate the camera in place
// (yaw + pitch). Camera position stays controlled by parent (or static).
//
// When `trackTarget` is provided, the camera's BASE orientation each frame
// is "look at this world-space point" — and the user's drag yaw/pitch are
// interpreted as offsets RELATIVE to that. Effect: the user always faces
// the target by default (a tidally-locked feeling for surface view, where
// the planet rotates to keep the same face toward its sun), and they can
// drag to look around the rest of the sky from there.
//
// VR note: in VR the headset owns camera.quaternion, so this component's
// writes are no-ops once a session is active. That's intentional: in VR the
// user physically rotates their head to look at the sun, and the sun naturally
// drifts through their sky as the planet orbits — a "real planetary surface"
// experience. Desktop surface mode instead auto-tracks the sun each frame
// (tidally-locked default feel); these are deliberate diverging UX choices.
function FirstPersonLook({
  initialYaw = 0, initialPitch = 0, trackTarget,
}: {
  initialYaw?: number; initialPitch?: number;
  trackTarget?: THREE.Vector3;
}) {
  const { camera, gl } = useThree();
  const inXR = useXR((s) => s.session != null);
  const yaw = useRef(trackTarget ? 0 : initialYaw);
  const pitch = useRef(trackTarget ? 0 : initialPitch);
  const dragging = useRef(false);
  const last = useRef({ x: 0, y: 0 });

  // Per-frame: if tracking, recompute the orientation each frame so the
  // base direction stays locked on the target as the camera moves through
  // the world (e.g. while the focal planet orbits). When not tracking,
  // orientation only changes on drag.
  // In VR, the XR session owns camera.quaternion — skip the write.
  useFrame(() => {
    if (!trackTarget || inXR) return;
    const baseDir = new THREE.Vector3().subVectors(trackTarget, camera.position).normalize();
    const baseQ = new THREE.Quaternion().setFromUnitVectors(FORWARD, baseDir);
    const userQ = new THREE.Quaternion().setFromEuler(
      new THREE.Euler(pitch.current, yaw.current, 0, 'YXZ'),
    );
    camera.quaternion.copy(baseQ).multiply(userQ);
  });

  useEffect(() => {
    const canvas = gl.domElement;
    const apply = () => {
      // Static (non-tracking) case: directly set orientation from yaw/pitch.
      // In tracking mode the useFrame above handles this every frame instead.
      if (trackTarget) return;
      const euler = new THREE.Euler(pitch.current, yaw.current, 0, 'YXZ');
      camera.quaternion.setFromEuler(euler);
    };
    apply();   // initial orientation (only effective when not tracking)

    const onDown = (e: PointerEvent) => {
      dragging.current = true;
      last.current = { x: e.clientX, y: e.clientY };
      try { canvas.setPointerCapture(e.pointerId); } catch { /* ok */ }
    };
    const onMove = (e: PointerEvent) => {
      if (!dragging.current) return;
      const dx = e.clientX - last.current.x;
      const dy = e.clientY - last.current.y;
      last.current = { x: e.clientX, y: e.clientY };
      yaw.current   -= dx * 0.004;
      pitch.current -= dy * 0.004;
      // Clamp pitch to just under straight up/down so we don't gimbal-flip
      pitch.current = Math.max(-Math.PI / 2 + 0.01, Math.min(Math.PI / 2 - 0.01, pitch.current));
      apply();
    };
    const onUp = (e: PointerEvent) => {
      dragging.current = false;
      try { canvas.releasePointerCapture(e.pointerId); } catch { /* ok */ }
    };
    canvas.addEventListener('pointerdown', onDown);
    canvas.addEventListener('pointermove', onMove);
    canvas.addEventListener('pointerup', onUp);
    canvas.addEventListener('pointercancel', onUp);
    return () => {
      canvas.removeEventListener('pointerdown', onDown);
      canvas.removeEventListener('pointermove', onMove);
      canvas.removeEventListener('pointerup', onUp);
      canvas.removeEventListener('pointercancel', onUp);
    };
  }, [camera, gl]);

  return null;
}

function SceneContents({
  scene, paused, speed, clockRef,
  hideFocal = false,
  focalPosOut,
  showStellarReference = true,
  showDebrisDiskAxis = true,
  alignToDiskAxis = false,
  showRuler = false,
  onRulerDragChange,
  showCompanions = true,
  companionDirectionsRef,
  showStarLabels = false,
}: {
  scene: SceneResponse;
  paused: boolean;
  speed: number;
  /** Orbital animation clock (seconds × speed when not paused). Owned by
      ScenePage so it can be initialized from the URL hash and survive
      Canvas remounts on viewMode toggle. */
  clockRef: React.MutableRefObject<number>;
  /** When true, the focal planet body is not rendered (used in surface mode
      where the camera is "standing on" the planet — no need to see it). */
  hideFocal?: boolean;
  /** When provided, the focal planet's animated world position is written
      into this ref every frame so a parent component (the surface-view
      camera follower) can read it. */
  focalPosOut?: React.MutableRefObject<THREE.Vector3>;
  /** Toggles the stellar spin axis + (when obliquity is present) equator
      ring overlay. Driven from PlaybackControls. */
  showStellarReference?: boolean;
  /** Toggles the debris-disk axis (normal vector perpendicular to disk plane).
      Independent from the stellar spin axis. */
  showDebrisDiskAxis?: boolean;
  /** When true, the camera's up vector is set to the (first inclined) debris-
      disk normal so the disk appears horizontal and its axis vertical on
      screen — a "physics-natural" viewing frame. */
  alignToDiskAxis?: boolean;
  /** Toggles the in-scene AU ruler. Rendered in the orbital reference plane
      regardless of focal mode. Off by default. */
  showRuler?: boolean;
  /** Notified when the user starts/ends dragging a ruler endpoint, so the
      parent can disable OrbitControls during the drag. */
  onRulerDragChange?: (dragging: boolean) => void;
  /** Toggles the off-screen companion-star HUD markers. Default true; the
      caller passes the boolean and the marker components honor it. */
  showCompanions?: boolean;
  /** Shared Map that the in-Canvas tracker writes companion direction
      angles + in-view flags into, and the out-of-Canvas HUD panel reads
      from. Lifted to ScenePage so both sides share one instance. */
  companionDirectionsRef?: CompanionDirectionRef;
  /** Persistent labels above each wide companion star — toggled on when
      the user wants disambiguation between multiple visible companions
      without hovering them one at a time. */
  showStarLabels?: boolean;
}) {
  const navigate = useNavigate();
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';
  const [hovered, setHovered] = useState<string | null>(null);

  const { sun_color_hex } = scene.scene_hints;
  const { planet, siblings } = scene;

  function jumpTo(plName: string) {
    // If we're inside an XR session, end it gracefully before navigating.
    // Otherwise the route change unmounts the Canvas mid-frame and the
    // active WebXR session crashes the headset. The user is dropped back
    // to flat-screen view; they can re-enter VR on the new planet's page.
    const session = xrStore.getState().session;
    const go = () => navigate(
      `/planets/${encodeURIComponent(plName)}/scene${themeQuery}`,
      { replace: true },
    );
    if (session) {
      session.end().then(go).catch(go);
    } else {
      go();
    }
  }

  const focalOrbsmax = planet.pl_orbsmax ?? 1;

  // Filter then fill, in order:
  //   1. drop self-reference rows (16 Cyg B's bogus "B" entry)
  //   2. drop unpointable rows (inner-binary "Ab" partners with NULL
  //      separation_arcsec — they're already part of the BinaryPhotospheres
  //      at origin and listing them as separate companions creates HUD
  //      arrows that point at nothing)
  //   3. spread remaining NULL-PA companions evenly so tight unresolved
  //      binaries (Kepler-444 BC, etc.) render at distinct 3D positions
  const filledCompanions = useMemo(
    () => fillCompanionPositionAngles(
      dropUnpointableCompanions(
        dropSelfReferenceCompanions(planet.hostname, scene.binary_companions),
      ),
    ),
    [scene.binary_companions, planet.hostname],
  );
  const innermost = innermostPeriapsis(scene);
  const sunRadius = sunDisplayRadius(planet.st_rad, innermost, focalOrbsmax);
  const focalPlanetRadius = planetDisplayRadius(planet.pl_rade, focalOrbsmax, planet.st_rad, sunRadius);

  // Mutual-inclination map keyed by planet name. ups And d (30° vs c),
  // 55 Cnc e (17° vs b), and Kepler-419 c (9° vs b) are the visible
  // standouts; most other measured rows are sub-degree fine structure.
  // Planets without an entry default to the system's reference plane
  // (i=0). Built once per scene response; cheap.
  const tiltMap = useMemo(
    () => buildOrbitTiltMap(scene.orbital_geometry),
    [scene.orbital_geometry],
  );
  const focalTilt = tiltMap.get(planet.pl_name) ?? { inc: 0, omega: 0 };

  // Spin-orbit obliquity tilts the focal orbit relative to the star's equator
  // (the XZ reference plane; spin axis = +Y). It takes precedence over the
  // mutual-inclination tilt for the focal planet — the curated obliquity
  // systems are single hot Jupiters whose focalTilt is {0,0} anyway, so this
  // is effectively "use the obliquity when we have it." Rendered against a
  // StellarSpinReference (equatorial ring + spin axis) so the tilt is legible.
  const obliquity = useMemo(
    () => focalObliquity(scene.derived_measurements, planet.pl_name),
    [scene.derived_measurements, planet.pl_name],
  );
  const focalRenderTilt = obliquity
    ? { inc: (obliquity.deg * Math.PI) / 180, omega: OBLIQUITY_NODE_OMEGA }
    : focalTilt;

  // Host-star rotation period (days), if known: drives a visible star rotation
  // about its spin axis (+Y, the axis the obliquity tilt references).
  const stellarRotationDays = useMemo(
    () => focalStellarRotationDays(scene.derived_measurements, planet.pl_name),
    [scene.derived_measurements, planet.pl_name],
  );

  // Full starspot parameters (position + size) derived from the host's
  // rotation period and identifier. Sibling planets share a star and
  // therefore share a spot — hashing on hostname, not pl_name, keeps the
  // spot fixed across navigation between siblings.
  const stellarSpot = useMemo(() => {
    if (stellarRotationDays == null || stellarRotationDays <= 0) return null;
    return starSpotProps(stellarRotationDays, planet.hostname);
  }, [stellarRotationDays, planet.hostname]);

  // Centrifugal oblateness of the host star (f = (R_eq − R_pol)/R_eq).
  // Only renders when f > 0.5% — Sun-class rotators contribute too little
  // to see. Squashes the Photosphere along its spin axis (+Y).
  const stellarOblateness = useMemo(
    () => focalStellarOblateness(
      scene.derived_measurements, planet.pl_name, planet.st_rad, planet.st_mass,
    ),
    [scene.derived_measurements, planet.pl_name, planet.st_rad, planet.st_mass],
  );

  // Focal planet's axial spin, derived from rotation_velocity (km/s) + radius.
  // Rate is stylized like the orbit pacing (a 10-hour rotator turns once per
  // ~12 s); faster/slower relative rates are preserved. Spin direction is +Y
  // by convention — the true planetary spin-axis orientation is essentially
  // unmeasured for exoplanets. Currently lights up bet Pic b (Snellen 2014,
  // ~8 h) and AB Pic b (Palma-Bifani 2023, vsini-derived ~1.9 h), the only
  // two planets with rotation_velocity harvested into derived_measurements.
  const planetSpinOmega = useMemo(() => {
    const row = bestDerived(scene.derived_measurements, planet.pl_name, 'rotation_velocity');
    if (!row?.value || planet.pl_rade == null) return null;
    return stylizedSpinOmega(row.value, planet.pl_rade);
  }, [scene.derived_measurements, planet.pl_name, planet.pl_rade]);

  // Day/night thermal emission colors for the focal planet, if the dayside
  // is hot enough that thermal radiation dominates the visible appearance.
  // When present, the body shader switches from sun-direction reflective
  // lighting to a smooth blend between thermal colors so the measured
  // day/night temperature contrast actually reads visually (the hottest
  // Jupiters glow white-hot on the lit side; their night sides can be
  // ~half that or dimmer).
  const phaseCurve = useMemo(
    () => focalPhaseCurve(scene.derived_measurements, planet.pl_name),
    [scene.derived_measurements, planet.pl_name],
  );

  // Circumplanetary disk for the focal planet, if the catalog/curated data
  // says one exists. Currently only PDS 70 b and c carry this (Wagner 2018
  // accretion rate; Benisty 2021 resolved dust mass). When present, a flat
  // dust ring is drawn around the planet body at a few planet-radii scale —
  // the canonical "forming planet feeding from its disc" look.
  const circumplanetaryDisk = useMemo(
    () => focalCircumplanetaryDisk(scene.derived_measurements, planet.pl_name),
    [scene.derived_measurements, planet.pl_name],
  );

  // Mass-loss / escaping-atmosphere tail for the focal planet, if the catalog
  // / curated data carries a mass_loss_rate row. 8 planets currently qualify
  // (migration 088 + Kepler-1520 b from 036). The tail is rendered in its own
  // world-frame group (sibling of focalGroup) because focalGroup only
  // translates, and the tail needs an extra rotation each frame to point
  // along the orbital tangent (trailing or leading).
  const massLoss = useMemo(
    () => focalMassLoss(scene.derived_measurements, planet.pl_name),
    [scene.derived_measurements, planet.pl_name],
  );

  // Curated reflective albedo for the focal planet. Modulates planet-body
  // reflected-light brightness; HD 189733 b also gets the blue reflection
  // tint. 11 planets currently qualify (migration 089 + WASP-80 b /
  // GJ 1214 b from prior migrations). Phase-curve planets (KELT-9 b-class)
  // are unaffected since the shader's emission path doesn't read albedo.
  const albedo = useMemo(
    () => focalAlbedo(scene.derived_measurements, planet.pl_name),
    [scene.derived_measurements, planet.pl_name],
  );

  // System-level debris disks for the focal planet's host star (5 systems
  // qualify post-migration 090: bet Pic, HR 8799, HD 95086, eps Eri, 51 Eri).
  // Returns one entry per belt — 51 Eri has both a warm and cold belt, the
  // others have one. Rendered as wide flat rings around the host at the
  // AU scale of the orbit.
  const debrisDisks = useMemo(
    () => focalDebrisDisks(scene.derived_measurements, planet.pl_name),
    [scene.derived_measurements, planet.pl_name],
  );

  // Stellar halo intensity, driven by data: the star's apparent flux at the
  // planet's orbit (scene_hints.insolation_relative_earth = L_star / orbsmax²
  // in Earth units, computed from measured st_lum and pl_orbsmax). This is
  // the same physics that gives a brighter point source a wider visible PSF
  // in the eye / a camera. Log-scaled and clamped to a sensible visual range
  // so cold outer planets get a tight subtle glow, Earth-like get a moderate
  // halo, and hot inner planets get a wide bright one. Falls back to 0.4
  // (Sun-at-Earth-equivalent) when the data is missing.
  const haloIntensity = useMemo(() => {
    const insol = scene.scene_hints.insolation_relative_earth;
    if (insol == null || insol <= 0) return 0.4;
    return Math.min(0.75, Math.max(0.25, 0.4 + 0.12 * Math.log10(insol)));
  }, [scene.scene_hints.insolation_relative_earth]);

  // Animation clock — accumulates real seconds × speed when not paused.
  // Each planet derives its current orbital angle from this single shared time.
  // Lifted to ScenePage and passed in via clockRef so it can be initialized
  // from the URL hash and survive Canvas remounts on viewMode toggle.
  const clock = clockRef;
  const focalGroup = useRef<THREE.Group>(null);
  const tailGroup = useRef<THREE.Group>(null);
  const siblingRefs = useRef<Map<string, THREE.Group>>(new Map());

  // Smart-default pacing: focal planet completes its orbit in 60 sec at 1×.
  // Siblings derive from Kepler's 3rd law (T² ∝ a³) so inner planets visibly
  // outpace outer ones — same physics as the real system, just sped up.
  const FOCAL_SECS_PER_ORBIT = 60;
  const focalPeriod = planet.pl_orbper ?? Math.pow(focalOrbsmax, 1.5) * 365.25;

  // Mean anomaly (M) = uniformly-advancing angle proxy for time. The real
  // ellipse position is computed from M by solving Kepler's equation for the
  // eccentric anomaly E (M = E − e·sin E), then converting to (x, z). This
  // makes the planet trace its actual orbital path AND respects Kepler's 2nd
  // law (faster near periapsis, slower near apoapsis) — visible especially
  // for HD 80606b (e=0.93) and other high-eccentricity worlds.
  function meanAnomaly(orbper: number | null, hashSeed: string): number {
    const periodDays = orbper ?? Math.pow(focalOrbsmax, 1.5) * 365.25;
    const ratio = focalPeriod / periodDays;
    let h = 2166136261;
    for (let i = 0; i < hashSeed.length; i++) h = Math.imul(h ^ hashSeed.charCodeAt(i), 16777619);
    const phase0 = ((h >>> 0) % 360) * Math.PI / 180;
    return phase0 + (clock.current / FOCAL_SECS_PER_ORBIT) * 2 * Math.PI * ratio;
  }

  useFrame((_, delta) => {
    if (!paused) clock.current += delta * speed;

    const M = (clock.current / FOCAL_SECS_PER_ORBIT) * 2 * Math.PI;
    const [fx0_raw, , fz0_raw] = keplerPosition(focalOrbsmax, planet.pl_orbeccen ?? 0, M);
    // In-plane rotation by the measured argument of periastron, so periapsis
    // points in the catalogued direction instead of arbitrarily on +X.
    const [fx0, fz0] = rotateInPlane(fx0_raw, fz0_raw, argPeriRad(planet.pl_orblper));
    const [fx, fy, fz] = applyOrbitTilt(fx0, fz0, focalRenderTilt.inc, focalRenderTilt.omega);
    if (focalGroup.current) focalGroup.current.position.set(fx, fy, fz);
    // Expose focal world position for surface-mode camera tracking
    if (focalPosOut) focalPosOut.current.set(fx, fy, fz);
    // Escaping-atmosphere tail. Parent group is positioned at the focal
    // planet; the ribbon component samples the orbit itself each frame to
    // build a spine that curves along the orbital path (leading or trailing).
    if (tailGroup.current && massLoss) {
      tailGroup.current.position.set(fx, fy, fz);
    }
    siblingRefs.current.forEach((group, plName) => {
      const s = siblings.find((x) => x.pl_name === plName);
      if (!s || s.pl_orbsmax == null) return;
      const M = meanAnomaly(s.pl_orbper, s.pl_name);
      const [x0_raw, , z0_raw] = keplerPosition(s.pl_orbsmax, s.pl_orbeccen ?? 0, M);
      const [x0, z0] = rotateInPlane(x0_raw, z0_raw, argPeriRad(s.pl_orblper));
      const tilt = tiltMap.get(plName) ?? { inc: 0, omega: 0 };
      const [x, y, z] = applyOrbitTilt(x0, z0, tilt.inc, tilt.omega);
      group.position.set(x, y, z);
    });
  });

  return (
    <>
      {/* Host star: photosphere sphere + geometric corona billboard.
          The corona is a StellarCorona camera-facing plane with a custom
          radial-gradient shader (AdditiveBlending, depthWrite=false) that
          works in both desktop and stereo XR — unlike the post-process Bloom
          pass which is skipped in XR because EffectComposer renders to a
          single 2D framebuffer and black-screens stereo. Desktop gets Bloom
          layered on top as well; the additive corona doesn't fight bloom. */}
      {/* Photosphere(s). For circumbinary planets (cb_flag=1) the planet
          orbits a tight binary pair, so we render TWO suns rotating around
          their common barycenter at the origin. Each Photosphere includes
          its own StellarCorona so both stars in a binary get a halo. */}
      {planet.cb_flag === 1
        ? <BinaryPhotospheres
            radius={sunRadius}
            color={sun_color_hex}
            teff={planet.st_teff}
            paused={paused}
            speed={speed}
            showLabels={showStarLabels}
            hostname={planet.hostname}
          />
        : <Photosphere radius={sunRadius} color={sun_color_hex} teff={planet.st_teff} rotationPeriodDays={stellarRotationDays} spot={stellarSpot} haloIntensity={haloIntensity} oblateness={stellarOblateness ?? 0} />
      }
      {/* Host-star label (single Photosphere case). Sits well above the
          star body so it doesn't cover the disc. Suppressed in the
          binary case since each inner star gets its own label inside
          BinaryPhotospheres. */}
      {showStarLabels && planet.cb_flag !== 1 && (
        <StarNameLabel
          name={planet.hostname}
          accentColor={sun_color_hex}
          yOffsetAU={sunRadius * 3.5}
        />
      )}
      {/* Sun light: decay=1.7 (slightly less aggressive than physical 1/r²).
          Pure inverse-square crushes outer planets visually faster than the
          eye expects in a stylized 3D scene; 1.7 keeps the directional
          lit/dark sense while extending visibility outward.

          Intensity scales with stellar temperature via (teff/Tsun)^2.5 —
          a softened Stefan-Boltzmann proxy. Full L∝T⁴ would make TRAPPIST-1
          planets effectively invisible (real luminosity ratio is ~1/2000);
          the 2.5 exponent gives M-dwarf planets a believably dim lit-side
          while keeping them readable, and hot stars like KELT-9 light their
          planets ~4× brighter. Radius isn't folded in here — the visible
          disc size already encodes that. */}
      <pointLight
        position={[0, 0, 0]}
        intensity={focalOrbsmax * focalOrbsmax * 2.2 * Math.pow((planet.st_teff ?? 5778) / 5778, 2.5)}
        color={sun_color_hex}
        distance={0}
        decay={1.7}
      />
      {/* Hemisphere fill — provides ambient brightness so even the dark
          side of planets and far-out outer worlds remain readable in dark
          space. Without this they sink into the void. Scaled (sqrt of the
          luminosity factor) so cool-star planets aren't washed out by fill
          that's now brighter than the sun itself. */}
      <hemisphereLight
        intensity={0.22 * Math.sqrt(Math.max(0.05, (planet.st_teff ?? 5778) / 5778))}
        color="#475066"
        groundColor="#1f1f2a"
      />

      {/* Orbit rings — focal in accent color, siblings dimmer. Tilt is
          applied per-vertex inside OrbitRing based on the planet's
          measured mutual inclination (from tiltMap). Visible standouts:
          ups And d (30° from c), 55 Cnc e (17° from b), Kepler-419 c
          (9° from b). Planets without measured geometry stay coplanar. */}
      <OrbitRing
        orbsmax={focalOrbsmax}
        eccen={planet.pl_orbeccen ?? 0}
        color="#7ad6ff"
        opacity={0.55}
        inc={focalRenderTilt.inc}
        omega={focalRenderTilt.omega}
        argPeri={argPeriRad(planet.pl_orblper)}
      />

      {/* In-scene AU ruler. Two-endpoint interactive measurement tool
          living in the orbital reference plane (XZ). User drags either
          handle to read distances between arbitrary points. Endpoints
          default to "locked" — A pinned to the host star at the origin,
          B following the focal planet's animated position each frame —
          so toggling the ruler on immediately shows the live star-to-
          planet distance. Dragging either handle unlocks it. */}
      {showRuler && (
        <SystemRuler
          maxOrbit={Math.max(
            focalOrbsmax,
            ...siblings.map((s) => s.pl_orbsmax ?? 0),
          )}
          onDragChange={onRulerDragChange}
          focalPosRef={focalPosOut}
        />
      )}
      {/* Stellar equator + spin axis — only when the focal planet carries a
          measured spin-orbit obliquity, so ordinary scenes are unchanged.
          The faint equatorial ring is where the orbit would lie at zero
          obliquity; the angle between it and the tilted orbit above IS the
          obliquity. */}
      {/* Reference frame:
           - equator ring only when an obliquity is measured (it is the
             reference plane the orbit tilts against);
           - spin axis whenever the scene has anything pinned to it
             (obliquity OR a stellar rotation period we are animating);
           - both togglable from PlaybackControls. */}
      {(obliquity || stellarRotationDays != null) && showStellarReference && (
        <StellarSpinReference
          orbsmax={focalOrbsmax}
          showAxis
          showEquator={!!obliquity}
        />
      )}

      {/* System-level debris disks. Centered on origin (host star), in AU
          scale, rendered as wide flat rings in the orbital reference plane
          (XZ) with inclination applied per belt. 5 systems qualify today
          (bet Pic, HR 8799, HD 95086, eps Eri, 51 Eri). Stacking order:
          rendered before sibling orbit rings + planet bodies so opaque
          planets occlude the disc as they pass through it (depthTest=true
          inside SystemDebrisDiskRing). */}
      {debrisDisks.map((belt) => (
        <SystemDebrisDiskRing
          key={`debris-${belt.bibcode ?? belt.innerAu}`}
          belt={belt}
        />
      ))}

      {/* Disk normal axis — one line per belt with a measured inclination,
          controlled by its OWN toggle (showDebrisDiskAxis) separately from
          the stellar spin axis. Helps visualize the disk-plane orientation
          for inclined disks (bet Pic ~89° = nearly along line of sight,
          HR 8799 = 40°, HD 95086 = 30°). eps Eri and 51 Eri belts have no
          measured inclination so they're skipped. */}
      {showDebrisDiskAxis && debrisDisks.map((belt) => (
        belt.inclinationDeg != null && (
          <DebrisDiskAxis
            key={`disk-axis-${belt.bibcode ?? belt.innerAu}`}
            length={(belt.outerAu ?? belt.innerAu * 1.1) * 1.2}
            inclinationDeg={belt.inclinationDeg}
          />
        )
      ))}

      {/* Align-camera-to-disk: sets the camera's up vector to the (first
          inclined) debris-disk's normal direction, so the disk appears
          horizontal and its axis vertical on screen. Toggleable from
          PlaybackControls; off by default. The effect runs whenever the
          toggle flips, the focal scene changes, or the disk set changes. */}
      <CameraAxisAlignment
        align={alignToDiskAxis}
        debrisDisks={debrisDisks}
      />
      {siblings
        .filter((s) => s.pl_name !== planet.pl_name && s.pl_orbsmax != null)
        .map((s) => {
          const t = tiltMap.get(s.pl_name) ?? { inc: 0, omega: 0 };
          return (
            <OrbitRing
              key={`ring-${s.pl_name}`}
              orbsmax={s.pl_orbsmax!}
              eccen={s.pl_orbeccen ?? 0}
              color="#888"
              opacity={0.45}
              inc={t.inc}
              omega={t.omega}
              argPeri={argPeriRad(s.pl_orblper)}
            />
          );
        })}

      {/* Focal planet — animated; group wraps so useFrame can move it.
          Hidden in surface mode (we're standing on it). The focal gets the
          atmospheric tint from curated molecule data; siblings don't (we
          don't fetch per-sibling atmospheric data in the scene endpoint). */}
      <group ref={focalGroup} position={[focalOrbsmax, 0, 0]}>
        {!hideFocal && (
          <>
            <PlanetBody
              position={[0, 0, 0]}
              radius={focalPlanetRadius}
              pl_eqt={planet.pl_eqt}
              pl_dens={planet.pl_dens}
              pl_rade={planet.pl_rade}
              emphasized
              name={planet.pl_name}
              onHover={setHovered}
              atmosphereTint={atmosphereTintFromMolecules(scene.atmospheric_detections)}
              rotationOmegaRad={planetSpinOmega}
              phaseCurve={phaseCurve}
              albedo={albedo?.value ?? null}
              reflectionTint={albedo?.reflectionTint ?? null}
              effectiveTempK={focalEffectiveTeff(scene.derived_measurements, planet.pl_name)}
            />
            {hovered === planet.pl_name && <PlanetLabel name={planet.pl_name} subtitle="(focal)" />}
          </>
        )}
        {/* Circumplanetary disk — sibling of PlanetBody (not nested inside
            it) so it stays visible in surface mode, where PlanetBody is
            hidden because the camera is standing on the planet. From the
            surface vantage you should still see the disc stretching across
            the sky like a flat band. Sits flat in the orbital plane (XZ)
            around the planet's position. */}
        {circumplanetaryDisk && (
          <CircumplanetaryDiskRing planetRadius={focalPlanetRadius} />
        )}
      </group>

      {/* Escaping-atmosphere tail — ribbon that follows the orbit. The
          parent group is positioned at the focal planet world coords; the
          ribbon component samples the same Kepler pipeline (keplerPosition
          → rotateInPlane → applyOrbitTilt) backward in M (or forward, for
          HAT-P-67 b's leading helium tail) and rebuilds its spine each
          frame, so the tail literally traces the curved orbit instead of
          shooting off as a straight tangent. */}
      {massLoss && (
        <group ref={tailGroup}>
          <EscapingAtmosphereTail
            planetRadius={focalPlanetRadius}
            mechanism={massLoss.mechanism}
            logMassLoss={Math.log10(massLoss.value)}
            maxLength={focalOrbsmax * 0.3}
            orbsmax={focalOrbsmax}
            eccen={planet.pl_orbeccen ?? 0}
            argPeri={argPeriRad(planet.pl_orblper)}
            inc={focalRenderTilt.inc}
            omega={focalRenderTilt.omega}
            leading={massLoss.leading}
            clockRef={clock}
            focalSecsPerOrbit={FOCAL_SECS_PER_ORBIT}
          />
        </group>
      )}

      {/* Siblings — clickable to jump perspective, hover shows name.
          Curated derived measurements (rotation_velocity,
          effective_temperature, circumplanetary disk parameters) are
          fetched system-wide by the API so siblings now light up the
          same enrichment paths the focal planet uses: warm fallback
          color from T_eff, visibly-rotating spin texture, CPD ring.
          Without this enrichment a system like PDS 70 only ever
          showed the focal planet's curated data, hiding the same
          measurements on the sibling. */}
      {siblings
        .filter((s) => s.pl_name !== planet.pl_name && s.pl_orbsmax != null)
        .map((s) => {
          const siblingRadius = planetDisplayRadius(s.pl_rade, s.pl_orbsmax!, planet.st_rad, sunRadius);
          const siblingTeff = focalEffectiveTeff(scene.derived_measurements, s.pl_name);
          const siblingSpinRow = bestDerived(scene.derived_measurements, s.pl_name, 'rotation_velocity');
          const siblingSpinOmega = siblingSpinRow?.value != null && s.pl_rade != null && s.pl_rade > 0
            ? stylizedSpinOmega(siblingSpinRow.value, s.pl_rade)
            : null;
          const siblingCpd = focalCircumplanetaryDisk(scene.derived_measurements, s.pl_name);
          return (
            <group
              key={s.pl_name}
              ref={(g) => { if (g) siblingRefs.current.set(s.pl_name, g); else siblingRefs.current.delete(s.pl_name); }}
            >
              <PlanetBody
                position={[0, 0, 0]}
                radius={siblingRadius}
                pl_eqt={s.pl_eqt}
                pl_dens={s.pl_dens}
                pl_rade={s.pl_rade}
                name={s.pl_name}
                onHover={setHovered}
                onClick={() => jumpTo(s.pl_name)}
                effectiveTempK={siblingTeff}
                rotationOmegaRad={siblingSpinOmega}
              />
              {siblingCpd && (
                <CircumplanetaryDiskRing planetRadius={siblingRadius} />
              )}
              {hovered === s.pl_name && <PlanetLabel name={s.pl_name} subtitle="click to jump" />}
            </group>
          );
        })}

      {/* Companion stars (static — they orbit on millennia timescales,
          irrelevant at our 60-sec-per-orbit pacing). Position angles
          are filled in for NULL-PA companions so tight unresolved
          binaries (Kepler-444 BC, etc.) render at distinct positions
          like the 2D PlanetCard does, instead of stacking at PA=0. */}
      {filledCompanions.map((c) => (
        <CompanionStar
          key={c.component_designation}
          companion={c}
          systemDistancePc={scene.host_star?.distance_gspphot_pc ?? scene.planet.sy_dist ?? scene.planet.distance_manual_pc ?? null}
          hostname={planet.hostname}
          onHover={setHovered}
          hoveredKey={hovered}
          focalOrbsmaxAu={focalOrbsmax}
          hostRsun={planet.st_rad}
          showPersistentLabel={showStarLabels}
        />
      ))}

      {/* Companion HUD tracker: invisible component inside the Canvas
          that uses useFrame to project each companion's position to
          screen space and write the direction angle + in-view flag
          into a shared ref. The fixed-position HUD panel (outside the
          Canvas, in ScenePage) reads from the same ref. */}
      {showCompanions && companionDirectionsRef && (
        <CompanionHUDTracker
          companions={filledCompanions}
          systemDistancePc={scene.host_star?.distance_gspphot_pc ?? scene.planet.sy_dist ?? scene.planet.distance_manual_pc ?? null}
          directionsRef={companionDirectionsRef}
        />
      )}
    </>
  );
}

// Format a companion's full system-relative name from the planet's host
// hostname + the companion's catalog designation. Strips the trailing
// component letter from hostname if present so "16 Cyg B" + "A" becomes
// "16 Cyg A" (and not the confusing "16 Cyg B A"). For systems without a
// trailing letter on the host (e.g. "Kepler-444" + "B") it just appends:
// "Kepler-444 B".
function companionFullName(hostname: string, designation: string): string {
  const stem = hostname.replace(/\s+[A-Z]$/, '');
  return `${stem} ${designation}`;
}

// Drop companion rows whose designation matches the host's trailing
// component letter — these are self-references introduced by bulk WDS /
// SIMBAD ingest, where the catalog stored both A→B and B→A relations and
// the latter ends up as "16 Cyg B has a companion designated B." Real
// curated rows never name a companion the same letter as the host.
function dropSelfReferenceCompanions(
  hostname: string,
  companions: BinaryCompanion[],
): BinaryCompanion[] {
  const trailing = hostname.match(/\s+([A-Z])$/)?.[1];
  if (!trailing) return companions;
  return companions.filter((c) => c.component_designation !== trailing);
}

// Only keep companions the user can actually navigate to and find in
// the 3D scene. Two reasons to drop:
//   1. inner_binary = true — already rendered as one of the two suns
//      of BinaryPhotospheres at the host position; the user is already
//      looking at the body, no navigation needed
//   2. separation_arcsec = null — no positional data, so we can't
//      place a body or rotate an arrow toward one. Catches inner-binary
//      partners from rows where inner_binary hasn't been set yet
function dropUnpointableCompanions(
  companions: BinaryCompanion[],
): BinaryCompanion[] {
  return companions.filter(
    (c) => c.inner_binary !== true && c.separation_arcsec != null,
  );
}

// Fill in missing position_angle_deg values by spreading companions evenly
// around the circle by their index. Mirrors PlanetCard.tsx's 2D fallback
// (line ~352) so both views agree: NULL PA → artistic spread, not all
// stacked at 0°. Tight unresolved binaries like Kepler-444 BC have NULL
// PAs in the catalog and would otherwise render at identical 3D positions
// (B and C visually stacked, only one visible).
function fillCompanionPositionAngles(
  companions: BinaryCompanion[],
): BinaryCompanion[] {
  const N = companions.length;
  return companions.map((c, i) => {
    if (c.position_angle_deg != null) return c;
    return { ...c, position_angle_deg: (i / Math.max(1, N)) * 360 };
  });
}

// Shared placement helper for binary/triple companion stars. 1 AU subtends
// 1 arcsec at 1 pc, so projected separation in AU is sep_arcsec * dist_pc.
// Position angle (deg E of N) becomes the azimuthal direction in the XZ
// plane; a fixed 30° lift out of the plane keeps wide companions visually
// off the orbital plane the planets live in (since the true 3D orientation
// is unknown).
//
// Returned by both the visible CompanionStar component and the HUD
// tracker, so they place the companion at exactly the same world point.
function companionScenePos(
  companion: BinaryCompanion,
  systemDistancePc: number | null,
): { sepAU: number; position: [number, number, number] } | null {
  if (companion.separation_arcsec == null || systemDistancePc == null) return null;
  const sepAU = companion.separation_arcsec * systemDistancePc;
  if (sepAU <= 0) return null;
  const pa = ((companion.position_angle_deg ?? 0) * Math.PI) / 180;
  const tiltY = Math.sin(0.52);   // ~30° lift above XZ plane
  const planar = Math.cos(0.52);
  return {
    sepAU,
    position: [
      sepAU * Math.cos(pa) * planar,
      sepAU * tiltY,
      sepAU * Math.sin(pa) * planar,
    ],
  };
}

// Companion HUD: a fixed-position panel listing each companion with a
// rotating arrow that points toward the body in 3D space. Stays put on
// the screen; only the arrows rotate as the camera pans.
//
// Implementation is split:
//
//   * CompanionHUDTracker lives inside the Canvas (it needs useThree to
//     read the camera). It mutates a shared CompanionDirectionRef map
//     each frame with the current angle + in-view flag for each group.
//
//   * CompanionHUDPanel lives outside the Canvas as a regular DOM
//     element. It re-renders at ~10Hz and reads the same ref to display
//     the rotated arrows. No drei <Html> involvement, so the panel
//     stays statically positioned regardless of camera motion.
//
// The shared-ref pattern keeps per-frame work in a useFrame (no React
// re-renders 60×/sec) while letting the panel re-render at a sane rate.

export type CompanionDirectionRef = React.MutableRefObject<
  Map<string, { deg: number; inView: boolean }>
>;

function CompanionHUDTracker({
  companions,
  systemDistancePc,
  directionsRef,
}: {
  companions: BinaryCompanion[];
  systemDistancePc: number | null;
  directionsRef: CompanionDirectionRef;
}) {
  const { camera } = useThree();
  const worldVec = useMemo(() => new THREE.Vector3(), []);
  const ndcVec = useMemo(() => new THREE.Vector3(), []);

  // Threshold past which we call the body "off-screen" — i.e. the arrow
  // should rotate, not show as in-view. Slightly inside the NDC edge
  // so the body is comfortably visible before we flip the indicator.
  const SCREEN_BOUND = 0.92;

  useFrame(() => {
    for (const c of companions) {
      const placement = companionScenePos(c, systemDistancePc);
      if (!placement) continue;
      worldVec.set(...placement.position);
      ndcVec.copy(worldVec).project(camera);

      const behind = ndcVec.z > 1;
      let nx = ndcVec.x;
      let ny = ndcVec.y;
      if (behind) { nx = -nx; ny = -ny; }

      const inView = !behind
        && Math.abs(nx) <= SCREEN_BOUND
        && Math.abs(ny) <= SCREEN_BOUND;

      // Arrow rotation: CSS rotate is clockwise-positive, atan2 is
      // counter-clockwise-positive in NDC space (y-up), so negate.
      const deg = -Math.atan2(ny, nx) * 180 / Math.PI;
      directionsRef.current.set(c.component_designation, { deg, inView });
    }
  });

  return null;
}

function CompanionHUDPanel({
  companions,
  hostname,
  systemDistancePc,
  directionsRef,
}: {
  companions: BinaryCompanion[];
  /** Planet's host hostname (e.g. "16 Cyg B") — used to build the full
      system-relative companion name (so the row reads "16 Cyg A · 815 AU"
      instead of a confusing bare "A · 815 AU"). */
  hostname: string;
  systemDistancePc: number | null;
  directionsRef: CompanionDirectionRef;
}) {
  // Force a re-render at ~10Hz to pick up the latest direction values
  // from the ref. Cheaper than a 60Hz setState, smoother than 1Hz.
  const [, forceUpdate] = useState(0);
  useEffect(() => {
    const id = window.setInterval(() => forceUpdate((n) => n + 1), 100);
    return () => window.clearInterval(id);
  }, []);

  if (companions.length === 0) return null;

  return (
    <div
      style={{
        position: 'fixed',
        top: HEADER_OFFSET_PX + 44,   // sit just below the TopRightHUD row
        right: 16,
        zIndex: 9,
        background: 'rgba(11, 13, 18, 0.88)',
        border: '1px solid var(--border)',
        borderRadius: 4,
        padding: '0.45rem 0.6rem',
        fontFamily: 'monospace',
        fontSize: '0.72rem',
        color: 'var(--fg)',
        backdropFilter: 'blur(4px)',
        pointerEvents: 'none',
        userSelect: 'none',
        minWidth: 140,
      }}
    >
      <div
        style={{
          fontSize: '0.65rem',
          color: 'var(--fg-muted)',
          textTransform: 'uppercase',
          letterSpacing: '0.08em',
          marginBottom: '0.35rem',
        }}
      >
        Companions
      </div>
      {companions.map((c) => {
        const placement = companionScenePos(c, systemDistancePc);
        const accent = spectralTypeToColor(c.component_spectype);
        const dir = directionsRef.current.get(c.component_designation);
        const deg = dir?.deg ?? 0;
        const inView = dir?.inView ?? false;
        return (
          <div
            key={c.component_designation}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '2px 0',
              fontWeight: 600,
              lineHeight: 1.4,
            }}
          >
            {/* Arrow: rotates to point in the companion's direction when
                off-screen; replaced by a static dot when the body is
                already in view (no nav needed). */}
            <span
              style={{
                color: accent,
                fontSize: '1.1rem',
                lineHeight: 1,
                width: '1.2em',
                textAlign: 'center',
                display: 'inline-block',
                transform: inView ? 'none' : `rotate(${deg}deg)`,
                transformOrigin: 'center',
              }}
            >
              {inView ? '●' : '➤'}
            </span>
            <span style={{ flex: 1 }}>
              {companionFullName(hostname, c.component_designation)}
              {placement && (
                <span style={{ color: 'var(--fg-muted)', marginLeft: 6 }}>
                  {formatAU(placement.sepAU)} AU
                </span>
              )}
            </span>
          </div>
        );
      })}
    </div>
  );
}

// Small reusable name pill for star bodies. Used by both CompanionStar
// (wide companions) and the host-star rendering (single Photosphere or
// the two stars of a BinaryPhotospheres inner binary). Same visual
// language so the user reads the scene consistently.
function StarNameLabel({
  name,
  accentColor,
  yOffsetAU,
}: {
  name: string;
  accentColor: string;
  yOffsetAU: number;
}) {
  return (
    <Html
      position={[0, yOffsetAU, 0]}
      center
      zIndexRange={[8, 0]}
      style={{
        pointerEvents: 'none',
        userSelect: 'none',
        color: '#e6edf3',
        background: 'rgba(11, 13, 18, 0.85)',
        padding: '2px 7px',
        borderRadius: 3,
        border: `1px solid ${accentColor}`,
        whiteSpace: 'nowrap',
        fontWeight: 600,
        fontSize: '0.72rem',
        fontFamily: 'monospace',
        letterSpacing: '0.02em',
      }}
    >
      <span style={{ color: accentColor, marginRight: 5 }}>◆</span>
      {name}
    </Html>
  );
}

function CompanionStar({
  companion,
  systemDistancePc,
  hostname,
  onHover,
  hoveredKey,
  focalOrbsmaxAu,
  hostRsun,
  showPersistentLabel = false,
}: {
  companion: BinaryCompanion;
  systemDistancePc: number | null;
  hostname: string;
  onHover?: (name: string | null) => void;
  hoveredKey?: string | null;
  // Focal planet's orbsmax in AU — sets the scene's overall scale and so
  // determines how big a companion has to be to remain visibly more than a
  // pixel from the default camera vantage (~2.4 × orbsmax from origin).
  focalOrbsmaxAu: number;
  // Host star's measured radius in solar radii. Passed so that a companion
  // with no recorded spectral type doesn't fall back to the K-dwarf default
  // (0.7 Rsun) and render absurdly large next to a small M-dwarf primary.
  hostRsun?: number | null;
  // When true, render a persistent designation label above the companion
  // body so the user can disambiguate multiple visible companions without
  // hovering each one. Toggled from PlaybackControls' "star labels" button.
  showPersistentLabel?: boolean;
}) {
  // 1 AU subtends 1 arcsec at 1 pc — so projected separation in AU is just
  // sep_arcsec * distance_pc. We have no information on the line-of-sight
  // component, so the companion's true distance from the primary is at least
  // this and unknown how much more.
  const placement = companionScenePos(companion, systemDistancePc);
  if (!placement) return null;
  const { sepAU, position } = placement;

  const color = spectralTypeToColor(companion.component_spectype);
  const teff = estimateStarTeff(companion.component_spectype);
  // Companion-star physical radius isn't in our data; estimate from spectral
  // type (M ~0.3 R_sun, K ~0.7, G ~1, etc.). Apply BODY_EXAG so the
  // companion has a VISIBLE disc at scene scale — the same exaggeration the
  // primary photosphere uses. Without it the companion is ~0.005 AU radius
  // at hundreds-of-AU separation, sub-pixel from any camera vantage and
  // effectively invisible (one of the reasons triple-star systems looked
  // like single-star systems before this fix).
  //
  // Cap at 1/8 of the separation to the primary so very close companions
  // (GJ 229's 27 AU B) don't visually engulf the primary or eclipse the
  // planet's orbit. The cap kicks in when sepAU < ~12 AU for solar-radius
  // companions — none of our currently-curated triples hit that.
  //
  // Floor at 0.05 AU so even white dwarfs and ultra-cool brown dwarfs
  // (sub-R_sun bodies) still render large enough to read as actual stars
  // at typical zoom levels — without this floor, a D-type companion is a
  // 0.028-AU pinprick easily lost against the starfield.
  //
  // Additional scene-scale floor at 1% of focal orbsmax: the default camera
  // sits ~2.4 × focalOrbsmax from origin, so on the largest-orbit imaged
  // systems (VHS J125601 at 350 AU, ITG 15 at 435 AU, 2MASS J0249-0557 at
  // 1950 AU) the BODY_EXAG=500 exaggerated radius shrinks to 1–2 pixels at
  // default vantage. Floor needs to be aggressive enough that the solid
  // photosphere disc — not just its corona — is visually dominant; the
  // corona renders with additive blending and doesn't occlude orbit lines
  // behind it, so a "mostly corona" companion appears to have the back
  // half of the orbit shining through it.
  const MIN_COMPANION_RADIUS_AU = Math.max(0.05, focalOrbsmaxAu * 0.01);
  const trueRadiusAU = estimateStarRadiusRsun(companion.component_spectype, hostRsun) * RSUN_IN_AU;
  const exaggerated = trueRadiusAU * BODY_EXAG;
  const radiusAU = Math.max(MIN_COMPANION_RADIUS_AU, Math.min(exaggerated, sepAU / 8));

  // Render companions with the SAME shader treatment as the primary host —
  // Photosphere (limb darkening + granulation + teff-driven HDR) plus the
  // StellarCorona halo it carries internally. Dwarfs (brown / white / red)
  // are stars too; they should glow with a corona, not appear as flat discs.
  //
  // Hover behaviour mirrors PlanetBody: an invisible hit-test sphere a few
  // times larger than the visible disc reports its label up to the parent
  // (SceneContents) which manages the shared `hovered` state. Distinct keys
  // ("VHS J125601.92-125723.9 B" vs the planet's "VHS J125601.92-125723.9 b")
  // prevent collisions between companion designations and planet names.
  const labelName = `${hostname} ${companion.component_designation}`;
  const kindLabel = companionKind(companion.component_spectype);
  const subtitleParts = [
    companion.component_spectype,
    kindLabel,
    `${formatAU(sepAU)} AU`,
  ].filter(Boolean) as string[];
  const subtitle = subtitleParts.length > 0 ? subtitleParts.join(' · ') : 'companion star';
  return (
    <group position={position}>
      <Photosphere radius={radiusAU} color={color} teff={teff} />
      <pointLight intensity={0.4} color={color} distance={0} decay={0} />
      <mesh
        onPointerOver={(e) => {
          e.stopPropagation();
          if (onHover) onHover(labelName);
          document.body.style.cursor = 'default';
        }}
        onPointerOut={(e) => {
          e.stopPropagation();
          if (onHover) onHover(null);
          document.body.style.cursor = 'default';
        }}
      >
        <sphereGeometry args={[Math.max(radiusAU * 4, 0.2), 16, 16]} />
        <meshBasicMaterial visible={false} />
      </mesh>
      {hoveredKey === labelName && (
        <PlanetLabel name={labelName} subtitle={subtitle} yOffset={radiusAU * 1.6} />
      )}
      {/* Persistent designation label: floats well above the body when
          the "star labels" toggle is on. Spectral-type colored border
          visually ties the label to its body. Position offset is
          radiusAU * 3.5 so the pill doesn't overlap the star at any
          reasonable zoom. Suppressed while the hover label is active
          to avoid double-stacking the same name. */}
      {showPersistentLabel && hoveredKey !== labelName && (
        <StarNameLabel
          name={labelName}
          accentColor={color}
          yOffsetAU={radiusAU * 3.5}
        />
      )}
    </group>
  );
}

function companionKind(spectype: string | null): string | null {
  if (!spectype) return null;
  const letter = spectype.trim().charAt(0).toUpperCase();
  if (letter === 'L' || letter === 'T' || letter === 'Y') return 'brown dwarf';
  if (letter === 'D') return 'white dwarf';
  if (letter === 'M') return 'red dwarf';
  return null;
}

function spectralTypeToColor(spectype: string | null): string {
  if (!spectype) return '#ffe6c0';
  const letter = spectype.trim().charAt(0).toUpperCase();
  switch (letter) {
    case 'O': case 'B': return '#a4c8ff';
    case 'A':           return '#dce6ff';
    case 'F': case 'G': return '#fff7d2';
    case 'K':           return '#ffd49a';
    case 'M':           return '#ff9b6a';
    case 'L': case 'T': case 'Y': case 'D': return '#cf5040';
    default:            return '#ffe6c0';
  }
}

// ── photosphere ──────────────────────────────────────────────────────────
// Custom shader for the visible disc of the star. Adds limb darkening (real
// physics — the edge of a star is dimmer because we're looking through more
// atmospheric path) and subtle granulation noise. Result: a soft, alive
// edge rather than a hard sharp circle.

function Photosphere({ radius, color, teff, rotationPeriodDays, spot, haloIntensity = 0.4, oblateness = 0 }: { radius: number; color: string; teff: number | null; rotationPeriodDays?: number | null; spot?: StarSpotProps | null; haloIntensity?: number; oblateness?: number }) {
  // Opaque shader — must write depth properly so orbit lines and planets
  // behind the sun get occluded. The "soft edge" is achieved by the corona
  // (drawn additively over and around the photosphere edge), not by making
  // the photosphere itself transparent.
  //
  // HDR brightness scales with stellar temperature so cool M-dwarfs stay
  // deep-red instead of getting desaturated to yellow by ACES tone mapping
  // (which compresses highlights toward white), and hot O/B stars look
  // appropriately blinding. Loosely based on Stefan-Boltzmann (L ∝ T⁴) but
  // softened so cool stars don't disappear and hot stars don't rocket past
  // bloom budget.
  const teffK = teff ?? 5778;
  // Cool stars get a HDR BOOST, not a dampening — deep red against black
  // has much lower perceived contrast than white against black at the same
  // luminance (eye sensitivity to long wavelengths is ~10× lower than to
  // green). So we push cool-star HDR up to ~2.8× to compensate, ensuring
  // their bloom-halo is visually comparable to a hot star's white halo
  // instead of looking like a dim red disc with no glow. The saturation
  // push on uColor below keeps them red despite the extra brightness.
  const cool = Math.max(0, Math.min(1, (5778 - teffK) / 3278));
  const warmth = 1.0 + cool * 0.4;
  // Hot stars get an additive multiplier on top of the base, CAPPED at 1.5
  // so mipmapBlur can't dome out on extreme HDR values (the original dome
  // bug was at uncapped hot * 0.0008 → KELT-9 reaching 4.5× by itself).
  const hot = Math.max(0, teffK - 5778);
  const bonus = 1.0 + Math.min(1.5, hot * 0.0006);
  // Base 0.8 × warmth × bonus → uHdr range: ~1.1 (TRAPPIST-1) → 0.8 (Sun)
  // → ~2.0 (KELT-9 and hotter). Tuned so the bulk of the disc surface sits
  // below the Bloom luminanceThreshold and stops feeding bleed back across
  // the photosphere; only the bright center contributes to bloom now, which
  // keeps surface detail (granulation, starspots) legible. Cool stars still
  // read as red (warmth boost + per-channel saturation push); hot stars
  // still get the dramatic bonus, just less crushingly so.
  const hdrScale = 0.8 * warmth * bonus;
  // Two-sided temperature tint, driven by measured st_teff, so F/G/K/M
  // stars are visibly distinguishable instead of all sitting in the
  // near-white blackbody dead zone. Real blackbody colors at 4500-7000K
  // are honest-but-subtle (broad spectra, tints in the "barely tinted
  // off-white" range); for the renderer's purposes we exaggerate the
  // tint linearly off solar (5778K), pushing cool stars toward red and
  // hot stars toward blue so spectral class reads from across the room.
  // Sun-anchored: G-type at solar T gets effectively neutral; the further
  // a star sits from 5778K in either direction, the stronger the tint.
  // Cool tint ramp: full saturation push by ~3300K (deep M dwarf).
  // Hot tint ramp: full push by ~10000K (early B / late A).
  const coolColor = Math.max(0, Math.min(1, (5778 - teffK) / 2500));
  const hotTint   = Math.max(0, Math.min(1, (teffK - 5778) / 4200));
  const saturated = new THREE.Color(color);
  // Cool: suppress G + B → deeper orange / red (TRAPPIST-1, K dwarfs).
  saturated.g *= 1.0 - coolColor * 0.7;
  saturated.b *= 1.0 - coolColor * 0.85;
  // Hot: suppress R + a little G → blue / blue-white (KELT-9, A/B stars).
  saturated.r *= 1.0 - hotTint * 0.45;
  saturated.g *= 1.0 - hotTint * 0.15;
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor:         { value: saturated },
      uTime:          { value: 0 },
      uHdr:           { value: hdrScale },
      uLogDepthBufFC: { value: 0 },
      // Starspot uniforms, updated by a useEffect below. A dark patch fixed in
      // object space; the mesh's group rotation moves it across the visible
      // disc, which is precisely the photometric signal (spot crossing the
      // disc) astronomers use to measure stellar rotation in the first place.
      // Size (inner/outer cosines) is also data-driven (rotation rate) so
      // active stars carry visibly bigger spots than slow Sun-like ones.
      uSpotDir:       { value: new THREE.Vector3(0, 1, 0) },
      uSpotIntensity: { value: 0 },
      uSpotInnerCos:  { value: 0.990 },
      uSpotOuterCos:  { value: 0.978 },
    },
    // Manual log-depth path for XR parity, scoped to Photosphere. This shader
    // is custom and paired with a depth pre-pass; keeping depth math explicit
    // here avoids eye-camera log-depth mismatch in XR while preserving pass
    // parity. Planet body/atmosphere shaders continue using three.js chunks.
    vertexShader: `
      #include <common>

      varying vec3 vNormal;
      varying vec3 vViewDir;
      varying vec3 vWorldPos;
      varying float vFragDepth;
      varying float vIsPerspective;
      void main() {
        vNormal = normalize(normalMatrix * normal);
        vec4 mvPos = modelViewMatrix * vec4(position, 1.0);
        vViewDir = normalize(-mvPos.xyz);
        vWorldPos = position;
        gl_Position = projectionMatrix * mvPos;
        vFragDepth = 1.0 + gl_Position.w;
        vIsPerspective = float(isPerspectiveMatrix(projectionMatrix));
      }
    `,
    fragmentShader: `
      #include <common>

      uniform vec3 uColor;
      uniform float uTime;
      uniform float uHdr;
      uniform float uLogDepthBufFC;
      uniform vec3 uSpotDir;
      uniform float uSpotIntensity;
      uniform float uSpotInnerCos;
      uniform float uSpotOuterCos;
      varying vec3 vNormal;
      varying vec3 vViewDir;
      varying vec3 vWorldPos;
      varying float vFragDepth;
      varying float vIsPerspective;
      const float LOG_DEPTH_EPSILON = 1e-6;

      float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
      float noise(vec3 p) {
        vec3 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(
          mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x),
              mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
          mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x),
              mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y),
          f.z);
      }

      void main() {
        gl_FragDepth = vIsPerspective == 0.0
          ? gl_FragCoord.z
          : log2(max(LOG_DEPTH_EPSILON, vFragDepth)) * uLogDepthBufFC * 0.5;

        // Granulation noise + aggressive limb darkening. The limb floor of
        // 0.15 (way past real-Sun ~0.4) is deliberately exaggerated so the
        // photosphere edge fades almost to black before meeting the bloom
        // corona, eliminating the hard-disc silhouette and making the
        // sun read as a glow rather than a sharp circle. pow(mu, 0.7)
        // makes the falloff gradual — most of the disc stays bright, but
        // the outer ~30% darkens significantly.
        vec3 np = vWorldPos * 18.0 + vec3(uTime * 0.08, uTime * 0.04, 0.0);
        float granule = (noise(np) - 0.5) * 0.5 + (noise(np * 2.3) - 0.5) * 0.25;
        float surf = 1.0 + granule * 0.10;

        // Starspot. Object-space; the parent group rotates the mesh so the
        // spot transits the visible disc at the rotation rate. Inner / outer
        // cosines are data-driven uniforms — slow Sun-like rotators get a
        // small low-latitude spot (~3-5° outer); fast rotators get a big
        // polar-cap-ish spot (~20°+ outer). Brightness drops to 50% of the
        // surrounding photosphere (slightly above real sunspot umbra ~30%
        // of quiet-Sun).
        //
        // Edge noise: real sunspot groups are irregular, not perfect
        // circles. We perturb the spot's effective threshold by surface
        // noise sampled in object space, so the boundary wobbles by ~±3°
        // and reads as an organic blot instead of a stamped disc.
        vec3 nLocal = normalize(vWorldPos);
        float spotCos = dot(nLocal, uSpotDir);
        float spotEdgeNoise = (noise(nLocal * 6.0) - 0.5) * 0.018;
        float spotFalloff = smoothstep(uSpotOuterCos + spotEdgeNoise,
                                       uSpotInnerCos + spotEdgeNoise,
                                       spotCos);
        surf *= mix(1.0, 0.50, spotFalloff * uSpotIntensity);

        // Limb darkening. Floor at 0.25 — the disc still reads as a 3-D
        // sphere (1.0 at center → 0.25 at silhouette, a 4× falloff that
        // gives clear center-to-edge shading) and the silhouette is now
        // dim enough that when the additive corona kicks in at the edge,
        // the transition is gradual rather than a hard brightness step.
        // Linear (no pow) keeps the falloff gentle across the whole disc.
        float mu = max(0.0, dot(vNormal, vViewDir));
        float limb = mix(0.25, 1.0, mu);

        // HDR multiplier is per-star (computed JS-side from teff). Cool
        // stars use a smaller boost so ACES doesn't desaturate their reds
        // toward yellow; hot stars use a much larger boost so they read as
        // blindingly bright. Pure ACES is famous for desaturating in the
        // highlights — the prior comment claiming otherwise was wrong.
        gl_FragColor = vec4(uColor * surf * limb * uHdr, 1.0);
      }
    `,
    transparent: false,
    depthWrite: true,
    depthTest: true,
    toneMapped: true,
  }), [color, hdrScale, teff]);

  // Push the starspot uniforms when the spot props change (or vanish).
  // The material itself is memoised on color/hdrScale/teff, so spot changes
  // do not recreate it; we just update the uniform values in place.
  useEffect(() => {
    if (spot) {
      material.uniforms.uSpotDir.value.copy(spot.dir);
      material.uniforms.uSpotIntensity.value = 1.0;
      material.uniforms.uSpotInnerCos.value = spot.innerCos;
      material.uniforms.uSpotOuterCos.value = spot.outerCos;
    } else {
      material.uniforms.uSpotIntensity.value = 0.0;
    }
  }, [material, spot]);

  // Spin axis = +Y, the same axis the obliquity tilt references. Rate is
  // stylized like the orbit pacing (true periods are days; at 60-sec orbits a
  // real rate would be imperceptible or absurd): a 10-day rotator turns once
  // per ~30 s, faster rotators visibly faster, slower slower. Only rotates
  // when a rotation period is known; otherwise the granulation drift alone
  // animates the surface, as before.
  const spinGroup = useRef<THREE.Group>(null);
  useFrame((state) => {
    material.uniforms.uTime.value = state.clock.getElapsedTime();
    const xrCamera = state.gl.xr.getCamera();
    const xrFar = (xrCamera.isArrayCamera ? xrCamera.cameras[0]?.far : undefined) ?? xrCamera.far;
    const activeFar = state.gl.xr.isPresenting ? xrFar : state.camera.far;
    const fallbackFar = Number.isFinite(state.camera.far) && state.camera.far > 0 ? state.camera.far : 1000;
    const safeFar = Number.isFinite(activeFar) && activeFar > 0 ? activeFar : fallbackFar;
    material.uniforms.uLogDepthBufFC.value = 2.0 / (Math.log(safeFar + 1.0) / Math.LN2);
    if (spinGroup.current && rotationPeriodDays && rotationPeriodDays > 0) {
      const clampedP = Math.min(200, Math.max(0.2, rotationPeriodDays));
      const omega = ((2 * Math.PI) / 30) * (10 / clampedP); // rad/sec
      spinGroup.current.rotation.y = state.clock.getElapsedTime() * omega;
    }
  });

  // Two-pass rendering to GUARANTEE the sun occludes anything behind it:
  //   1) Depth pre-pass at renderOrder=-100 — invisible (colorWrite=false),
  //      writes only depth. Runs FIRST in the opaque pass, before any planet.
  //      Result: when planets render afterwards, a far-side planet's depth
  //      test against the existing sun-depth FAILS and the planet is culled
  //      before being drawn at all. No bleed-through possible.
  //   2) Color pass at renderOrder=10 — the visible photosphere shader.
  //      depthFunc=LessEqual ensures it draws cleanly on top of its own
  //      pre-pass depth without z-fighting.
  // Same geometry on both passes (64 segs) so the depth values match
  // identically between pre-pass and color pass. Both materials now use
  // logarithmic depth (the color shader writes gl_FragDepth manually with
  // the same formula as three.js log-depth chunks; MeshBasic gets log-depth
  // automatically when the renderer flag is on), so no precision mismatch
  // that would cause z-fighting.
  const depthOnlyMaterial = useMemo(
    () => new THREE.MeshBasicMaterial({
      colorWrite: false,
      depthWrite: true,
      depthTest: true,
    }),
    [],
  );
  return (
    <>
      {/* Both photosphere meshes spin together about +Y so depth pre-pass and
          color pass stay coincident; a sphere is rotation-symmetric so the
          depth occlusion is unaffected, and the granulation (sampled in object
          space) visibly rotates with the disc. The corona is a camera-facing
          billboard, so it stays outside the spin group.
          Oblateness squashes the spin axis (Y) by (1 − f): the equator stays
          at the catalog radius, the poles shrink. The rendered squash is
          exaggerated 3× so it reads through the corona's additive halo —
          same idiom as BODY_EXAG = 500 for planet sizes. Capped at 0.30
          so even break-up rotators stay "credibly stellar." The InfoPanel
          shows the true physical f, not the visual factor. */}
      <group ref={spinGroup} scale={[1, 1 - Math.min(0.30, oblateness * 3), 1]}>
        <mesh material={depthOnlyMaterial} renderOrder={-100}>
          <sphereGeometry args={[radius, 64, 64]} />
        </mesh>
        <mesh material={material} renderOrder={10}>
          <sphereGeometry args={[radius, 64, 64]} />
        </mesh>
      </group>
      {/* Two-layer corona, modelled on the long-tail PSF a real bright
          point source produces in the eye / a camera:
          - INNER (sizeMult=2.5, peakAlpha=1.0): bright halo hugging the
            disc edge. This is what dominates the visible glow in normal
            views, and is compact enough that a planet in front fully
            occludes it.
          - OUTER (sizeMult=6, peakAlpha=0.12): wide soft aura extending
            far past the disc. Dim enough to be subtle in normal views,
            but gives the halo a long gradient tail. During an eclipse,
            this layer also depth-occludes, leaving only the small fringe
            beyond the planet's silhouette — much closer to what a real
            eclipse photo shows (corona extending past the moon).
          Both are scaled by haloIntensity (data-driven from the star's
          apparent flux at the planet's orbit, st_lum + pl_orbsmax). */}
      <StellarCorona radius={radius} color={saturated} hdrScale={haloIntensity} sizeMult={2.5} peakAlpha={1.0} />
      {/* Outer: overlaps the inner (default startUv = disc edge) so the two
          layers' alpha profiles add into a single continuous gradient
          rather than meeting at a discontinuity. This is also closer to
          the real PSF physics — a bright source's profile is one
          monotonic distribution that can be decomposed into a bright core
          plus a faint long tail, not two concentric rings. peakAlpha 0.25
          keeps the outer layer subtle enough not to over-brighten the
          inner halo, while still extending visibly out to 6× sun radius. */}
      <StellarCorona radius={radius} color={saturated} hdrScale={haloIntensity} sizeMult={6.0} peakAlpha={0.25} />
    </>
  );
}

// ── geometric corona / star halo ─────────────────────────────────────────
// Camera-facing billboard rendered with AdditiveBlending.  Works in stereo
// XR because it is ordinary scene geometry — no post-process compositor
// needed.  On desktop the Bloom pass adds more glow on top; the two are
// complementary (Bloom amplifies the bright centre, corona provides the
// wide soft halo that Bloom would otherwise supply on its own).
//
// Size: billboard half-extent = 3.5 × photosphere radius so the halo
// extends well beyond the disc.  In shader UV space r = 1 corresponds to
// that half-extent, meaning the photosphere occupies r ≈ 0 – 0.286.
//
// Radial profile (alpha):
//   r < 0.25   — fade in from centre (photosphere covers this region)
//   r ≈ 0.25–0.40 — corona peak just outside photosphere edge
//   r > 0.40   — smooth halo decay, reaches 0 at r = 1.0
//
// renderOrder=20 — draws after the photosphere colour pass (renderOrder=10).
// AdditiveBlending is commutative so pixel order doesn't change the final
// colour value; renderOrder here gives deterministic draw ordering vs. r3f's
// default depth-sorted transparent pass.
function StellarCorona({
  radius, color, hdrScale,
  sizeMult = 2.5,
  peakAlpha = 1.0,
  startUv,
}: {
  radius: number; color: THREE.Color; hdrScale: number;
  /** Billboard size as a multiple of the photosphere radius. */
  sizeMult?: number;
  /** Multiplier on the halo's peak alpha. */
  peakAlpha?: number;
  /** UV radius at which the gradient starts (peak alpha). Defaults to
      1/sizeMult (the photosphere disc edge). For the outer of a two-layer
      stack, set this to where the inner corona ends so the outer does NOT
      overlap and add brightness on top of the inner; it then contributes
      purely as a wide soft tail past the inner halo. */
  startUv?: number;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const billboardHalf = radius * sizeMult;
  const discEdgeUv = startUv ?? 1.0 / sizeMult;

  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor:      { value: color.clone() },
      uHdr:        { value: hdrScale },
      uDiscEdgeUv: { value: discEdgeUv },
      uPeakAlpha:  { value: peakAlpha },
    },
    vertexShader: `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform vec3  uColor;
      uniform float uHdr;
      uniform float uDiscEdgeUv;
      uniform float uPeakAlpha;
      varying vec2  vUv;

      void main() {
        // Signed distance from billboard centre, normalised so r = 1 at edge.
        vec2  c = vUv * 2.0 - 1.0;
        float r = length(c);
        if (r > 1.0) discard;

        // Monotonic gradient-to-transparent halo: peak alpha at the disc
        // edge (r = 1/sizeMult), smoothly fading to zero at the billboard
        // edge (r = 1.0). The "glow" you see IS this falloff. Overall scale
        // is set by uHdr (data-driven from apparent flux) and uPeakAlpha
        // (per-instance — 1.0 for the bright inner corona, 0.10-0.15 for
        // an outer wide dim layer that paints a long soft tail).
        float alpha = (1.0 - smoothstep(uDiscEdgeUv, 1.0, r)) * uPeakAlpha;

        // Additive: bright fragments add light to whatever is behind them.
        // uHdr mirrors the photosphere's HDR multiplier so cool stars get a
        // rich deep-red halo and hot stars get a blinding white one.
        gl_FragColor = vec4(uColor * uHdr * alpha, alpha);
      }
    `,
    blending:    THREE.AdditiveBlending,
    depthWrite:  false,
    depthTest:   true,
    transparent: true,
    side:        THREE.FrontSide,
  // Depend on colour channels because the THREE.Color object reference
  // is recreated each render but the channel values only change when the
  // star changes.  hdrScale captures the temperature-driven brightness;
  // discEdgeUv + peakAlpha capture per-instance shape so the inner and
  // outer corona compile to distinct materials.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [color.r, color.g, color.b, hdrScale, discEdgeUv, peakAlpha]);

  // Orient the billboard to face the camera every frame using lookAt, which
  // resolves through the full parent-transform chain.  Prefer this over
  // quaternion.copy(camera.quaternion): the latter copies a world-space
  // value as if it were local, which works today because no ancestor of
  // Photosphere rotates, but would silently break if one ever did.
  // In XR, state.camera is the parent ArrayCamera (head pose), so both eyes
  // share one billboard orientation.  The IPD-induced per-eye angular
  // difference is negligible at any realistic star-viewing distance, so the
  // head-pose approximation is visually indistinguishable.
  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.lookAt(state.camera.position);
    }
  });

  return (
    <mesh ref={meshRef} renderOrder={20} material={material}>
      <planeGeometry args={[billboardHalf * 2, billboardHalf * 2]} />
    </mesh>
  );
}

// ── binary photospheres (circumbinary systems) ───────────────────────────
// For cb_flag=1 planets, the host is a tight binary pair (the planet orbits
// both stars, Tatooine-style). Render two unequal suns orbiting their common
// barycenter at the system origin.
//
// Honest defaults — these systems are spectroscopic binaries (the two stars
// are too close together to resolve on the sky), so we typically don't have
// measured masses or radii for the secondary. We assume:
//   - Primary: 0.80× the host's nominal radius, full color from st_teff
//   - Secondary: 0.45× the nominal radius, slightly redder
//     (Statistically, secondaries in circumbinary systems are usually M-
//     dwarfs cooler than the primary — Kepler-16: K-dwarf + M-dwarf,
//     Kepler-47: G-type + M-dwarf, TOI-1338: F-type + M-dwarf, etc.
//     The shift toward red is a defensible visual default, not a measurement.)
// Barycenter-weighted orbital radii reflect the mass asymmetry: the smaller
// secondary swings on a larger circle, the bigger primary stays closer in.

function BinaryPhotospheres({
  radius, color, teff, paused, speed,
  showLabels = false,
  hostname,
}: {
  radius: number; color: string; teff: number | null; paused: boolean; speed: number;
  /** When true, render a persistent name label above each of the two
      inner stars (Aa and Ab) so the user can read which is which in
      circumbinary systems. */
  showLabels?: boolean;
  /** Planet's host hostname — used to build the inner-star labels.
      "PH1" → "PH1 Aa" / "PH1 Ab"; "TIC 172900988 Aa" →
      "TIC 172900988 Aa" / "TIC 172900988 Ab" (the trailing letter is
      stripped before suffixing so we don't get "... Aa Aa"). */
  hostname?: string;
}) {
  const starA = useRef<THREE.Group>(null);
  const starB = useRef<THREE.Group>(null);
  const clock = useRef(0);

  const primaryRadius   = radius * 0.80;
  const secondaryRadius = radius * 0.45;
  const separation      = radius * 3.5;
  // Mass-ratio-weighted barycenter offsets. Assume primary ~0.7 of total mass:
  // primary swings on a circle of 0.3*sep, secondary on 0.7*sep, opposite phase.
  const primaryArm   = separation * 0.30;
  const secondaryArm = separation * 0.70;
  const secondaryColor = shiftTowardRed(color);
  const SECS_PER_BINARY_ORBIT = 6;

  useFrame((_, delta) => {
    if (!paused) clock.current += delta * speed;
    const a = (clock.current / SECS_PER_BINARY_ORBIT) * Math.PI * 2;
    if (starA.current) starA.current.position.set( primaryArm  * Math.cos(a), 0,  primaryArm  * Math.sin(a));
    if (starB.current) starB.current.position.set(-secondaryArm * Math.cos(a), 0, -secondaryArm * Math.sin(a));
  });

  const nameAa = hostname ? companionFullName(hostname, 'Aa') : 'Aa';
  const nameAb = hostname ? companionFullName(hostname, 'Ab') : 'Ab';

  return (
    <>
      <group ref={starA}>
        <Photosphere radius={primaryRadius} color={color} teff={teff} />
        {showLabels && (
          <StarNameLabel
            name={nameAa}
            accentColor={color}
            yOffsetAU={primaryRadius * 3.5}
          />
        )}
      </group>
      <group ref={starB}>
        {/* Secondary uses a cooler-equivalent teff so its red-shifted
            color reads correctly through the Stefan-Boltzmann scaling. */}
        <Photosphere radius={secondaryRadius} color={secondaryColor} teff={teff != null ? teff * 0.65 : null} />
        {showLabels && (
          <StarNameLabel
            name={nameAb}
            accentColor={secondaryColor}
            yOffsetAU={secondaryRadius * 3.5}
          />
        )}
      </group>
    </>
  );
}

// Pull a hex color halfway toward a generic M-dwarf red. Used for the
// secondary in a circumbinary pair when we don't know its true composition
// (which is almost always the case — most secondaries in cb systems are
// M-dwarfs that the spectroscopic data can't characterize independently).
function shiftTowardRed(hex: string): string {
  const M_DWARF_REF: [number, number, number] = [255, 130, 70];   // generic deep orange-red
  const h = hex.replace('#', '');
  const r = parseInt(h.substring(0, 2), 16);
  const g = parseInt(h.substring(2, 4), 16);
  const b = parseInt(h.substring(4, 6), 16);
  const blend = (a: number, target: number) => Math.round(a * 0.5 + target * 0.5);
  const nr = blend(r, M_DWARF_REF[0]);
  const ng = blend(g, M_DWARF_REF[1]);
  const nb = blend(b, M_DWARF_REF[2]);
  return `#${nr.toString(16).padStart(2, '0')}${ng.toString(16).padStart(2, '0')}${nb.toString(16).padStart(2, '0')}`;
}

// ── orbit rings ──────────────────────────────────────────────────────────
// Draws the planet's elliptical path around the sun (at one focus). Uses
// pl_orbeccen so HD 80606b's wildly stretched cigar-orbit looks stretched
// and TRAPPIST-1's near-circular paths look circular. 128 segments — smooth
// even at extreme zoom.

function OrbitRing({
  orbsmax, eccen, color, opacity, inc = 0, omega = 0, argPeri = 0,
}: {
  orbsmax: number; eccen: number; color: string; opacity: number;
  inc?: number; omega?: number;
  /** Argument of periastron (radians). Rotates the ellipse within its plane
      so periapsis points in the catalogued direction. Composes with omega
      (longitude of ascending node) and inc to give the orbit its measured
      3-D orientation. */
  argPeri?: number;
}) {
  // Native three.js Line (gl_LINES, 1px width) instead of drei's Line2
  // wrapper. Line2 renders thick lines as instanced quad strips and its
  // depth output doesn't reliably occlude against custom shaders, which
  // caused orbit rings to draw on top of the photosphere. Native lines
  // depth-test correctly per fragment.
  //
  // Inclination + Ω tilt the entire ellipse out of the xz plane using
  // the same applyOrbitTilt rotation as the planet position calc, and
  // argPeri rotates it in the plane first so periapsis points in the
  // catalogued direction. The rendered planet sits exactly on its rendered
  // orbital path even when all three are nonzero.
  const geometry = useMemo(() => {
    const a = orbsmax;
    const e = Math.max(0, Math.min(0.99, eccen));
    const b = a * Math.sqrt(1 - e * e);
    const N = 256;
    const positions = new Float32Array((N + 1) * 3);
    const cosI = Math.cos(inc), sinI = Math.sin(inc);
    const cosO = Math.cos(omega), sinO = Math.sin(omega);
    const cosW = Math.cos(argPeri), sinW = Math.sin(argPeri);
    for (let i = 0; i <= N; i++) {
      const t = (i / N) * Math.PI * 2;
      const x_raw = a * Math.cos(t) - a * e;
      const z_raw = b * Math.sin(t);
      // In-plane rotation by argument of periastron
      const x0 = x_raw * cosW - z_raw * sinW;
      const z0 = x_raw * sinW + z_raw * cosW;
      // Inclination + Ω tilt
      positions[i * 3 + 0] = x0 * cosO + z0 * cosI * sinO;
      positions[i * 3 + 1] = -z0 * sinI;
      positions[i * 3 + 2] = -x0 * sinO + z0 * cosI * cosO;
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    return g;
  }, [orbsmax, eccen, inc, omega, argPeri]);

  const material = useMemo(
    () => new THREE.LineBasicMaterial({
      color,
      transparent: true,
      opacity,
      depthTest: true,
      depthWrite: false,
    }),
    [color, opacity],
  );

  return <primitive object={new THREE.Line(geometry, material)} />;
}

// Reference frame for spin-orbit obliquity: a faint ring in the stellar
// equatorial plane (XZ) at the focal orbit's scale, plus the spin axis
// through the poles (±Y). The tilted focal orbit is drawn against this, so
// the obliquity reads as the angle between the two rings. Convention only:
// the true sky orientation of the stellar spin axis is unknown (that's why
// λ is sky-projected), so +Y is a chosen reference, consistent with the XZ
// reference plane used everywhere else in the scene.
function StellarSpinReference({ orbsmax, showAxis = true, showEquator = true }: { orbsmax: number; showAxis?: boolean; showEquator?: boolean }) {
  const ringGeom = useMemo(() => {
    const N = 192;
    const positions = new Float32Array((N + 1) * 3);
    for (let i = 0; i <= N; i++) {
      const t = (i / N) * Math.PI * 2;
      positions[i * 3 + 0] = orbsmax * Math.cos(t);
      positions[i * 3 + 1] = 0;
      positions[i * 3 + 2] = orbsmax * Math.sin(t);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    return g;
  }, [orbsmax]);

  const axisGeom = useMemo(() => {
    const L = orbsmax * 1.18;
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(
      new Float32Array([0, -L, 0, 0, L, 0]), 3,
    ));
    return g;
  }, [orbsmax]);

  const ringMat = useMemo(
    () => new THREE.LineBasicMaterial({
      color: '#3f5d6b', transparent: true, opacity: 0.38, depthWrite: false,
    }),
    [],
  );
  const axisMat = useMemo(
    () => new THREE.LineBasicMaterial({
      color: '#5a7d8c', transparent: true, opacity: 0.5, depthWrite: false,
    }),
    [],
  );

  // Memoise the Line instances so React renders that flip the visibility
  // toggles (showAxis / showEquator) do not allocate new THREE.Line wrappers
  // each pass. The instances stay stable for the life of this component;
  // geometry + material identity already covers the only cases where the
  // line content changes (orbsmax-driven scale).
  const ringLine = useMemo(() => new THREE.Line(ringGeom, ringMat), [ringGeom, ringMat]);
  const axisLine = useMemo(() => new THREE.Line(axisGeom, axisMat), [axisGeom, axisMat]);

  // Three.js Line objects do NOT auto-dispose their geometry/material, and
  // R3F won't reliably dispose resources behind a <primitive>. Without these
  // cleanups, navigating between scenes (component unmount) and orbsmax
  // changes (new geometry buffers) would each leak GPU buffers. Geometry is
  // disposed when it changes or the component unmounts; materials only on
  // unmount, since they have no deps.
  useEffect(() => () => {
    ringGeom.dispose();
    axisGeom.dispose();
  }, [ringGeom, axisGeom]);
  useEffect(() => () => {
    ringMat.dispose();
    axisMat.dispose();
  }, [ringMat, axisMat]);

  return (
    <>
      {showEquator && <primitive object={ringLine} />}
      {showAxis && <primitive object={axisLine} />}
    </>
  );
}

// Format an AU value for the distance label. Adaptive precision based on
// magnitude: small distances need decimals to read meaningfully ("0.05 AU"),
// large distances don't ("142 AU"). Keeps the label compact at every scale.
function formatAU(v: number): string {
  if (v >= 100) return v.toFixed(0);
  if (v >= 10) return v.toFixed(1);
  if (v >= 1) return v.toFixed(2);
  if (v >= 0.1) return v.toFixed(3);
  return v.toFixed(4);
}

// Interactive AU ruler. Two draggable endpoint handles in the orbital
// reference plane (XZ); a glowing spine connects them; an HTML label at
// the midpoint shows the live AU distance.
//
// Default behavior: A locked to host (origin), B locked to focal planet
// (read each frame from focalPosRef). Dragging either handle unlocks it.
// To re-lock, toggle the ruler off and on.
//
// Sizing: handles + spine thickness are scaled per-frame from camera
// distance so they keep a consistent pixel size at every zoom and across
// the 0.05 AU - 100+ AU system-scale range. World-space sizing produced
// huge handles on hot-Jupiter systems and invisible handles on wide-orbit
// debris-disk systems.
//
// State visual encoding:
//   - Locked handle: cyan-green (#7fffd6) — "attached"
//   - Unlocked / freehand: amber (#ffd76e)
//   - Currently dragging: bright yellow (#fff080)
function SystemRuler({
  maxOrbit,
  onDragChange,
  focalPosRef,
}: {
  maxOrbit: number;
  onDragChange?: (dragging: boolean) => void;
  focalPosRef?: React.MutableRefObject<THREE.Vector3>;
}) {
  // Endpoint positions live in refs (not state) so the per-frame lock
  // tracking doesn't trigger React re-renders 60×/sec. Only the values
  // that drive visible state (label text, handle color, dragging flag)
  // go through useState.
  const aRef = useRef<[number, number, number]>([0, 0, 0]);
  // Initialize B to focal planet position on mount (useEffect runs after
  // initial render, by which time focalPosRef.current is set). useFrame
  // then keeps it in sync via the lock loop. Default of [0,0,0] is a
  // fine placeholder for the single render-frame before mount finishes.
  const bRef = useRef<[number, number, number]>([0, 0, 0]);
  useEffect(() => {
    const p = focalPosRef?.current;
    if (p && (p.x !== 0 || p.z !== 0)) bRef.current = [p.x, p.y, p.z];
    else bRef.current = [maxOrbit * 0.5, 0, 0];
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const [lockedA, setLockedA] = useState(true);
  const [lockedB, setLockedB] = useState(true);
  const [dragging, setDragging] = useState<null | 'A' | 'B'>(null);
  // Distance label + midpoint position update at a throttled rate (~10
  // Hz) to avoid 60fps re-renders. Bundled together because they're
  // visually coupled — the label has to track the spine midpoint.
  const [labelInfo, setLabelInfo] = useState<{
    pos: [number, number, number];
    text: string;
  }>({ pos: [0, 0, 0], text: '0 AU' });

  // Bubble drag state up so OrbitControls can be disabled during drag.
  useEffect(() => {
    onDragChange?.(dragging !== null);
  }, [dragging, onDragChange]);

  const meshARef = useRef<THREE.Mesh>(null);
  const meshBRef = useRef<THREE.Mesh>(null);
  const spineRef = useRef<THREE.Mesh>(null);
  const lastLabelUpdate = useRef(0);

  const { camera, gl } = useThree();

  // While a drag is in progress, listen for pointer moves + up directly on
  // the canvas. Bypasses R3F's mesh-routed event system so cursor moves
  // over the host star, planet body, or off-canvas don't intercept the
  // drag — and so pointer-up always fires and clears the drag state
  // (which the camera-disable depends on).
  useEffect(() => {
    if (!dragging) return;
    const canvas = gl.domElement;
    const raycaster = new THREE.Raycaster();
    const ndc = new THREE.Vector2();

    const onMove = (e: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      ndc.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      ndc.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(ndc, camera);
      const ray = raycaster.ray;
      if (Math.abs(ray.direction.y) < 1e-9) return;
      const t = -ray.origin.y / ray.direction.y;
      if (t < 0) return;
      const x = ray.origin.x + t * ray.direction.x;
      const z = ray.origin.z + t * ray.direction.z;
      if (dragging === 'A') aRef.current = [x, 0, z];
      else if (dragging === 'B') bRef.current = [x, 0, z];
    };
    const onUp = () => setDragging(null);

    canvas.addEventListener('pointermove', onMove);
    canvas.addEventListener('pointerup', onUp);
    canvas.addEventListener('pointercancel', onUp);
    return () => {
      canvas.removeEventListener('pointermove', onMove);
      canvas.removeEventListener('pointerup', onUp);
      canvas.removeEventListener('pointercancel', onUp);
    };
  }, [dragging, gl, camera]);

  // Constants
  const SPINE_COLOR = '#fff3d6';
  const HANDLE_COLOR_LOCKED = '#7fffd6';
  const HANDLE_COLOR_IDLE = '#ffd76e';
  const HANDLE_COLOR_DRAG = '#fff080';
  // Handle radius as a fraction of camera distance, so handles stay a
  // consistent on-screen size. ~1.5% of camera distance reads as a
  // grabbable handle at default FOV.
  const HANDLE_SCREEN_FRAC = 0.018;
  // Spine thickness relative to handle radius.
  const SPINE_THICKNESS_FRAC = 0.12;

  function handleColor(side: 'A' | 'B', locked: boolean): string {
    if (dragging === side) return HANDLE_COLOR_DRAG;
    return locked ? HANDLE_COLOR_LOCKED : HANDLE_COLOR_IDLE;
  }

  // Per-frame: update locked endpoints from refs, update handle scales
  // based on camera distance, update spine geometry (position + rotation
  // + scale), and update the distance label at a throttled rate. Endpoint
  // positions and the spine are TRUE 3D so locked-to-planet correctly
  // tracks tilted/obliquity orbits like WASP-107 b. Freehand drags are
  // still Y=0-constrained (the drag raycast hits the orbital plane), so
  // a dragged endpoint snaps back to the reference plane.
  useFrame(() => {
    // Lock tracking — full 3D for the planet so we follow inclined orbits.
    if (lockedA) aRef.current = [0, 0, 0];
    if (lockedB && focalPosRef?.current) {
      const p = focalPosRef.current;
      bRef.current = [p.x, p.y, p.z];
    }

    const a = aRef.current;
    const b = bRef.current;
    const ax = a[0], ay = a[1], az = a[2];
    const bx = b[0], by = b[1], bz = b[2];
    const dx = bx - ax, dy = by - ay, dz = bz - az;
    const length = Math.hypot(dx, dy, dz);

    // Handle positions + screen-space scale
    if (meshARef.current) {
      meshARef.current.position.set(ax, ay, az);
      const dist = camera.position.distanceTo(meshARef.current.position);
      meshARef.current.scale.setScalar(dist * HANDLE_SCREEN_FRAC);
    }
    if (meshBRef.current) {
      meshBRef.current.position.set(bx, by, bz);
      const dist = camera.position.distanceTo(meshBRef.current.position);
      meshBRef.current.scale.setScalar(dist * HANDLE_SCREEN_FRAC);
    }

    // Spine: midpoint, length, orientation in full 3D
    if (spineRef.current && length > 1e-6) {
      const mx = (ax + bx) / 2, my = (ay + by) / 2, mz = (az + bz) / 2;
      spineRef.current.position.set(mx, my, mz);
      // Orient base-+Y cylinder to point along (b - a) in 3D.
      const dir = new THREE.Vector3(dx / length, dy / length, dz / length);
      spineRef.current.quaternion.setFromUnitVectors(
        new THREE.Vector3(0, 1, 0),
        dir,
      );
      // Scale: x/z control radius (screen-space), y controls length
      // (true AU distance).
      const dist = camera.position.distanceTo(spineRef.current.position);
      const radiusScale = dist * HANDLE_SCREEN_FRAC * SPINE_THICKNESS_FRAC;
      spineRef.current.scale.set(radiusScale, length, radiusScale);
      spineRef.current.visible = true;
    } else if (spineRef.current) {
      spineRef.current.visible = false;
    }

    // Throttled label update: every ~100ms is plenty for a readout, and
    // keeps React re-renders to ~10 Hz instead of 60 Hz.
    const now = performance.now();
    if (now - lastLabelUpdate.current > 100) {
      lastLabelUpdate.current = now;
      const mx = (ax + bx) / 2, my = (ay + by) / 2, mz = (az + bz) / 2;
      setLabelInfo({ pos: [mx, my, mz], text: `${formatAU(length)} AU` });
    }
  });

  return (
    <group>
      {/* Spine: cylinder with unit radius + unit length, scaled per-frame
          via the spineRef in useFrame above. */}
      <mesh ref={spineRef}>
        <cylinderGeometry args={[1, 1, 1, 8]} />
        <meshStandardMaterial
          color={SPINE_COLOR}
          emissive={SPINE_COLOR}
          emissiveIntensity={1.4}
          toneMapped={false}
        />
      </mesh>

      {/* Endpoint A handle. Pointer-down kicks off the drag; the canvas-
          level pointermove + pointerup listeners (mounted via useEffect
          while `dragging` is set) drive the actual move and release.
          Putting the listeners on the canvas instead of the mesh means
          cursor moves over other meshes or off-screen don't break the
          drag. */}
      <mesh
        ref={meshARef}
        onPointerDown={(e) => {
          e.stopPropagation();
          setLockedA(false);
          setDragging('A');
        }}
      >
        <sphereGeometry args={[1, 16, 12]} />
        <meshStandardMaterial
          color={handleColor('A', lockedA)}
          emissive={handleColor('A', lockedA)}
          emissiveIntensity={dragging === 'A' ? 2.0 : 1.2}
          toneMapped={false}
        />
      </mesh>

      {/* Endpoint B handle. Identical to A. */}
      <mesh
        ref={meshBRef}
        onPointerDown={(e) => {
          e.stopPropagation();
          setLockedB(false);
          setDragging('B');
        }}
      >
        <sphereGeometry args={[1, 16, 12]} />
        <meshStandardMaterial
          color={handleColor('B', lockedB)}
          emissive={handleColor('B', lockedB)}
          emissiveIntensity={dragging === 'B' ? 2.0 : 1.2}
          toneMapped={false}
        />
      </mesh>

      {/* Live distance label, HTML-overlaid in 3D space. Stays a constant
          CSS pixel size regardless of zoom. Position + text update at the
          throttled rate set inside useFrame. */}
      <Html
        position={labelInfo.pos}
        center
        style={{
          pointerEvents: 'none',
          color: SPINE_COLOR,
          fontSize: '0.85rem',
          fontWeight: 600,
          background: 'rgba(11, 13, 18, 0.7)',
          padding: '2px 6px',
          borderRadius: 3,
          border: `1px solid ${SPINE_COLOR}`,
          whiteSpace: 'nowrap',
          fontFamily: 'monospace',
        }}
      >
        {labelInfo.text}
      </Html>
    </group>
  );
}

// Sets the camera's up vector to the (first inclined) debris-disk's normal
// when toggled on. Effect: looking at the system, the disk appears horizontal
// (perpendicular to "up") and its axis appears vertical on screen. Reverts
// to world +Y up when toggled off so the user can return to the default
// scene orientation without reloading. Lives inside Canvas so it has access
// to useThree() for the camera instance.
function CameraAxisAlignment({
  align, debrisDisks,
}: {
  align: boolean; debrisDisks: FocalDebrisDiskBelt[];
}) {
  const { camera, invalidate } = useThree();
  // Pick the first belt with a measured inclination as the alignment target.
  // For multi-belt systems (51 Eri) inclinations aren't measured anyway, so
  // this consistently picks the inclined belt for HR 8799 / HD 95086 / β Pic.
  const target = debrisDisks.find((b) => b.inclinationDeg != null) ?? null;
  useEffect(() => {
    if (align && target?.inclinationDeg != null) {
      // Disk normal direction (same math as DebrisDiskAxis): (0, cos i, sin i)
      // in world space, with the disk rotation [-π/2 + i, 0, 0] applied to
      // a ringGeometry's natural +Z normal.
      const incRad = (target.inclinationDeg * Math.PI) / 180;
      camera.up.set(0, Math.cos(incRad), Math.sin(incRad));
    } else {
      camera.up.set(0, 1, 0);
    }
    camera.updateMatrixWorld(true);
    invalidate();
  }, [align, target?.inclinationDeg, camera, invalidate]);
  return null;
}

// Axis line perpendicular to a curated debris-disk's plane. The disk's
// rotation is [-PI/2 + incRad, 0, 0] around the X axis (see
// SystemDebrisDiskRing); applying that rotation to the ringGeometry's
// natural +Z normal gives a world-space normal of (0, cos(incRad),
// sin(incRad)), so the axis line extends along ±(0, cos i, sin i) from
// the host. Toggled by the same showStellarReference checkbox as the
// stellar spin axis — both are "reference geometry" overlays.
function DebrisDiskAxis({
  length, inclinationDeg, color = '#a08866',
}: {
  length: number; inclinationDeg: number; color?: string;
}) {
  const incRad = (inclinationDeg * Math.PI) / 180;
  const ny = Math.cos(incRad);
  const nz = Math.sin(incRad);
  const geom = useMemo(() => {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(
      new Float32Array([
        0, -length * ny, -length * nz,
        0,  length * ny,  length * nz,
      ]), 3,
    ));
    return g;
  }, [length, ny, nz]);
  const mat = useMemo(() => new THREE.LineBasicMaterial({
    color, transparent: true, opacity: 0.5, depthWrite: false,
  }), [color]);
  const line = useMemo(() => new THREE.Line(geom, mat), [geom, mat]);
  useEffect(() => () => { geom.dispose(); }, [geom]);
  useEffect(() => () => { mat.dispose(); }, [mat]);
  return <primitive object={line} />;
}

// ── Per-vantage starfield + diffuse galaxy skydome ─────────────────────
// Phase 2/3/4: fetches a server-rendered equirectangular PNG from
// /api/starfield/:plName.png that contains both the per-vantage star
// rasterization (Gaia + procedural Milky Way particles, all in one
// textured layer) and the line-of-sight integrated diffuse galaxy glow
// composited in linear-light space (api/starfield.py:composite_diffuse_onto).
// The frontend just paints it on a camera-following skydome sphere — one
// textured primitive is the only thing the @react-three/xr 6 + Quest 3
// multiview pipeline reliably renders, so all the per-pixel math lives
// server-side. See docs/STARFIELD_PLAN.md for the architectural rationale.

function Starfield({ plName }: { plName: string }) {
  const [texture, setTexture] = useState<THREE.Texture | null>(null);
  const { scene, gl } = useThree();
  const skydomeRef = useRef<THREE.Mesh>(null);

  // Phase 2: fetch the per-vantage starfield PNG from the server. The
  // texture is rendered for THIS specific host system — stars are
  // reprojected from the host's heliocentric ICRS position, so
  // TRAPPIST-1's sky differs from Earth's, OGLE microlensing-bulge
  // worlds get a galactic-center-dominated sky, etc. The server caches
  // by host position (Cache-Control: immutable for a year); the
  // browser caches by URL. Two distinct planets in the same system
  // pull the same PNG bytes from the browser cache.
  //
  // EquirectangularReflectionMapping is set so the texture renders as a
  // proper spherical environment in both the scene.background fallback
  // path and on the skydome mesh — critical for VR (without it, the
  // background renders as a head-locked 2D quad). See the XR gotcha
  // section of docs/PROCEDURAL_RENDERING.md.
  useEffect(() => {
    let cancelled = false;
    const loader = new THREE.TextureLoader();
    const url = `/api/starfield/${encodeURIComponent(plName)}.png`;
    loader.load(
      url,
      (tex) => {
        if (cancelled) { tex.dispose(); return; }
        tex.colorSpace = THREE.SRGBColorSpace;
        tex.mapping = THREE.EquirectangularReflectionMapping;
        // Anisotropic filtering: at glancing angles (near the skydome
        // horizon line, or when looking through the texture at low grazing
        // incidence) the default isotropic mip selection blurs the smaller
        // texels aggressively and pinpoint stars smear into haze. Bumping
        // to the GPU's max anisotropy (typically 16 on Quest 3 and desktop
        // GPUs) tells the sampler to take more samples per fragment along
        // the stretched axis, keeping stars sharp without affecting
        // perpendicular viewing. Practically free at this texture size.
        tex.anisotropy = gl.capabilities.getMaxAnisotropy();
        setTexture(tex);
      },
      undefined,
      () => { /* silent fail — scene still works without stars */ },
    );
    return () => { cancelled = true; };
  }, [plName]);


  // Lock the skydome to the camera every frame. In XR, state.camera does
  // NOT necessarily reflect the headset's live pose — three.js maintains
  // an internal ArrayCamera that's only available via gl.xr.getCamera(),
  // and even then the camera's `.position` field can be stale (its world
  // transform is composed of parent + matrix updates). getWorldPosition()
  // decomposes the matrixWorld so we always get the correct world point.
  //
  // The quaternion.identity() call clamps the mesh's LOCAL rotation only.
  // It does NOT compensate for parent transforms — if <Starfield />'s
  // ancestor chain ever included a rotating group (e.g., it was mounted
  // inside XROrigin and the user snap-turned), the skydome's world
  // rotation would still rotate with the parent. Today the component is
  // a direct child of <XR> with no rotating ancestors, so local-identity
  // is sufficient. Revisit if the scene graph changes.
  useFrame((state) => {
    if (!skydomeRef.current) return;
    const xr = state.gl.xr;
    const cam = (xr && xr.isPresenting) ? xr.getCamera() : state.camera;
    cam.getWorldPosition(skydomeRef.current.position);
    skydomeRef.current.quaternion.identity();
  });

  // scene.background fallback + GPU texture lifecycle. Combined into one
  // effect so the cleanup order is guaranteed: unassign first, dispose
  // second. (Disposing a texture that's still bound to a render target
  // asserts in three.js debug builds.)
  //
  // Why the fallback exists: scene.background renders in three.js's
  // dedicated background pass BEFORE any scene meshes. The skydome mesh
  // below renders afterward and overwrites the background wherever it
  // draws. If the mesh fails to render for any reason (some XR pipelines
  // silently drop large meshes), the background still shows so the user
  // sees a proper sky instead of empty space. renderOrder:-1 and
  // depthTest:false on the skydome control mesh-vs-mesh ordering, NOT
  // mesh-vs-background ordering.
  //
  // Why disposal matters: the Canvas re-mounts on viewMode change (system
  // ↔ surface) via key={viewMode} on the parent — a new CanvasTexture
  // (~72MB at 6144×3072 RGB, ~96MB once mipmaps generate) allocates
  // each mount. Without dispose, GPU memory leaks per toggle.
  useEffect(() => {
    if (!texture) return;
    const previous = scene.background;
    scene.background = texture;
    return () => {
      scene.background = previous;
      texture.dispose();
    };
  }, [texture, scene]);

  if (!texture) return null;

  // Method A: explicit skydome mesh, camera-following. depthTest:false
  // means it always draws first as background; depthWrite:false keeps
  // it from occluding planets, sun, etc.
  // Radius is STAR_SPHERE_AU (5000) — at this size the mesh is known to
  // render in VR. At 1e6 it silently failed on Quest, likely because the
  // XR session's actual depth-far is clamped well below the 1e9 we
  // requested via updateRenderState. Camera-follow eliminates parallax.
  // side: DoubleSide as a defensive choice for XR multiview face-culling
  // quirks. Negligible perf cost for a single 64×32 sphere.
  return (
    <mesh ref={skydomeRef} frustumCulled={false} renderOrder={-1}>
      <sphereGeometry args={[STAR_SPHERE_AU, 64, 32]} />
      <meshBasicMaterial
        map={texture}
        side={THREE.DoubleSide}
        toneMapped={false}
        depthWrite={false}
        depthTest={false}
      />
    </mesh>
  );
}

// Median effective temperature for a spectral class — feeds the Photosphere
// shader's HDR ramp so a K-companion glows orange-yellow, an M-companion red,
// a T brown dwarf deep crimson, etc. Falls back to Sun-like 5778 K.
function estimateStarTeff(spectype: string | null): number {
  if (!spectype) return 5778;
  const letter = spectype.trim().charAt(0).toUpperCase();
  switch (letter) {
    case 'O': return 35000;
    case 'B': return 18000;
    case 'A': return 8500;
    case 'F': return 6700;
    case 'G': return 5800;
    case 'K': return 4500;
    case 'M': return 3200;
    case 'L': return 1800;
    case 'T': return 1000;
    case 'Y': return 500;
    case 'D': return 20000;   // typical white dwarf
    default:  return 5778;
  }
}

function PlanetBody({
  position,
  radius,
  pl_eqt,
  pl_dens,
  pl_rade,
  emphasized,
  name,
  onHover,
  onClick,
  atmosphereTint,
  rotationOmegaRad,
  phaseCurve,
  albedo,
  reflectionTint,
  effectiveTempK,
}: {
  position: [number, number, number];
  radius: number;
  pl_eqt: number | null;
  pl_dens: number | null;
  pl_rade: number | null;
  /** Curated effective temperature (K), used as a color-stop fallback
      when pl_eqt is null. Applies to self-luminous directly-imaged
      planets — see focalEffectiveTeff() in this file. */
  effectiveTempK?: number | null;
  emphasized?: boolean;
  name?: string;
  onHover?: (n: string | null) => void;
  onClick?: () => void;
  /** When provided, overrides the default atmospheric haze color for gas
      giants. Driven by curated molecule detections — methane → blue,
      water → pale blue, CO2 → tan, etc. Only meaningful for the focal planet
      (siblings don't get per-planet atmosphere data fetched). */
  atmosphereTint?: string;
  /** Visible axial spin rate in rad/sec (stylized from real rotation_velocity).
      When provided, the planet body + atmosphere rotate about +Y, the same
      reference axis the obliquity tilt uses. The hit mesh stays still (it is
      sphere-symmetric anyway and rotating it would only complicate pointer
      events). +Y is a convention; planetary spin-axis orientation is not
      generally measured for exoplanets. */
  rotationOmegaRad?: number | null;
  /** Measured day/night thermal-emission colors. When provided, the shader
      switches to thermal-blend lighting (hot dayside, dim nightside) instead
      of the reflective sun-direction default. Driven by curated dayside_/
      nightside_temperature from phase-curve papers. */
  phaseCurve?: PhaseCurve | null;
  /** Measured geometric or Bond albedo (0-1 fraction). Modulates reflected-
      light brightness in the reflective lighting mode only — the phase-curve
      path is unaffected because those planets are thermal-emission dominated.
      Default 0.30 (reference albedo, factor = 1.0). */
  albedo?: number | null;
  /** Hex color tint applied to reflected starlight for planets with
      wavelength-dependent albedo (currently HD 189733 b, "deep cobalt blue").
      Null leaves the body color unmixed. */
  reflectionTint?: string | null;
}) {
  const visual = useMemo(
    () => planetVisual(pl_eqt, pl_dens, pl_rade, effectiveTempK ?? null),
    [pl_eqt, pl_dens, pl_rade, effectiveTempK]
  );
  const isGasGiant = visual.bodyType === 'gas_giant';
  const isIcyOrCold = visual.bodyType === 'rocky' && (pl_eqt ?? 999) < 273;
  // Hit-mesh: invisible larger sphere for generous click/hover targeting.
  const hitRadius = Math.max(radius * 2.5, radius + 0.005);

  const spinGroup = useRef<THREE.Group>(null);
  useFrame((state) => {
    if (spinGroup.current && rotationOmegaRad && rotationOmegaRad > 0) {
      spinGroup.current.rotation.y = state.clock.getElapsedTime() * rotationOmegaRad;
    }
  });

  // Procedural body material: gas giants get faint latitude bands; cold rocky
  // planets get polar ice caps; everything else stays flat-color (with
  // emissive for hot lava worlds). Albedo + reflectionTint modulate the
  // reflective lighting path (thermal phase-curve mode is unaffected).
  // Spin texture: object-space cloud-patch noise that visibly rotates
  // with the planet body. Gated on rotationOmegaRad being curated and
  // non-zero — without that signal there's no spin to visualize, and
  // we don't want to slap procedural patches on planets where the
  // rotation rate hasn't been measured. Phase-curve planets (hot
  // Jupiters with dayside/nightside maps) are excluded because their
  // shader is in emission-dominated thermal mode where the noise would
  // fight the day/night gradient.
  const showSpinTexture =
    rotationOmegaRad != null && rotationOmegaRad !== 0 && !phaseCurve;

  const bodyMaterial = useMemo(
    () => buildPlanetBodyMaterial({
      bodyType: visual.bodyType,
      fillColor: visual.fillColor,
      glow: visual.glow,
      isCold: isIcyOrCold,
      phaseCurve: phaseCurve ?? null,
      albedo: albedo ?? null,
      reflectionTint: reflectionTint ?? null,
      showSpinTexture,
    }),
    [visual.bodyType, visual.fillColor, visual.glow, isIcyOrCold, phaseCurve, albedo, reflectionTint, showSpinTexture],
  );

  return (
    <group position={position}>
      {/* Hit mesh. Was visible={false} for "invisible" behavior, but R3F's
          XR controller ray pointer skips invisible meshes for pointer
          events on Quest — so VR clicks never registered. A transparent
          material that draws nothing (opacity 0, no depth write) still
          gets raycast hits because the mesh is actually visible to
          three.js's traversal. Same effect on desktop. */}
      <mesh
        onPointerOver={(e) => { e.stopPropagation(); if (name && onHover) onHover(name); document.body.style.cursor = onClick ? 'pointer' : 'default'; }}
        onPointerOut={(e) => { e.stopPropagation(); if (onHover) onHover(null); document.body.style.cursor = 'default'; }}
        onClick={(e) => { if (onClick) { e.stopPropagation(); onClick(); } }}
      >
        <sphereGeometry args={[hitRadius, 8, 8]} />
        <meshBasicMaterial transparent opacity={0} depthWrite={false} />
      </mesh>
      {/* Body + atmosphere co-rotate about +Y when an axial spin rate is set.
          The body shader's noise samples object-space position, so rotating
          the mesh visibly rotates the surface pattern. The atmosphere is
          sphere-symmetric (Fresnel-only), unaffected by the rotation but
          kept inside the spin group so it always tracks the body cleanly. */}
      <group ref={spinGroup}>
        <mesh material={bodyMaterial}>
          <sphereGeometry args={[radius, emphasized ? 128 : 64, emphasized ? 128 : 64]} />
        </mesh>
        {isGasGiant && (
          <PlanetAtmosphere
            radius={radius * 1.08}
            color={atmosphereTint ?? visual.fillColor}
          />
        )}
      </group>
      {/* Note: the circumplanetary disk is rendered by the *parent* group
          (SceneContents) as a sibling of PlanetBody, NOT inside this
          component. That way it stays visible in surface mode (where we
          hide the planet body because the camera is standing on it) —
          you should still see the dust stretching across the sky when
          you're inside the disc. */}
    </group>
  );
}

// Circumplanetary disk ring. Flat dust ring around a forming planet, lying
// in the orbital plane (XZ in our scene since the orbit is in XZ by default).
// Inner edge sits just outside the planet body so it reads as separate from
// the planet's atmosphere; outer edge extends ~4× planet radius. Alpha tapers
// at both edges so the disc fades into space rather than terminating sharply.
// Currently only renders for PDS 70 b and c (the only systems with curated
// circumplanetary_disk_dust_mass / accretion_rate measurements); future
// curation of debris-disk extents would let bet Pic, HR 8799, etc. carry
// system-level rings via a separate component.
function CircumplanetaryDiskRing({ planetRadius }: { planetRadius: number }) {
  // Inner radius is INSIDE the planet body, so the planet's own depth mask
  // hides the geometric inner edge — the visible inner boundary becomes the
  // alpha gradient instead of a hard ring. Outer extends well past the
  // visible cutoff so the shader fades to zero before any geometric edge
  // would show.
  const innerRadius = planetRadius * 0.5;
  const outerRadius = planetRadius * 5.0;

  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color('#b08868') }, // dusty brown
    },
    vertexShader: `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform vec3 uColor;
      varying vec2 vUv;

      // 2D value noise for dust granularity.
      float hash2(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
      }
      float noise2(vec2 p) {
        vec2 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(
          mix(hash2(i),                hash2(i + vec2(1, 0)), f.x),
          mix(hash2(i + vec2(0, 1)),   hash2(i + vec2(1, 1)), f.x),
          f.y);
      }

      void main() {
        // Envelope: smooth fade-in at the inner edge (across the first 35%
        // of the radial range — well past the planet's silhouette at uv.y
        // ~0.11 — so the disc has no brightness step where it emerges from
        // behind the planet body) combined with a gentle outward decay AND
        // an explicit outer-edge fade-out so the dust tapers softly into
        // space instead of cutting off at the ring's geometric edge.
        float r = vUv.y;
        float fadeIn  = smoothstep(0.0, 0.35, r);
        float fadeOut = 1.0 - smoothstep(0.65, 1.0, r);
        float decay   = pow(1.0 - r * 0.6, 1.1);
        float envelope = fadeIn * fadeOut * decay;

        // Multi-octave noise so the dust reads as clumpy material with
        // structure on multiple scales — not a uniformly-painted decal.
        vec2 c = vUv * 2.0 - 1.0;
        float ang = atan(c.y, c.x);
        float n1 = noise2(vec2(r * 10.0,  ang * 4.0));
        float n2 = noise2(vec2(r * 24.0,  ang * 11.0));
        float n3 = noise2(vec2(r * 55.0,  ang * 24.0));
        float dust = 0.25 + 0.40 * n1 + 0.25 * n2 + 0.15 * n3;

        // Faint radial banding so the disc has visible structure (dust
        // lanes / gaps) rather than a continuous gradient.
        float bands = 0.75 + 0.25 * sin(r * 22.0 + n1 * 3.0);

        // Per-layer intensity dropped to 0.04 because we stack 25 layers
        // via NormalBlending (1 - (1-0.04*peak)^25 ≈ 0.45 at full overlap).
        // At the silhouette where only a few layers contribute, alpha is
        // ~0.04-0.10 giving a truly soft edge — same approach as the
        // system-level debris disks.
        float intensity = envelope * dust * bands * 0.04;
        intensity = clamp(intensity, 0.0, 0.08);

        gl_FragColor = vec4(uColor, intensity);
      }
    `,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    blending: THREE.NormalBlending,
    side: THREE.DoubleSide,
  }), []);

  // 25 stacked rings along +Y (disk normal — CPD sits flat in XZ with no
  // inclination data). Thickness = 5% of the radial width so the layers
  // pack densely enough to read as a continuous 3D thickness rather than
  // discrete rings. Same trick as SystemDebrisDiskRing — softens the
  // silhouette at the projected ellipse's minor-axis ends when viewed at
  // any angle.
  const N_LAYERS = 25;
  const totalThickness = (outerRadius - innerRadius) * 0.05;
  const layerStep = totalThickness / (N_LAYERS - 1);
  return (
    <group>
      {Array.from({ length: N_LAYERS }, (_, i) => {
        const offset = -totalThickness / 2 + i * layerStep;
        return (
          <mesh
            key={i}
            material={material}
            position={[0, offset, 0]}
            rotation={[-Math.PI / 2, 0, 0]}
          >
            <ringGeometry args={[innerRadius, outerRadius, 256]} />
          </mesh>
        );
      })}
    </group>
  );
}

// System-level debris disk ring around the host star. Renders one curated
// belt as a wide flat ring in the XZ plane (the orbital reference plane),
// centered on the host (origin) — distinct from CircumplanetaryDiskRing
// which sits around a single forming planet at planet-radii scale. AU
// scale: the inner/outer radii are real AU values, so visible to the same
// camera that views the planet orbits.
//
// For belts with a single-radius SED fit (51 Eri warm/cold), outerAu is
// null and the renderer draws a narrow ring (width = ~20% of innerAu)
// centered on innerAu — honest about the lack of a resolved-imaging
// outer edge.
//
// Inclination tilts the disk plane: 0° = coplanar with orbit (face-on in
// the default scene), 90° = edge-on. When inclinationDeg is null we render
// coplanar with the focal orbit plane (no extra tilt).
function SystemDebrisDiskRing({ belt }: { belt: FocalDebrisDiskBelt }) {
  // Single-radius SED fits (51 Eri belts): render as a narrow ring
  // (width = 20% of inner radius) centered on the blackbody radius.
  //
  // Resolved-imaging belts (β Pic, HR 8799, HD 95086, ε Eri): geometric
  // ring extends 5% inside the cited inner edge and 40% past the cited
  // outer edge. The cited bounds become "this is where the parent-body
  // belt is" and the halo extension represents the small-grain dust
  // pushed outward by stellar radiation pressure — Booth 2016's HR 8799
  // paper explicitly describes this "halo of small grains" beyond the
  // parent belt. Brightness peaks at the inner edge and tapers
  // continuously to zero at the geometric outer, so the visible ring
  // never has a hard cutoff at the cited boundary.
  const isSingleRadius = belt.outerAu == null;
  // Geometry extends WELL inward of cited bounds so the inner fade-in spans
  // many AU and reads as a visibly gradual gradient.
  //
  // Broad belt (resolved imaging): inner = citedInner * 0.65 (35% inward),
  //   outer = citedOuter * 1.1 (10% outward). For HD 95086 this gives a
  //   ~37 AU inner fade region before reaching the cited inner.
  //
  // Single-radius SED fit (51 Eri warm at 5.5 AU, cold at 82 AU): the cited
  //   "radius" is a single blackbody-fit value, not a measured ring extent.
  //   The geometric ring is widened to inner = innerAu * 0.5 and outer =
  //   innerAu * 1.5, giving the bell curve a radial range equal to the
  //   cited radius itself — enough for the stacked-ring thickness effect
  //   to register visibly (otherwise the 5%-of-width thickness collapses
  //   to near-zero AU for small cited radii like the 5.5 AU warm belt).
  const inner = isSingleRadius ? belt.innerAu * 0.5 : belt.innerAu * 0.65;
  const outer = isSingleRadius
    ? belt.innerAu * 1.5
    : (belt.outerAu ?? belt.innerAu * 1.1) * 1.1;

  const material = useMemo(() => {
    return new THREE.ShaderMaterial({
    uniforms: {
      // Per-belt color from curated dust temperature (migration 091 — see
      // dustColorHex). Belts without a temperature row fall back to the
      // legacy generic dust brown so existing visuals don't change for
      // belts where temperature isn't measured (eps Eri b).
      uColor: { value: new THREE.Color(dustColorHex(belt.dustTemperatureK)) },
      uIsSingleRadius: { value: isSingleRadius ? 1.0 : 0.0 },
    },
    vertexShader: `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform vec3 uColor;
      uniform float uIsSingleRadius;
      varying vec2 vUv;

      float hash2(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
      }
      float noise2(vec2 p) {
        vec2 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(
          mix(hash2(i),              hash2(i + vec2(1, 0)), f.x),
          mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x),
          f.y);
      }

      void main() {
        float r = vUv.y;   // 0 at geometric inner, 1 at geometric outer
        float envelope;
        if (uIsSingleRadius > 0.5) {
          // Narrow ring case: peak at r=0.5, fade to edges. This is the
          // honest visual for SED-fit single-radius belts (51 Eri).
          envelope = smoothstep(0.0, 0.40, r) * (1.0 - smoothstep(0.60, 1.0, r));
        } else {
          // Soft cloud with SQUARED envelope for much more gradual edges.
          // The bell-curve smoothstep already produces a smooth fade, but
          // its rise is "fast" near the edges — alpha hits ~5% (perceptual
          // visibility threshold) at r ~ 0.1, which the eye reads as a
          // defined boundary. Squaring the envelope pushes that visibility
          // threshold out to r ~ 0.3, giving the inner fade THREE TIMES as
          // much radial space to read as gradient before it becomes
          // visible. Peak (r=0.5) stays at 1.0 so the central disk reads
          // at the same brightness as before.
          float fadeIn  = smoothstep(0.0, 0.5, r);
          float fadeOut = 1.0 - smoothstep(0.5, 1.0, r);
          envelope = fadeIn * fadeOut;
          envelope = envelope * envelope;
        }

        // Dust noise + bands restored — multi-octave value noise gives the
        // disk visible clumpy structure (matching ALMA mm-grain imagery),
        // multiplied by the bell-curve envelope so it fades to invisible
        // at both geometric ring boundaries.
        vec2 c = vUv * 2.0 - 1.0;
        float ang = atan(c.y, c.x);
        float n1 = noise2(vec2(r * 8.0,  ang * 3.0));
        float n2 = noise2(vec2(r * 20.0, ang * 8.0));
        float n3 = noise2(vec2(r * 48.0, ang * 18.0));
        float dust = 0.30 + 0.40 * n1 + 0.20 * n2 + 0.10 * n3;
        float bands = 0.88 + 0.12 * sin(r * 18.0 + n1 * 2.5);
        // Per-layer intensity dropped to 0.025 because 25 layers are
        // stacked via NormalBlending. At full overlap: composited alpha
        // = 1 - (1 - 0.025*peak)^25 ≈ 0.30, similar to the original
        // single-layer peak. At the silhouette (where only 1-3 layers
        // overlap due to perspective), composited alpha is ~0.04-0.10,
        // giving a true gradient silhouette instead of a hard edge.
        float intensity = envelope * dust * bands * 0.025;
        intensity = clamp(intensity, 0.0, 0.05);
        gl_FragColor = vec4(uColor, intensity);
      }
    `,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    // NormalBlending (vs the previous AdditiveBlending) so soft
    // mathematical fade-outs at the inner/outer edges read as truly
    // transparent regions, not faintly-additive brown tinting the
    // dark space. The "hard edge" perception was an artifact of
    // additive blending against pure black; normal alpha blending
    // makes low-alpha pixels show the background through cleanly.
    blending: THREE.NormalBlending,
    side: THREE.DoubleSide,
    });
  }, [isSingleRadius, belt.dustTemperatureK]);

  // Disk inclination: rotate the ring around +X axis by inclination degrees.
  // The disk plane (XZ after the -π/2 rotation) is perpendicular to a normal
  // vector that's at angle incRad from +Y. Stacking multiple rings along
  // this normal gives the disk genuine 3D vertical thickness, which softens
  // the silhouette at the projected ellipse's minor-axis ends — those
  // points get more screen pixels for the alpha to fade through, instead of
  // the flat-ring case where the radial direction collapses there.
  const incRad = belt.inclinationDeg != null
    ? (belt.inclinationDeg * Math.PI) / 180
    : 0;
  // Disk normal direction in world frame: (0, cos i, sin i). Each stacked
  // ring is offset along this direction.
  const ny = Math.cos(incRad);
  const nz = Math.sin(incRad);
  // Total vertical thickness = 5% of the radial width. Spread across MANY
  // layers (25) tightly packed so adjacent rings overlap visually and the
  // discrete bands of the previous 7-layer attempt become a continuous
  // gradient. For HD 95086 (cited width 214 AU): 11 AU total thickness,
  // ~0.5 AU layer spacing — well below visual sampling threshold at any
  // realistic zoom.
  const N_LAYERS = 25;
  const totalThickness = (outer - inner) * 0.05;
  const layerStep = totalThickness / (N_LAYERS - 1);
  return (
    <group>
      {Array.from({ length: N_LAYERS }, (_, i) => {
        const offset = -totalThickness / 2 + i * layerStep;
        return (
          <mesh
            key={i}
            material={material}
            position={[0, offset * ny, offset * nz]}
            rotation={[-Math.PI / 2 + incRad, 0, 0]}
          >
            <ringGeometry args={[inner, outer, 256]} />
          </mesh>
        );
      })}
    </group>
  );
}

// Escaping-atmosphere tail. A flat plane lying in the orbital plane (XZ in
// the local frame), starting at the planet body and stretching along local +X.
// The wrapper group sets position to focal-planet world coords and rotates so
// local +X points along the orbital tangent (trailing for normal escape,
// leading for HAT-P-67 b's pre-transit helium tail).
//
// Length scales with log10(mass_loss_rate), spreading the 4-orders-of-
// magnitude range (0.0016 → 105.7 M_earth/Gyr) across a visually-readable
// 6-50 planet-radii window. Width tapers from ~2 R_p at the body to ~6 R_p
// at the far end (comet-style flare). Color is set by escape mechanism:
// hydrogen Lyman-alpha tracers read blue, helium 1083 nm metastable tracers
// read pink/red, Kepler-1520 b dust reads warm gray-brown.
function EscapingAtmosphereTail({
  planetRadius, mechanism, logMassLoss, maxLength,
  orbsmax, eccen, argPeri, inc, omega,
  leading, clockRef, focalSecsPerOrbit,
}: {
  planetRadius: number;
  mechanism: EscapeMechanism;
  logMassLoss: number;
  maxLength: number;
  orbsmax: number;
  eccen: number;
  argPeri: number;
  inc: number;
  omega: number;
  leading: boolean;
  clockRef: React.MutableRefObject<number>;
  focalSecsPerOrbit: number;
}) {
  const N = 32;
  const lengthRp = Math.min(50, Math.max(5, 5 + 8 * (logMassLoss + 3)));
  // Length is capped to a fraction of orbsmax so close-in giants don't blow
  // out (planetRadius * 50 can be many orbits long for HAT-P-67 b-class).
  const length = Math.min(planetRadius * lengthRp, maxLength);
  // The tail covers Δ_M ≈ length / orbsmax radians of mean anomaly along the
  // orbit. Close enough for visual purposes; eccentricity warps the mapping
  // but our 30%-of-orbsmax cap keeps it in the small-arc regime.
  const deltaM = length / orbsmax;
  // Where does the planet body sit along the tail length? Used by the
  // shader's fade-in so the head doesn't punch through the silhouette.
  const bodyFrac = planetRadius / length;
  // Ribbon width: tip is wider than head (escaping gas diffuses with
  // distance), capped at planetRadius units that scale with length so
  // short tails aren't disproportionately fat.
  const baseHalfWidth = Math.min(planetRadius * 0.8, length * 0.04);
  const tipHalfWidth  = Math.min(planetRadius * 2.5, length * 0.10);

  const colorHex = mechanism === 'hydrogen' ? '#4a8fcf'
                 : mechanism === 'helium'   ? '#e57c8c'
                                            : '#b08868';

  // Orbital plane normal — perpendicular to the orbital plane in scene frame.
  // Derived from the same inc/omega convention as applyOrbitTilt: Y in source
  // orbit frame maps to (-sin Ω sin i, -cos i, -cos Ω sin i) after Ry(Ω)·Rx(i).
  // Sign doesn't matter — we only use it to get an in-plane perpendicular via
  // cross(tangent, normal), and either sign gives a valid side direction.
  const orbitNormal = useMemo(() => {
    const sI = Math.sin(inc), cI = Math.cos(inc);
    const sO = Math.sin(omega), cO = Math.cos(omega);
    return new THREE.Vector3(-sO * sI, -cI, -cO * sI).normalize();
  }, [inc, omega]);

  // Ribbon BufferGeometry: (N+1) spine points × 2 vertices = 2(N+1) vertices,
  // 2N triangles. UVs and index buffer are static — only positions get
  // recomputed each frame as the planet's M advances. Allocated once via
  // useMemo, mutated in-place in useFrame to avoid per-frame GC.
  const geometry = useMemo(() => {
    const g = new THREE.BufferGeometry();
    const positions = new Float32Array((N + 1) * 2 * 3);
    const uvs = new Float32Array((N + 1) * 2 * 2);
    const indices = new Uint16Array(N * 2 * 3);
    for (let i = 0; i <= N; i++) {
      const u = i / N;
      uvs[i * 4 + 0] = u; uvs[i * 4 + 1] = 0;
      uvs[i * 4 + 2] = u; uvs[i * 4 + 3] = 1;
    }
    for (let i = 0; i < N; i++) {
      const a = i * 2, b = i * 2 + 1, c = (i + 1) * 2, d = (i + 1) * 2 + 1;
      const off = i * 6;
      indices[off + 0] = a; indices[off + 1] = c; indices[off + 2] = b;
      indices[off + 3] = b; indices[off + 4] = c; indices[off + 5] = d;
    }
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    g.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
    g.setIndex(new THREE.BufferAttribute(indices, 1));
    g.boundingSphere = new THREE.Sphere(new THREE.Vector3(), length * 2);
    return g;
  }, [length]);

  // Recompute spine positions every frame so the ribbon tracks the planet's
  // M as the orbit advances. The parent tailGroup is positioned at the focal
  // planet (sample 0 in world frame), so each vertex is written in LOCAL
  // coords as (sample_i_world − sample_0_world).
  const tmpSpine = useMemo(() => Array.from({ length: N + 1 }, () => new THREE.Vector3()), []);
  const tmpTangent = useMemo(() => new THREE.Vector3(), []);
  const tmpSide = useMemo(() => new THREE.Vector3(), []);
  useFrame(() => {
    const M0 = (clockRef.current / focalSecsPerOrbit) * 2 * Math.PI;
    const dirSign = leading ? 1 : -1;
    // Sample world positions along the orbit.
    for (let i = 0; i <= N; i++) {
      const t = i / N;
      const M_i = M0 + dirSign * t * deltaM;
      const [x0r, , z0r] = keplerPosition(orbsmax, eccen, M_i);
      const [x0, z0] = rotateInPlane(x0r, z0r, argPeri);
      const [x, y, z] = applyOrbitTilt(x0, z0, inc, omega);
      tmpSpine[i].set(x, y, z);
    }
    // For leading tails (HAT-P-67 b): shift the head toward the L1 Lagrange
    // point (star-facing side of the planet) so the visible source isn't the
    // planet's center. The offset fades to zero by t≈0.2 so the rest of the
    // tail still sits on the orbit ring. Physically the L1 point is between
    // the planet center and the star; once material crosses L1 it drops into
    // a closer, faster orbit and pulls ahead of the planet — this offset
    // makes the "escaping toward the star, then leading" story readable
    // without changing the curve.
    const sample0 = tmpSpine[0];
    let l1x = 0, l1y = 0, l1z = 0;
    if (leading) {
      const r = Math.hypot(sample0.x, sample0.y, sample0.z);
      if (r > 1e-9) {
        const k = (planetRadius * 0.8) / r;
        l1x = -sample0.x * k;
        l1y = -sample0.y * k;
        l1z = -sample0.z * k;
      }
    }
    const positions = geometry.attributes.position.array as Float32Array;
    for (let i = 0; i <= N; i++) {
      const t = i / N;
      // Tangent via finite difference along the spine.
      const prev = tmpSpine[Math.max(0, i - 1)];
      const next = tmpSpine[Math.min(N, i + 1)];
      tmpTangent.subVectors(next, prev).normalize();
      // Side = perpendicular to tangent, in the orbital plane.
      tmpSide.crossVectors(tmpTangent, orbitNormal).normalize();
      const halfW = baseHalfWidth + (tipHalfWidth - baseHalfWidth) * t;
      // L1-offset weight: 1 at the head, 0 by t≈0.2.
      const headLerp = Math.max(0, 1 - t * 5);
      const px = tmpSpine[i].x - sample0.x + l1x * headLerp;
      const py = tmpSpine[i].y - sample0.y + l1y * headLerp;
      const pz = tmpSpine[i].z - sample0.z + l1z * headLerp;
      const off = i * 6;
      positions[off + 0] = px - halfW * tmpSide.x;
      positions[off + 1] = py - halfW * tmpSide.y;
      positions[off + 2] = pz - halfW * tmpSide.z;
      positions[off + 3] = px + halfW * tmpSide.x;
      positions[off + 4] = py + halfW * tmpSide.y;
      positions[off + 5] = pz + halfW * tmpSide.z;
    }
    geometry.attributes.position.needsUpdate = true;
  });

  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(colorHex) },
      uBodyFrac: { value: bodyFrac },
    },
    vertexShader: `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform vec3 uColor;
      uniform float uBodyFrac;
      varying vec2 vUv;

      float hash2(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
      }
      float noise2(vec2 p) {
        vec2 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(
          mix(hash2(i),              hash2(i + vec2(1, 0)), f.x),
          mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x),
          f.y);
      }

      void main() {
        // vUv.x: 0 at planet → 1 at tip. vUv.y: 0..1 across the ribbon.
        float u = vUv.x;
        float v = vUv.y - 0.5;

        // Hide the region inside the planet silhouette, then ramp up.
        float fadeIn = smoothstep(uBodyFrac * 0.5, uBodyFrac * 1.4, u);
        // Soft tip cutoff so the geometric end of the ribbon doesn't show.
        float tipFade = 1.0 - smoothstep(0.75, 1.0, u);
        // Exponential density falloff from the head.
        float distFromHead = max(0.0, u - uBodyFrac * 1.4);
        float density = exp(-distFromHead * 3.0);
        // Tight gaussian lateral so the ribbon's bounding rectangle stays
        // out of the visible envelope.
        float widthFrac = 0.30 + 0.10 * u;
        float lateral = exp(-pow(v / widthFrac, 2.0) * 3.5);
        // Multi-octave wisp to break up the solid look.
        vec2 q = vec2(u * 6.0, v * 5.0 + u * 2.0);
        float n1 = noise2(q);
        float n2 = noise2(q * 2.7);
        float n3 = noise2(q * 6.3);
        float wisp = 0.25 + 0.45 * n1 + 0.20 * n2 + 0.10 * n3;
        float intensity = fadeIn * tipFade * density * lateral * wisp * 1.4;
        intensity = clamp(intensity, 0.0, 0.95);
        gl_FragColor = vec4(uColor, intensity);
      }
    `,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    blending: THREE.AdditiveBlending,
    side: THREE.DoubleSide,
  }), [colorHex, bodyFrac]);

  return <mesh geometry={geometry} material={material} />;
}

// Shared cache so the same (bodyType, fillColor, ...) doesn't allocate a new
// material per render. Each unique tuple gets one ShaderMaterial.
const planetMaterialCache = new Map<string, THREE.ShaderMaterial>();

function buildPlanetBodyMaterial({
  bodyType, fillColor, glow, isCold, phaseCurve, albedo, reflectionTint,
  showSpinTexture = false,
}: {
  bodyType: string; fillColor: string; glow: boolean; isCold: boolean;
  phaseCurve?: PhaseCurve | null;
  albedo?: number | null;
  reflectionTint?: string | null;
  /** When true, add procedural object-space noise to the surface so the
      planet's spin is visually apparent as patches move across the
      visible disc. Intended for planets where the curated rotation rate
      (rotationOmegaRad) is set — without surface variation the
      symmetric-around-spin-axis lighting hides the rotation entirely.
      Defensible for L-dwarf / hot directly-imaged objects (AB Pic b,
      β Pic b, HR 8799 family, etc.) whose atmospheres have patchy
      silicate + iron cloud decks; the same pattern reads as Jupiter-
      like mottling on cooler gas giants. */
  showSpinTexture?: boolean;
}): THREE.ShaderMaterial {
  // Cache key includes phase-curve color fingerprints so phase-curve planets
  // get their own material rather than sharing with non-phase-curve planets
  // that happen to match on body type / color / glow / isCold. Albedo +
  // reflectionTint also fingerprinted so curated planets don't share material
  // with their visual twins.
  const phaseKey = phaseCurve
    ? `|p:${phaseCurve.dayside.getHexString()}-${phaseCurve.nightside.getHexString()}`
    : '';
  // Quantize albedo to 2 decimal places for the cache key — avoids fragmenting
  // the cache on floating-point precision noise.
  const albedoKey = albedo != null ? `|a:${albedo.toFixed(2)}` : '';
  const tintKey = reflectionTint ? `|t:${reflectionTint}` : '';
  const spinKey = showSpinTexture ? '|s' : '';
  const key = `${bodyType}|${fillColor}|${glow}|${isCold}${phaseKey}${albedoKey}${tintKey}${spinKey}`;
  const cached = planetMaterialCache.get(key);
  if (cached) return cached;

  const isGasGiant = bodyType === 'gas_giant';
  const showIceCaps = bodyType === 'rocky' && isCold;
  const hasPhaseCurve = phaseCurve != null;

  // Albedo factor: measured / reference (0.30). Default 1.0 when unmeasured
  // so existing rendering is unchanged. No min floor — TrES-2 b (A_g ~ 0.025
  // → factor 0.083) is the darkest exoplanet known and should read very
  // dark; the ambient term in the shader also scales with this factor so
  // dark planets don't carry a constant brightness floor.
  const albedoFactor = albedo != null ? albedo / 0.30 : 1.0;
  // Tint is a direct color mix into the body color (NOT multiplied — that
  // would zero out non-overlapping channels). HD 189733 b uses a saturated
  // deep cobalt so the blue reads through even on the planet's underlying
  // warm-ish hot-Jupiter base color.
  const tintColor = reflectionTint ? new THREE.Color(reflectionTint) : new THREE.Color(1, 1, 1);
  const tintStrength = reflectionTint ? 0.85 : 0.0;

  const mat = new THREE.ShaderMaterial({
    transparent: false,
    depthWrite: true,
    depthTest: true,
    defines: { USE_LOGDEPTHBUF: '' },
    uniforms: {
      uColor:           { value: new THREE.Color(fillColor) },
      uEmissive:        { value: glow ? 0.15 : 0.0 },
      uShowBands:       { value: isGasGiant ? 1.0 : 0.0 },
      uShowIceCaps:     { value: showIceCaps ? 1.0 : 0.0 },
      uHasPhaseCurve:   { value: hasPhaseCurve ? 1.0 : 0.0 },
      uDaysideColor:    { value: (phaseCurve?.dayside ?? new THREE.Color(0, 0, 0)).clone() },
      uNightsideColor:  { value: (phaseCurve?.nightside ?? new THREE.Color(0, 0, 0)).clone() },
      uAlbedoFactor:    { value: albedoFactor },
      uReflectionTint:  { value: tintColor },
      uTintStrength:    { value: tintStrength },
      uShowSpinTexture: { value: showSpinTexture ? 1.0 : 0.0 },
    },
    vertexShader: `
      #include <common>
      #include <logdepthbuf_pars_vertex>
      varying vec3 vNormal;
      varying vec3 vWorldPos;
      varying vec3 vObjectNormal;
      void main() {
        // World-space normal — must match the world-space lightDir below
        // (sun-at-origin). Using view-space normalMatrix here would mix
        // coord spaces and the lit hemisphere would rotate with the camera.
        vNormal = normalize(mat3(modelMatrix) * normal);
        // Object-space normal — locked to the planet body. Used by the
        // spin-texture path so the noise pattern rotates WITH the body
        // (sampling world-space coords would lock the pattern to space
        // and the rotation would be invisible).
        vObjectNormal = normalize(normal);
        vec4 mvPos = modelViewMatrix * vec4(position, 1.0);
        vWorldPos = (modelMatrix * vec4(position, 1.0)).xyz;
        gl_Position = projectionMatrix * mvPos;
        #include <logdepthbuf_vertex>
      }
    `,
    fragmentShader: `
      #include <common>
      #include <logdepthbuf_pars_fragment>
      uniform vec3  uColor;
      uniform float uEmissive;
      uniform float uShowBands;
      uniform float uShowIceCaps;
      uniform float uHasPhaseCurve;
      uniform vec3  uDaysideColor;
      uniform vec3  uNightsideColor;
      uniform float uAlbedoFactor;
      uniform vec3  uReflectionTint;
      uniform float uTintStrength;
      uniform float uShowSpinTexture;
      varying vec3 vNormal;
      varying vec3 vWorldPos;
      varying vec3 vObjectNormal;

      // 3D value noise for the spin-texture patches. Hash + smoothstep
      // interpolation across a unit cell — cheap and good enough for a
      // surface-feature modulation; not trying to ray-march clouds.
      float hash3(vec3 p) {
        return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
      }
      float noise3(vec3 p) {
        vec3 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float n000 = hash3(i);
        float n100 = hash3(i + vec3(1, 0, 0));
        float n010 = hash3(i + vec3(0, 1, 0));
        float n110 = hash3(i + vec3(1, 1, 0));
        float n001 = hash3(i + vec3(0, 0, 1));
        float n101 = hash3(i + vec3(1, 0, 1));
        float n011 = hash3(i + vec3(0, 1, 1));
        float n111 = hash3(i + vec3(1, 1, 1));
        return mix(
          mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
          mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
          f.z);
      }

      void main() {
        #include <logdepthbuf_fragment>

        // Sun is at world origin; direction from planet surface to sun is
        // -normalize(worldPos). Used by both lighting paths.
        vec3 lightDir = normalize(-vWorldPos);
        float dotNL = dot(vNormal, lightDir);

        vec3 col;
        if (uHasPhaseCurve > 0.5) {
          // Thermal phase-curve mode (hot Jupiters with measured day/night
          // temps). The colors already encode brightness via blackbody
          // emission, so we don't apply a separate diffuse/ambient — the
          // dayside is bright because it's hot, the nightside is dim
          // because it's cool. Albedo doesn't apply here: these planets are
          // emission-dominated and reflected starlight is a small fraction.
          //
          // Soft terminator: smoothstep over a wide ~90° band (cos -0.4 to
          // 0.4) so the day/night transition reads as the gentle gradient
          // an atmospheric body really has, not a hard shadow line. Real
          // hot Jupiters are tidally locked with strong equatorial jets
          // that smear the substellar heat peak across a wide swath of the
          // disc. The pow(t, 1.6) bias makes the dim half take longer to
          // brighten so the dim-to-bright ramp doesn't visually overshoot
          // toward the bright side under our perceptual gamma.
          float t = smoothstep(-0.4, 0.4, dotNL);
          t = pow(t, 1.6);
          col = mix(uNightsideColor, uDaysideColor, t);
        } else {
          // Reflective mode: sun-direction diffuse + small ambient floor.
          // Both terms scale with uAlbedoFactor (measured/0.30; default 1.0
          // when unmeasured, so unmeasured planets keep the original
          // ambient = 0.08 baseline). For TrES-2 b (factor ~ 0.083) BOTH
          // diffuse and ambient drop, so the body genuinely reads near-
          // black instead of bottoming out at the ambient floor.
          //
          // uReflectionTint is mixed directly into the body color (not
          // multiplied — multiplying blue × warm-brown zeroes the
          // non-overlapping channels and the tint disappears). For
          // HD 189733 b this lets the deep-cobalt blue actually show
          // through on a hot-Jupiter base color.
          float diffuse = max(0.0, dotNL) * uAlbedoFactor;
          float ambient = 0.08 * uAlbedoFactor;
          vec3 reflectColor = mix(uColor, uReflectionTint, uTintStrength);
          col = reflectColor * (diffuse + ambient);
          col += uColor * uEmissive;
        }

        // Latitude — for a unit sphere with normal pointing outward, the
        // y-component of the world-frame normal IS the sine of the latitude.
        float lat = vNormal.y;
        float absLat = abs(lat);

        // Gas giant bands modulate brightness in both lighting modes — they
        // are surface features regardless of where the heat comes from.
        if (uShowBands > 0.5) {
          float bands = sin(lat * 12.0) * 0.5 + 0.5;
          col *= mix(0.92, 1.08, bands);
        }

        // Object-space spin texture: 2-octave 3D value noise locked to
        // the planet body so the pattern visibly rotates as the body
        // spins. For L-dwarf-class hot directly-imaged planets this
        // reads as patchy silicate / iron cloud decks (Crossfield 2014's
        // Luhman 16 B rotational mapping is the prototype); for cooler
        // gas giants it reads as Jupiter-like mottling. Modulation
        // amplitude is intentionally chunky (~±18%) so the rotation is
        // clearly visible at typical zoom and animation speeds — too
        // subtle and the verification fails its own purpose.
        if (uShowSpinTexture > 0.5) {
          vec3 q = vObjectNormal * 4.5;
          float n1 = noise3(q);
          float n2 = noise3(q * 2.3 + vec3(13.7, 5.1, 9.2));
          float patches = 0.6 * n1 + 0.4 * n2;
          col *= mix(0.82, 1.18, patches);
        }

        // Ice caps only apply to cold rocky planets, which never have
        // phase-curve mode (gating threshold is dayside > 1200K).
        if (uShowIceCaps > 0.5) {
          float capStrength = smoothstep(0.55, 0.85, absLat);
          col = mix(col, vec3(0.88, 0.92, 0.96), capStrength * 0.85);
        }

        gl_FragColor = vec4(col, 1.0);
      }
    `,
  });
  planetMaterialCache.set(key, mat);
  return mat;
}

// Gas-giant atmospheric halo. A slightly larger sphere with a fresnel shader:
// alpha is high at the silhouette (looking through atmosphere edge-on, more
// scattering) and 0 toward the center (looking straight down, atmosphere is
// thin). Front-side rendering, additive blending so it brightens the
// silhouette against background space.
function PlanetAtmosphere({ radius, color }: { radius: number; color: string }) {
  const material = useMemo(() => new THREE.ShaderMaterial({
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    side: THREE.FrontSide,
    defines: { USE_LOGDEPTHBUF: '' },
    uniforms: { uColor: { value: new THREE.Color(color) } },
    vertexShader: `
      #include <common>
      #include <logdepthbuf_pars_vertex>
      varying vec3 vNormalView;
      varying vec3 vViewDir;
      varying vec3 vNormalWorld;
      varying vec3 vWorldPos;
      void main() {
        vNormalView = normalize(normalMatrix * normal);
        vNormalWorld = normalize(mat3(modelMatrix) * normal);
        vec4 worldPos4 = modelMatrix * vec4(position, 1.0);
        vWorldPos = worldPos4.xyz;
        vec4 mvPos = viewMatrix * worldPos4;
        vViewDir = normalize(-mvPos.xyz);
        gl_Position = projectionMatrix * mvPos;
        #include <logdepthbuf_vertex>
      }
    `,
    fragmentShader: `
      #include <common>
      #include <logdepthbuf_pars_fragment>
      uniform vec3 uColor;
      varying vec3 vNormalView;
      varying vec3 vViewDir;
      varying vec3 vNormalWorld;
      varying vec3 vWorldPos;
      void main() {
        #include <logdepthbuf_fragment>
        float facing = max(0.0, dot(vNormalView, vViewDir));
        // Thin atmospheric haze hugging the planet's limb. Shell sits at
        // 1.08× planet radius (~realistic atmosphere fraction; Earth's
        // is ~1%). Same gradient direction as the sun: transparent at
        // the silhouette, fades up softly toward the planet body.
        // Where the planet body would occlude the shell, depth test
        // rejects the fragment and the planet's gradient stays clean.
        float alpha = smoothstep(0.0, 0.6, facing) * 0.18;
        // Sun-side modulation — atmosphere only glows where lit. Dark
        // side fades to nothing so we don't get visible "ghost halos"
        // when the parent planet body is hidden behind the sun.
        vec3 lightDir = normalize(-vWorldPos);
        float lit = max(dot(vNormalWorld, lightDir), 0.0);
        float sunBoost = mix(0.0, 1.0, lit);
        gl_FragColor = vec4(uColor, alpha * sunBoost);
      }
    `,
  }), [color]);

  return (
    <mesh material={material} renderOrder={5}>
      <sphereGeometry args={[radius, 64, 64]} />
    </mesh>
  );
}

// Compute an atmospheric tint color from detected molecule list. Defensible
// per-molecule colors based on what each absorbs/reflects in the visible
// spectrum. Only applies when the API returned curated molecule detections
// for this planet (~30 planets currently).
function atmosphereTintFromMolecules(
  molecules: { molecule: string; detection: string }[] | undefined,
): string | undefined {
  if (!molecules || molecules.length === 0) return undefined;
  const detected = molecules
    .filter((m) => m.detection === 'detected')
    .map((m) => m.molecule.toUpperCase());
  if (detected.length === 0) return undefined;
  // Priority: methane gives the strongest visible tint (Neptune-blue), then
  // water (pale blue-cyan), then CO2 (tan), then sodium/potassium (yellow).
  if (detected.includes('CH4')) return '#5b8aa8';
  if (detected.includes('H2O')) return '#a8c4d8';
  if (detected.includes('CO2')) return '#c8a878';
  if (detected.some((m) => m === 'NA' || m === 'K')) return '#d8c468';
  return undefined;
}

function PlanetLabel({ name, subtitle, yOffset = 0.012 }: { name: string; subtitle?: string; yOffset?: number }) {
  return (
    <Html position={[0, yOffset, 0]} center distanceFactor={undefined} style={{ pointerEvents: 'none' }}>
      <div style={{
        background: 'rgba(11, 13, 18, 0.85)',
        color: 'var(--fg)',
        padding: '0.25rem 0.55rem',
        borderRadius: 3,
        fontSize: '0.78rem',
        fontWeight: 600,
        letterSpacing: '0.02em',
        whiteSpace: 'nowrap',
        border: '1px solid rgba(255,255,255,0.12)',
      }}>
        {name}
        {subtitle && <span style={{ marginLeft: '0.4rem', color: 'var(--fg-muted)', fontWeight: 400, fontSize: '0.72rem' }}>{subtitle}</span>}
      </div>
    </Html>
  );
}
