// Top-down schematic of the Milky Way showing where the Solar System and target
// system are relative to the galactic center.
//
// Coordinate math:
//   RA + Dec → galactic (l, b) via IAU J2000 rotation
//   (l, b, d) → galactic Cartesian → SVG position
//
// Galaxy frame: origin at galactic center (GC), x-axis pointing from GC toward
// the Solar System. Sun sits at (+R_SUN, 0); the SVG lays this out with GC at
// center and Sun to the right.

// IAU J2000 galactic coordinate constants
const RA_NGP  = 192.859508 * (Math.PI / 180); // RA of north galactic pole
const DEC_NGP = 27.128336  * (Math.PI / 180); // Dec of north galactic pole
const L_NCP   = 122.932    * (Math.PI / 180); // galactic longitude of NCP

function toGalactic(raDeg: number, decDeg: number): [number, number] {
  const a = raDeg  * (Math.PI / 180);
  const d = decDeg * (Math.PI / 180);
  const sinB =
    Math.sin(d) * Math.sin(DEC_NGP) +
    Math.cos(d) * Math.cos(DEC_NGP) * Math.cos(a - RA_NGP);
  const b = Math.asin(Math.max(-1, Math.min(1, sinB)));
  const y = Math.cos(d) * Math.sin(a - RA_NGP);
  const x = Math.sin(d) * Math.cos(DEC_NGP) - Math.cos(d) * Math.sin(DEC_NGP) * Math.cos(a - RA_NGP);
  const l = ((L_NCP - Math.atan2(y, x)) * (180 / Math.PI) + 360) % 360;
  return [l, b * (180 / Math.PI)];
}

// SVG canvas
const W = 420, H = 240;
const CX = W / 2, CY = H / 2;

// Galactic constants (parsecs)
const R_SUN     = 8300;   // Sun's distance from GC
const GALAXY_R  = 16000;  // visual disk radius for the map
const PX_PER_PC = (W * 0.44) / GALAXY_R; // ≈ 0.01155 px/pc

// Logarithmic spiral arm generator — pitch angle ~13° (Milky Way typical)
const K_PITCH = Math.tan(13 * Math.PI / 180);
function spiralArmD(startTheta: number): string {
  const pts: string[] = [];
  for (let i = 0; i <= 200; i++) {
    const th = startTheta + i * 0.04;
    const r  = 2200 * Math.exp(K_PITCH * (th - startTheta));
    if (r > GALAXY_R * 0.94) break;
    const sx = CX + r * Math.cos(th) * PX_PER_PC;
    const sy = CY - r * Math.sin(th) * PX_PER_PC; // flip y for SVG
    pts.push(`${i === 0 ? 'M' : 'L'} ${sx.toFixed(1)} ${sy.toFixed(1)}`);
  }
  return pts.join(' ');
}

type Props = {
  ra: number;
  dec: number;
  distPc: number;
  hostname: string;
};

