const IMG = 1280;

const GC_PX  = { x: 630, y: 555 };
const SUN_PX = { x: 755, y: 820 };

const R_SUN_PC    = 8300;
const PX_PER_PC   = Math.hypot(GC_PX.x - SUN_PX.x, GC_PX.y - SUN_PX.y) / R_SUN_PC;
const ANGLE_TO_GC = Math.atan2(GC_PX.y - SUN_PX.y, GC_PX.x - SUN_PX.x);

const RA_NGP  = 192.859508 * (Math.PI / 180);
const DEC_NGP = 27.128336  * (Math.PI / 180);
const L_NCP   = 122.932    * (Math.PI / 180);

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

type Props = { ra: number; dec: number; distPc: number; hostname: string };

export default function GalaxyMap({ ra, dec, distPc, hostname }: Props) {
  const [l, b] = toGalactic(ra, dec);
  const dProj  = distPc * Math.cos(b * Math.PI / 180);
  const angle  = ANGLE_TO_GC - l * (Math.PI / 180);
  const distPx = dProj * PX_PER_PC;

  const sysX = Math.max(10, Math.min(IMG - 10, SUN_PX.x + distPx * Math.cos(angle)));
  const sysY = Math.max(10, Math.min(IMG - 10, SUN_PX.y + distPx * Math.sin(angle)));
  const sep  = Math.hypot(sysX - SUN_PX.x, sysY - SUN_PX.y);

  return (
    <div style={{ marginTop: '0.75rem' }}>
      <svg
        viewBox={`0 0 ${IMG} ${IMG}`}
        width="100%"
        style={{ display: 'block', borderRadius: '6px' }}
        aria-label="Milky Way map — Solar System location"
      >
        <image href="/milkyway.jpg" x="0" y="0" width={IMG} height={IMG} />

        <circle cx={SUN_PX.x} cy={SUN_PX.y} r={6} fill="#ffe080">
          <title>you are here</title>
        </circle>

        {sep >= 15 && (
          <circle cx={sysX} cy={sysY} r={6} fill="#6ccfff">
            <title>{hostname}</title>
          </circle>
        )}
      </svg>
      {sep < 15 && (
        <p style={{ margin: '0.4rem 0 0', fontSize: '0.78rem', color: 'var(--fg-muted)' }}>
          {hostname} is too close to show separately from our position at this scale.
        </p>
      )}
    </div>
  );
}
