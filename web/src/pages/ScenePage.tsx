import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import { Canvas } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import { api, type SceneResponse } from '../api';

export default function ScenePage() {
  const { plName = '' } = useParams<{ plName: string }>();
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';

  const [scene, setScene] = useState<SceneResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setScene(null);
    setError(null);
    api.planetScene(plName)
      .then(setScene)
      .catch((e: Error) => setError(e.message));
  }, [plName]);

  if (error) {
    return (
      <div style={{ padding: '1rem' }}>
        <p><Link to={`/planets/${encodeURIComponent(plName)}${themeQuery}`}>← back to detail</Link></p>
        <div className="error">Could not load scene: {error}</div>
      </div>
    );
  }

  if (!scene) {
    return (
      <div style={{ padding: '1rem' }}>
        <p><Link to={`/planets/${encodeURIComponent(plName)}${themeQuery}`}>← back to detail</Link></p>
        <p>Loading 3D scene…</p>
      </div>
    );
  }

  return (
    <>
      <SceneHUD scene={scene} backTo={`/planets/${encodeURIComponent(plName)}${themeQuery}`} />
      <Canvas
        style={{ position: 'fixed', inset: 0, background: '#000', zIndex: 0 }}
        camera={{ position: [0, 1.5, 5], fov: 50, near: 0.01, far: 5000 }}
      >
        <ambientLight intensity={0.04} />
        <OrbitControls enablePan={false} minDistance={1.5} maxDistance={200} />
        <SceneContents scene={scene} />
      </Canvas>
    </>
  );
}

function SceneHUD({ scene, backTo }: { scene: SceneResponse; backTo: string }) {
  const { planet, scene_hints } = scene;
  return (
    <div
      style={{
        position: 'fixed', top: 16, left: 16, zIndex: 10,
        background: 'rgba(11, 13, 18, 0.78)', color: 'var(--fg)',
        padding: '0.85rem 1rem', borderRadius: 4,
        fontSize: '0.85rem', maxWidth: 380, lineHeight: 1.5,
        backdropFilter: 'blur(4px)',
      }}
    >
      <p style={{ margin: '0 0 0.5rem' }}>
        <Link to={backTo}>← back to detail</Link>
      </p>
      <h2 style={{ margin: '0 0 0.4rem', fontSize: '1rem' }}>
        {planet.pl_name} — preview scene
      </h2>
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
      <p style={{ margin: '0.7rem 0 0', fontSize: '0.72rem', color: 'var(--fg-muted)' }}>
        Drag to orbit · scroll to zoom · Milestone 2 preview — body shader, siblings, starfield, and VR coming next.
      </p>
    </div>
  );
}

/**
 * Scene scale convention (v0):
 *   - planet at origin with radius = 1 unit
 *   - sun placed at fixed direction (off-camera-left, slightly forward) at
 *     SUN_DISTANCE units. its radius is computed so that its angular size from
 *     the planet matches scene_hints.sun_angular_size_deg.
 *   - this lets the user orbit close to the planet (zoom in to 1.5 units = just
 *     above the surface) while the sun stays correctly sized in the sky from
 *     any angle.
 */
const SUN_DISTANCE = 100;
const SUN_DIRECTION: [number, number, number] = [-0.8, 0.3, -0.5];   // unit-ish vector

function SceneContents({ scene }: { scene: SceneResponse }) {
  const { sun_color_hex, sun_angular_size_deg, body_type } = scene.scene_hints;

  const sunPosition = useMemo<[number, number, number]>(() => {
    const len = Math.hypot(...SUN_DIRECTION);
    return SUN_DIRECTION.map((c) => (c / len) * SUN_DISTANCE) as [number, number, number];
  }, []);

  const sunRadius = useMemo(() => {
    const angleDeg = sun_angular_size_deg ?? 0.534;   // Earth's Sun fallback
    const angleRad = (angleDeg * Math.PI) / 180;
    return SUN_DISTANCE * Math.tan(angleRad / 2);
  }, [sun_angular_size_deg]);

  const planetColor = bodyTypeToPlaceholderColor(body_type);

  return (
    <>
      {/* Planet body — placeholder material; real procedural shader is M3 */}
      <mesh position={[0, 0, 0]}>
        <sphereGeometry args={[1, 96, 96]} />
        <meshStandardMaterial
          color={planetColor}
          roughness={body_type === 'rocky' ? 0.95 : 0.6}
          metalness={0.0}
        />
      </mesh>

      {/* Host star — emissive sphere at correct angular size */}
      <mesh position={sunPosition}>
        <sphereGeometry args={[sunRadius, 64, 64]} />
        <meshBasicMaterial color={sun_color_hex} toneMapped={false} />
      </mesh>

      {/* Star's light, coming from the sun's direction */}
      <pointLight position={sunPosition} intensity={1.8} color={sun_color_hex} distance={0} decay={0} />
    </>
  );
}

function bodyTypeToPlaceholderColor(type: string): string {
  // Placeholders only — the real material per docs/PROCEDURAL_RENDERING.md
  // (driven by pl_eqt + composition) lands in Milestone 3.
  switch (type) {
    case 'rocky':     return '#8b6f47';
    case 'icy':       return '#9cc6d6';
    case 'gas_giant': return '#c89968';
    default:          return '#555';
  }
}