export default function GalaxyMap({ ra, dec, distPc, hostname }: Props) {
  const [l, b] = toGalactic(ra, dec);
  const lR = l * (Math.PI / 180);
  const bR = b * (Math.PI / 180);

  // Project distance onto galactic plane (ignore z / galactic latitude for top-down)
  const dProj = distPc * Math.cos(bR);
  const xEarth = dProj * Math.cos(lR); // parsecs toward GC (l=0°)
  const yEarth = dProj * Math.sin(lR); // parsecs 90° CCW from GC

  // Galaxy-centered coordinates: Sun is at (R_SUN, 0)
  // Moving toward GC (xEarth > 0) decreases galaxy-frame x.
  const xGal = R_SUN - xEarth;
  const yGal = yEarth;

  // SVG positions
  const sunX = CX + R_SUN * PX_PER_PC;
  const sunY = CY;
  const sysX = CX + xGal * PX_PER_PC;
  const sysY = CY - yGal * PX_PER_PC;

  const gR = GALAXY_R * PX_PER_PC; // galaxy visual radius in px
  const sepPx = Math.hypot(sysX - sunX, sysY - sunY);
  const tooClose = sepPx < 5; // < ~430 pc at this scale

  // Clamp system dot to within SVG bounds so the label doesn't vanish
  const sysDotX = Math.max(8, Math.min(W - 8, sysX));
  const sysDotY = Math.max(8, Math.min(H - 8, sysY));
  const isClipped = sysDotX !== sysX || sysDotY !== sysY;

  // Four-arm spiral offsets (pairs 180° apart)
  const armStarts = [0, Math.PI, Math.PI / 2, 3 * Math.PI / 2];

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      width="100%"
      style={{ display: 'block', marginTop: '0.75rem' }}
      aria-label={`Top-down map of the Milky Way showing the Solar System and ${hostname}`}
    >
      <defs>
        <radialGradient id="gm-halo" cx="50%" cy="50%">
          <stop offset="0%"   stopColor="#1e2d5a" stopOpacity="0.55" />
          <stop offset="70%"  stopColor="#0e1830" stopOpacity="0.18" />
          <stop offset="100%" stopColor="#050a14" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="gm-disk" cx="50%" cy="50%">
          <stop offset="0%"   stopColor="#3050a0" stopOpacity="0.7" />
          <stop offset="45%"  stopColor="#203880" stopOpacity="0.3" />
          <stop offset="100%" stopColor="#0c1428" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="gm-core" cx="50%" cy="50%">
          <stop offset="0%"   stopColor="#fff8d0" stopOpacity="1" />
          <stop offset="18%"  stopColor="#ffb040" stopOpacity="0.85" />
          <stop offset="45%"  stopColor="#9060c0" stopOpacity="0.45" />
          <stop offset="100%" stopColor="#2840a0" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="gm-sun-glow" cx="50%" cy="50%">
          <stop offset="0%"   stopColor="#ffe890" stopOpacity="0.9" />
          <stop offset="100%" stopColor="#ffe890" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="gm-sys-glow" cx="50%" cy="50%">
          <stop offset="0%"   stopColor="#60ccff" stopOpacity="0.7" />
          <stop offset="100%" stopColor="#60ccff" stopOpacity="0" />
        </radialGradient>
      </defs>

      {/* Outer halo */}
      <ellipse cx={CX} cy={CY} rx={gR * 1.15} ry={gR * 1.05} fill="url(#gm-halo)" />

      {/* Disk */}
      <ellipse cx={CX} cy={CY} rx={gR} ry={gR * 0.93} fill="url(#gm-disk)" />

      {/* Spiral arms — 4 arms at low opacity, schematic only */}
      {armStarts.map((th0, i) => (
        <path
          key={i}
          d={spiralArmD(th0)}
          fill="none"
          stroke="#5070d0"
          strokeOpacity="0.10"
          strokeWidth="9"
          strokeLinecap="round"
        />
      ))}

      {/* Galactic core */}
      <ellipse cx={CX} cy={CY} rx={gR * 0.09} ry={gR * 0.075} fill="url(#gm-core)" />

      {/* GC label */}
      <text
        x={CX} y={CY + gR * 0.13}
        textAnchor="middle" fontSize="6.5"
        fill="#ffa040" opacity="0.45"
        fontFamily="-apple-system, sans-serif"
      >
        galactic center
      </text>

      {/* Connection line: Sun → system */}
      {!tooClose && !isClipped && (
        <line
          x1={sunX} y1={sunY} x2={sysDotX} y2={sysDotY}
          stroke="var(--accent, #6cf)"
          strokeOpacity="0.35"
          strokeWidth="0.75"
          strokeDasharray="3,4"
        />
      )}

      {/* Solar System */}
      <circle cx={sunX} cy={sunY} r={8}   fill="url(#gm-sun-glow)" />
      <circle cx={sunX} cy={sunY} r={2.5} fill="#ffe080" />
      <text
        x={sunX} y={sunY + 13}
        textAnchor="middle" fontSize="7.5"
        fill="#ffe080" opacity="0.85"
        fontFamily="-apple-system, sans-serif"
      >
        ☀ you are here
      </text>

      {/* Target system */}
      {tooClose ? (
        <text
          x={sunX} y={sunY - 14}
          textAnchor="middle" fontSize="7"
          fill="var(--fg-muted)"
          fontFamily="-apple-system, sans-serif"
        >
          {hostname} — indistinguishable from ☀ at this scale
        </text>
      ) : (
        <>
          <circle cx={sysDotX} cy={sysDotY} r={6}   fill="url(#gm-sys-glow)" />
          <circle cx={sysDotX} cy={sysDotY} r={2}   fill="var(--accent, #6cf)" />
          <text
            x={sysDotX}
            y={sysDotY > sunY ? sysDotY + 13 : sysDotY - 6}
            textAnchor={sysDotX < 100 ? 'start' : sysDotX > W - 100 ? 'end' : 'middle'}
            fontSize="7.5"
            fill="var(--accent, #6cf)"
            opacity="0.9"
            fontFamily="-apple-system, sans-serif"
          >
            {isClipped ? `→ ${hostname}` : hostname}
          </text>
        </>
      )}

      {/* Scale bar — bottom-left */}
      {(() => {
        const barPc = 5000;
        const bx1 = 14, bx2 = bx1 + barPc * PX_PER_PC, by = H - 14;
        return (
          <g opacity="0.55">
            <line x1={bx1} y1={by} x2={bx2} y2={by} stroke="#4a5a80" strokeWidth="1" />
            <line x1={bx1} y1={by - 3} x2={bx1} y2={by + 3} stroke="#4a5a80" strokeWidth="1" />
            <line x1={bx2} y1={by - 3} x2={bx2} y2={by + 3} stroke="#4a5a80" strokeWidth="1" />
            <text x={(bx1 + bx2) / 2} y={by - 5}
                  textAnchor="middle" fontSize="7"
                  fill="#4a5a80"
                  fontFamily="-apple-system, sans-serif">
              5,000 pc
            </text>
          </g>
        );
      })()}

      {/* Galactic latitude note — bottom-right */}
      {Math.abs(b) > 5 && (
        <text
          x={W - 10} y={H - 10}
          textAnchor="end" fontSize="6.5"
          fill="var(--fg-muted)" opacity="0.6"
          fontFamily="-apple-system, sans-serif"
        >
          {b > 0 ? '+' : ''}{b.toFixed(1)}° galactic latitude
        </text>
      )}
    </svg>
  );
}
