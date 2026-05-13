import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Html, OrbitControls } from '@react-three/drei';
import { Bloom, EffectComposer } from '@react-three/postprocessing';
import { createXRStore, useXR, useXRControllerLocomotion, XR, XROrigin } from '@react-three/xr';
import * as THREE from 'three';
import { api, type BinaryCompanion, type DiscoveryPaper, type SceneResponse } from '../api';
import LoadingBar from '../components/LoadingBar';
import { planetVisual } from '../procedural';

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
  const [viewMode, setViewMode] = useState<'system' | 'surface'>('system');

  // Shared ref written by SceneContents each frame with the focal planet's
  // animated world position. Read by CameraFollowFocal in surface mode so
  // the camera rides along with the planet as it orbits.
  // The sun is always at scene origin — its position is constant.
  // BOTH hooks must be declared before any early returns (React rules of hooks).
  const focalPosRef = useRef(new THREE.Vector3());
  const sunWorldPos = useMemo(() => new THREE.Vector3(0, 0, 0), []);

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
  const focalRadius = planetDisplayRadius(scene.planet.pl_rade, orbsmax);
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
  const farPlane = STAR_SPHERE_AU * 1.2;

  const backTo = `/planets/${encodeURIComponent(plName)}${themeQuery}`;
  // Initialize the shared position to the focal planet's t=0 location so the
  // first surface-mode frame doesn't snap from origin to its actual position.
  if (focalPosRef.current.x === 0 && focalPosRef.current.z === 0) {
    focalPosRef.current.set(orbsmax, 0, 0);
  }
  // The focal planet's display radius — used as the camera's vertical offset
  // above the planet center in surface mode (so we're standing ON it, not in it).
  const surfaceOffset = focalRadius * 1.1;
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
      <CloseButton to={backTo} />
      <PlaybackControls
        paused={paused} setPaused={setPaused}
        speed={speed} setSpeed={setSpeed}
        viewMode={viewMode} setViewMode={setViewMode}
      />
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
              target={focalPos}
              enablePan={true}
              minDistance={focalRadius * 1.5}
              maxDistance={maxOrbit * 4 + 5}
            />
          )}
          {viewMode === 'surface' && (
            <>
              <FirstPersonLook trackTarget={sunWorldPos} />
              <CameraFollowFocal focalPosRef={focalPosRef} surfaceOffset={surfaceOffset} />
            </>
          )}
          {/* Visual scene content sits inside VRSceneScale so it scales up
              in VR (AU → meters mapping) without affecting the desktop view.
              Starfield lives OUTSIDE the scale group — its skydome follows
              the camera each frame, and being outside the scale means we
              can write camera.position directly to the mesh without having
              to divide by the scale factor. */}
          <VRSceneScale maxOrbit={maxOrbit}>
            {viewMode === 'system' ? (
              <SceneContents scene={scene} paused={paused} speed={speed} />
            ) : (
              <SceneContents
                scene={scene} paused={paused} speed={speed}
                hideFocal
                focalPosOut={focalPosRef}
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

function planetDisplayRadius(pl_rade: number | null, pl_orbsmax: number | null): number {
  const truthAU = (pl_rade ?? 1) * REARTH_IN_AU;
  const exaggerated = truthAU * BODY_EXAG;
  const orbitCap = (pl_orbsmax ?? 1) * ORBIT_CAP_FRAC;
  return Math.max(MIN_PLANET_AU, Math.min(exaggerated, orbitCap));
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
// never shrink a star.
function sunDisplayRadius(st_rad_solar: number | null, innermostPeriapsisAu: number): number {
  const truthAU = (st_rad_solar ?? 1) * RSUN_IN_AU;
  const exaggerated = truthAU * BODY_EXAG;
  const periapsisCap = innermostPeriapsisAu * SUN_PERIAPSIS_FRAC;
  return Math.max(truthAU, Math.min(exaggerated, periapsisCap));
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

  const distance_pc = host_star?.distance_gspphot_pc ?? planet.sy_dist;

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
          {scene_hints.day_length_hours != null
            ? `${scene_hints.day_length_hours.toFixed(1)} hours`
            : 'unknown'}
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
          </p>
        )}
      </Section>

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

function CloseButton({ to }: { to: string }) {
  return (
    <Link
      to={to}
      replace
      title="Exit 3D scene"
      style={{
        position: 'fixed', top: HEADER_OFFSET_PX, right: 16, zIndex: 10,
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

function PlaybackControls({
  paused, setPaused, speed, setSpeed,
  viewMode, setViewMode,
}: {
  paused: boolean; setPaused: (p: boolean) => void;
  speed: number; setSpeed: (s: number) => void;
  viewMode: 'system' | 'surface'; setViewMode: (v: 'system' | 'surface') => void;
}) {
  const isSurface = viewMode === 'surface';
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
           Threshold 0.30 catches the full photosphere disc — cool
           stars and hot stars alike get a generous halo. Side effect:
           bright companion stars and well-lit planets get some bloom
           too. */
        intensity={1.7}
        luminanceThreshold={0.30}
        luminanceSmoothing={0.25}
        mipmapBlur
        radius={0.9}
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
  scene, paused, speed,
  hideFocal = false,
  focalPosOut,
}: {
  scene: SceneResponse;
  paused: boolean;
  speed: number;
  /** When true, the focal planet body is not rendered (used in surface mode
      where the camera is "standing on" the planet — no need to see it). */
  hideFocal?: boolean;
  /** When provided, the focal planet's animated world position is written
      into this ref every frame so a parent component (the surface-view
      camera follower) can read it. */
  focalPosOut?: React.MutableRefObject<THREE.Vector3>;
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
  const innermost = innermostPeriapsis(scene);
  const sunRadius = sunDisplayRadius(planet.st_rad, innermost);

  // Animation clock — accumulates real seconds × speed when not paused.
  // Each planet derives its current orbital angle from this single shared time.
  const clock = useRef(0);
  const focalGroup = useRef<THREE.Group>(null);
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
    const [fx, , fz] = keplerPosition(focalOrbsmax, planet.pl_orbeccen ?? 0, M);
    if (focalGroup.current) focalGroup.current.position.set(fx, 0, fz);
    // Expose focal world position for surface-mode camera tracking
    if (focalPosOut) focalPosOut.current.set(fx, 0, fz);
    siblingRefs.current.forEach((group, plName) => {
      const s = siblings.find((x) => x.pl_name === plName);
      if (!s || s.pl_orbsmax == null) return;
      const M = meanAnomaly(s.pl_orbper, s.pl_name);
      const [x, , z] = keplerPosition(s.pl_orbsmax, s.pl_orbeccen ?? 0, M);
      group.position.set(x, 0, z);
    });
  });

  return (
    <>
      {/* Host star: photosphere sphere + animated billboard glow.
          The glow is a camera-facing plane with a custom radial-gradient
          shader — smooth multi-stop falloff (core, corona, halo) plus
          time-driven rim flicker for "boiling" stellar edge animation. */}
      {/* Photosphere(s). For circumbinary planets (cb_flag=1) the planet
          orbits a tight binary pair, so we render TWO suns rotating around
          their common barycenter at the origin. For everything else, one
          sun at origin. Bloom handles the glow for both cases the same way. */}
      {planet.cb_flag === 1
        ? <BinaryPhotospheres radius={sunRadius} color={sun_color_hex} teff={planet.st_teff} paused={paused} speed={speed} />
        : <Photosphere radius={sunRadius} color={sun_color_hex} teff={planet.st_teff} />
      }
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

      {/* Orbit rings — focal in accent color, siblings dimmer */}
      <OrbitRing orbsmax={focalOrbsmax} eccen={planet.pl_orbeccen ?? 0} color="#7ad6ff" opacity={0.55} />
      {siblings
        .filter((s) => s.pl_name !== planet.pl_name && s.pl_orbsmax != null)
        .map((s) => (
          <OrbitRing
            key={`ring-${s.pl_name}`}
            orbsmax={s.pl_orbsmax!}
            eccen={s.pl_orbeccen ?? 0}
            color="#888"
            opacity={0.45}
          />
        ))}

      {/* Focal planet — animated; group wraps so useFrame can move it.
          Hidden in surface mode (we're standing on it). The focal gets the
          atmospheric tint from curated molecule data; siblings don't (we
          don't fetch per-sibling atmospheric data in the scene endpoint). */}
      <group ref={focalGroup} position={[focalOrbsmax, 0, 0]}>
        {!hideFocal && (
          <>
            <PlanetBody
              position={[0, 0, 0]}
              radius={planetDisplayRadius(planet.pl_rade, focalOrbsmax)}
              pl_eqt={planet.pl_eqt}
              pl_dens={planet.pl_dens}
              pl_rade={planet.pl_rade}
              emphasized
              name={planet.pl_name}
              onHover={setHovered}
              atmosphereTint={atmosphereTintFromMolecules(scene.atmospheric_detections)}
            />
            {hovered === planet.pl_name && <PlanetLabel name={planet.pl_name} subtitle="(focal)" />}
          </>
        )}
      </group>

      {/* Siblings — clickable to jump perspective, hover shows name */}
      {siblings
        .filter((s) => s.pl_name !== planet.pl_name && s.pl_orbsmax != null)
        .map((s) => (
          <group
            key={s.pl_name}
            ref={(g) => { if (g) siblingRefs.current.set(s.pl_name, g); else siblingRefs.current.delete(s.pl_name); }}
          >
            <PlanetBody
              position={[0, 0, 0]}
              radius={planetDisplayRadius(s.pl_rade, s.pl_orbsmax!)}
              pl_eqt={s.pl_eqt}
              pl_dens={s.pl_dens}
              pl_rade={s.pl_rade}
              name={s.pl_name}
              onHover={setHovered}
              onClick={() => jumpTo(s.pl_name)}
            />
            {hovered === s.pl_name && <PlanetLabel name={s.pl_name} subtitle="click to jump" />}
          </group>
        ))}

      {/* Companion stars (static — they orbit on millennia timescales,
          irrelevant at our 60-sec-per-orbit pacing) */}
      {scene.binary_companions.map((c) => (
        <CompanionStar
          key={c.component_designation}
          companion={c}
          systemDistancePc={scene.host_star?.distance_gspphot_pc ?? scene.planet.sy_dist ?? null}
        />
      ))}
    </>
  );
}

function CompanionStar({
  companion,
  systemDistancePc,
}: {
  companion: BinaryCompanion;
  systemDistancePc: number | null;
}) {
  // 1 AU subtends 1 arcsec at 1 pc — so projected separation in AU is just
  // sep_arcsec * distance_pc. We have no information on the line-of-sight
  // component, so the companion's true distance from the primary is at least
  // this and unknown how much more.
  if (companion.separation_arcsec == null || systemDistancePc == null) return null;
  const sepAU = companion.separation_arcsec * systemDistancePc;
  if (sepAU <= 0) return null;

  // Position angle (degrees east of north on the sky) used to give each
  // companion a distinct direction. Tilt 30° off the orbital plane so wide
  // companions visually sit "off to the side" rather than mixed in with the
  // planet orbits — honest about the unknown 3D orientation.
  const pa = ((companion.position_angle_deg ?? 0) * Math.PI) / 180;
  const tiltY = Math.sin(0.52);   // ~30° lift above XZ plane
  const planar = Math.cos(0.52);
  const position: [number, number, number] = [
    sepAU * Math.cos(pa) * planar,
    sepAU * tiltY,
    sepAU * Math.sin(pa) * planar,
  ];

  const color = spectralTypeToColor(companion.component_spectype);
  // Companion-star physical radius isn't in our data; estimate from spectral
  // type (M ~0.3 R_sun, K ~0.7, G ~1, etc.). True angular size from inner
  // planets will be tiny — but we emphasize emissive intensity to make sure
  // it reads as a "bright second sun in the sky."
  const radiusAU = estimateStarRadiusRsun(companion.component_spectype) * RSUN_IN_AU;

  return (
    <group>
      <mesh position={position}>
        <sphereGeometry args={[radiusAU, 32, 32]} />
        <meshBasicMaterial color={color} toneMapped={false} />
      </mesh>
      <pointLight position={position} intensity={0.4} color={color} distance={0} decay={0} />
    </group>
  );
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

function Photosphere({ radius, color, teff }: { radius: number; color: string; teff: number | null }) {
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
  // Base 2.0 × warmth × bonus → uHdr range: ~2.8 (TRAPPIST-1) → 2.0 (Sun)
  // → ~5.0 (KELT-9 and hotter). Cool stars get a generous red halo, hot
  // stars stay intensely bright, and the range stays well below the
  // mipmapBlur dome threshold.
  const hdrScale = 2.0 * warmth * bonus;
  // Saturation push for cool stars: suppress green and (more aggressively)
  // blue so the photosphere reads as deep RED, not orange. The Tanner-Helland
  // blackbody approximation gives a perceptually accurate "neutral-eye" color
  // that's actually quite orange for M-dwarfs (#ffa24c at 2566K). Real M-dwarfs
  // would look much redder to a human, and bloom over dark space turns the
  // generic orange into muddy brown — neither is what we want. Pushing G/B
  // down rebalances toward a hauntingly-red look that survives bloom.
  const saturated = new THREE.Color(color);
  saturated.g *= 1.0 - cool * 0.7;
  saturated.b *= 1.0 - cool * 0.85;
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: saturated },
      uTime:  { value: 0 },
      uHdr:   { value: hdrScale },
      uLogDepthBufFC: { value: 0 },
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

        float mu = max(0.0, dot(vNormal, vViewDir));
        float limb = mix(0.15, 1.0, pow(mu, 0.7));

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
  }), [color, hdrScale]);

  useFrame((state) => {
    material.uniforms.uTime.value = state.clock.getElapsedTime();
    const xrCamera = state.gl.xr.getCamera();
    const xrFar = (xrCamera.isArrayCamera ? xrCamera.cameras[0]?.far : undefined) ?? xrCamera.far;
    const activeFar = state.gl.xr.isPresenting ? xrFar : state.camera.far;
    const fallbackFar = Number.isFinite(state.camera.far) && state.camera.far > 0 ? state.camera.far : 1000;
    const safeFar = Number.isFinite(activeFar) && activeFar > 0 ? activeFar : fallbackFar;
    material.uniforms.uLogDepthBufFC.value = 2.0 / (Math.log(safeFar + 1.0) / Math.LN2);
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
      <mesh material={depthOnlyMaterial} renderOrder={-100}>
        <sphereGeometry args={[radius, 64, 64]} />
      </mesh>
      <mesh material={material} renderOrder={10}>
        <sphereGeometry args={[radius, 64, 64]} />
      </mesh>
    </>
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
}: {
  radius: number; color: string; teff: number | null; paused: boolean; speed: number;
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

  return (
    <>
      <group ref={starA}>
        <Photosphere radius={primaryRadius} color={color} teff={teff} />
      </group>
      <group ref={starB}>
        {/* Secondary uses a cooler-equivalent teff so its red-shifted
            color reads correctly through the Stefan-Boltzmann scaling. */}
        <Photosphere radius={secondaryRadius} color={secondaryColor} teff={teff != null ? teff * 0.65 : null} />
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
  orbsmax, eccen, color, opacity,
}: {
  orbsmax: number; eccen: number; color: string; opacity: number;
}) {
  // Native three.js Line (gl_LINES, 1px width) instead of drei's Line2
  // wrapper. Line2 renders thick lines as instanced quad strips and its
  // depth output doesn't reliably occlude against custom shaders, which
  // caused orbit rings to draw on top of the photosphere. Native lines
  // depth-test correctly per fragment.
  const geometry = useMemo(() => {
    const a = orbsmax;
    const e = Math.max(0, Math.min(0.99, eccen));
    const b = a * Math.sqrt(1 - e * e);
    const N = 256;
    const positions = new Float32Array((N + 1) * 3);
    for (let i = 0; i <= N; i++) {
      const t = (i / N) * Math.PI * 2;
      positions[i * 3 + 0] = a * Math.cos(t) - a * e;
      positions[i * 3 + 1] = 0;
      positions[i * 3 + 2] = b * Math.sin(t);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    return g;
  }, [orbsmax, eccen]);

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

// ── Gaia starfield ────────────────────────────────────────────────────────
// Loads /starfield_basic.bin once on mount, parses the packed-float format
// produced by etl/build_starfield.py, and renders ~62k stars as a single
// Points draw call on a sphere of radius STAR_SPHERE_AU around the origin.

function Starfield({ plName }: { plName: string }) {
  const [texture, setTexture] = useState<THREE.Texture | null>(null);
  const { scene } = useThree();
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
  // (~33MB at 4096×2048 RGB) allocates each mount. Without dispose, GPU
  // memory leaks per toggle.
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
  // Radius is set back to STAR_SPHERE_AU (5000) — at this size the mesh
  // is known to render in VR (we saw it render at this radius earlier in
  // this session). At 1e6 it silently failed to render on Quest, likely
  // because the XR session's actual depth-far is clamped well below the
  // 1e9 we requested via updateRenderState. Camera-follow eliminates the
  // parallax that 5000-radius would otherwise produce.
  // side: DoubleSide rather than BackSide as a defensive choice — if
  // anything in the XR rendering pipeline is silently culling our
  // BackSide-only faces (some multiview implementations have quirks
  // with face culling), DoubleSide guarantees the inside-facing surface
  // renders regardless. Negligible perf cost for a single 64×32 sphere.
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

function estimateStarRadiusRsun(spectype: string | null): number {
  if (!spectype) return 0.7;
  const letter = spectype.trim().charAt(0).toUpperCase();
  // Main-sequence median radii. Brown dwarfs (L/T/Y) are ~Jupiter-sized.
  switch (letter) {
    case 'O': return 10;
    case 'B': return 4;
    case 'A': return 1.7;
    case 'F': return 1.3;
    case 'G': return 1.0;
    case 'K': return 0.7;
    case 'M': return 0.3;
    case 'L': case 'T': case 'Y': return 0.1;
    case 'D': return 0.012;   // white dwarf
    default:  return 0.7;
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
}: {
  position: [number, number, number];
  radius: number;
  pl_eqt: number | null;
  pl_dens: number | null;
  pl_rade: number | null;
  emphasized?: boolean;
  name?: string;
  onHover?: (n: string | null) => void;
  onClick?: () => void;
  /** When provided, overrides the default atmospheric haze color for gas
      giants. Driven by curated molecule detections — methane → blue,
      water → pale blue, CO2 → tan, etc. Only meaningful for the focal planet
      (siblings don't get per-planet atmosphere data fetched). */
  atmosphereTint?: string;
}) {
  const visual = useMemo(
    () => planetVisual(pl_eqt, pl_dens, pl_rade),
    [pl_eqt, pl_dens, pl_rade]
  );
  const isGasGiant = visual.bodyType === 'gas_giant';
  const isIcyOrCold = visual.bodyType === 'rocky' && (pl_eqt ?? 999) < 273;
  // Hit-mesh: invisible larger sphere for generous click/hover targeting.
  const hitRadius = Math.max(radius * 2.5, radius + 0.005);

  // Procedural body material: gas giants get faint latitude bands; cold rocky
  // planets get polar ice caps; everything else stays flat-color (with
  // emissive for hot lava worlds).
  const bodyMaterial = useMemo(
    () => buildPlanetBodyMaterial({
      bodyType: visual.bodyType,
      fillColor: visual.fillColor,
      glow: visual.glow,
      isCold: isIcyOrCold,
    }),
    [visual.bodyType, visual.fillColor, visual.glow, isIcyOrCold],
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
      {/* Planet body */}
      <mesh material={bodyMaterial}>
        <sphereGeometry args={[radius, emphasized ? 128 : 64, emphasized ? 128 : 64]} />
      </mesh>
      {/* Gas giant atmospheric halo: a slightly-larger sphere with a fresnel
          shader. Bright at the silhouette (where you'd see through more
          atmosphere from outside), transparent toward the center (where you
          look straight down through thin atmosphere). The atmospheric tint
          color comes from molecule detections when available, otherwise the
          planet's own color slightly desaturated. */}
      {isGasGiant && (
        <PlanetAtmosphere
          radius={radius * 1.08}
          color={atmosphereTint ?? visual.fillColor}
        />
      )}
    </group>
  );
}

// Shared cache so the same (bodyType, fillColor, ...) doesn't allocate a new
// material per render. Each unique tuple gets one ShaderMaterial.
const planetMaterialCache = new Map<string, THREE.ShaderMaterial>();

function buildPlanetBodyMaterial({
  bodyType, fillColor, glow, isCold,
}: {
  bodyType: string; fillColor: string; glow: boolean; isCold: boolean;
}): THREE.ShaderMaterial {
  const key = `${bodyType}|${fillColor}|${glow}|${isCold}`;
  const cached = planetMaterialCache.get(key);
  if (cached) return cached;

  const isGasGiant = bodyType === 'gas_giant';
  const showIceCaps = bodyType === 'rocky' && isCold;

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
    },
    vertexShader: `
      #include <common>
      #include <logdepthbuf_pars_vertex>
      varying vec3 vNormal;
      varying vec3 vWorldPos;
      void main() {
        // World-space normal — must match the world-space lightDir below
        // (sun-at-origin). Using view-space normalMatrix here would mix
        // coord spaces and the lit hemisphere would rotate with the camera.
        vNormal = normalize(mat3(modelMatrix) * normal);
        vec4 mvPos = modelViewMatrix * vec4(position, 1.0);
        vWorldPos = (modelMatrix * vec4(position, 1.0)).xyz;
        gl_Position = projectionMatrix * mvPos;
        #include <logdepthbuf_vertex>
      }
    `,
    fragmentShader: `
      #include <common>
      #include <logdepthbuf_pars_fragment>
      uniform vec3 uColor;
      uniform float uEmissive;
      uniform float uShowBands;
      uniform float uShowIceCaps;
      varying vec3 vNormal;
      varying vec3 vWorldPos;

      void main() {
        #include <logdepthbuf_fragment>

        // Lighting: sun is at world origin. Direction from planet surface
        // toward the sun is -normalize(worldPos). Both vectors are now in
        // world space, so the dot product is camera-independent.
        vec3 lightDir = normalize(-vWorldPos);
        float diffuse = max(0.0, dot(vNormal, lightDir));
        float ambient = 0.18;
        float lighting = diffuse + ambient;

        vec3 col = uColor;

        // Latitude — for a unit sphere with normal pointing outward, the
        // y-component of the world-frame normal IS the sine of the latitude.
        // We approximate with the local normal's y component since planets
        // aren't tilted in our scene.
        float lat = vNormal.y;             // -1 (south pole) → 1 (north pole)
        float absLat = abs(lat);

        // Gas giant bands: subtle horizontal stripes from latitude. ~12 bands
        // across the sphere. Modulation is small (±8%) so it reads as
        // "differential rotation banding" without claiming specific colors.
        if (uShowBands > 0.5) {
          float bands = sin(lat * 12.0) * 0.5 + 0.5;
          col *= mix(0.92, 1.08, bands);
        }

        // Ice caps: brighten and shift toward white near the poles. Only
        // applied when the planet is rocky AND cold (eqt < 273K). The
        // smoothstep gives a soft transition rather than a hard line.
        if (uShowIceCaps > 0.5) {
          float capStrength = smoothstep(0.55, 0.85, absLat);
          col = mix(col, vec3(0.88, 0.92, 0.96), capStrength * 0.85);
        }

        col *= lighting;

        // Emissive add for hot worlds (lava glow on rocky, hot-Jupiter glow)
        col += uColor * uEmissive;

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

function PlanetLabel({ name, subtitle }: { name: string; subtitle?: string }) {
  return (
    <Html position={[0, 0.012, 0]} center distanceFactor={undefined} style={{ pointerEvents: 'none' }}>
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
