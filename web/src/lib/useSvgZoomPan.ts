import { useCallback, useEffect, useRef, useState } from 'react';
import type { RefObject } from 'react';

export type ViewBox = { x: number; y: number; w: number; h: number };

// Zoom sensitivity. Tuned so a single mouse-wheel "notch" (deltaY ≈ 100 px on
// most browsers) zooms by ~13%, while a small trackpad-swipe event (deltaY ≈ 4
// px) only nudges the zoom by ~0.5%. Without per-event deltaY scaling, trackpads
// fire ~60 events/sec and the zoom feels uncontrollable.
const ZOOM_SENSITIVITY = 0.0013;
// Clamp per-event factor — protects against pathological deltas (DOM_DELTA_PAGE,
// browser quirks) suddenly jumping zoom level by orders of magnitude.
const ZOOM_FACTOR_CLAMP = 1.5;

export function useSvgZoomPan(
  svgRef: RefObject<SVGSVGElement>,
  natural: ViewBox,
  enabled: boolean,
  maxZoom = 20,
  // minZoom < 1 lets the viewBox grow beyond natural — useful for adding
  // breathing room around the contents. 0.33 → up to 3× zoom-out.
  minZoom = 0.33,
) {
  const [vb, setVb] = useState<ViewBox>(natural);
  const vbRef = useRef(vb);
  vbRef.current = vb;

  // Reset whenever the natural viewBox changes (e.g. switching planets, or
  // sibling data arriving asynchronously and resizing the canvas).
  useEffect(() => {
    setVb(natural);
  }, [natural.x, natural.y, natural.w, natural.h]);

  const reset = useCallback(() => setVb(natural), [natural.x, natural.y, natural.w, natural.h]);

  // Wheel zoom — anchored on the cursor so the point under the pointer stays
  // put in screen space. Native listener (not React onWheel) so we can call
  // preventDefault and stop the page scrolling behind the modal.
  useEffect(() => {
    const svg = svgRef.current;
    if (!svg || !enabled) return;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const cur = vbRef.current;
      const rect = svg.getBoundingClientRect();
      // Cursor in viewBox units
      const cx = cur.x + ((e.clientX - rect.left) / rect.width) * cur.w;
      const cy = cur.y + ((e.clientY - rect.top) / rect.height) * cur.h;
      // Normalize deltaY to pixels — most browsers send DOM_DELTA_PIXEL (0),
      // but some send DOM_DELTA_LINE (1) or DOM_DELTA_PAGE (2).
      const deltaPx = e.deltaY * (e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? 400 : 1);
      // Negative deltaY (scroll up) → factor < 1 → zoom in.
      const rawFactor = Math.exp(deltaPx * ZOOM_SENSITIVITY);
      const factor = Math.max(1 / ZOOM_FACTOR_CLAMP, Math.min(ZOOM_FACTOR_CLAMP, rawFactor));
      const minW = natural.w / maxZoom;
      const maxW = natural.w / minZoom;
      const newW = Math.max(minW, Math.min(maxW, cur.w * factor));
      if (newW === cur.w) return;
      const ratio = newW / cur.w;
      const newH = cur.h * ratio;
      const newX = cx - (cx - cur.x) * ratio;
      const newY = cy - (cy - cur.y) * ratio;
      setVb({ x: newX, y: newY, w: newW, h: newH });
    };
    svg.addEventListener('wheel', onWheel, { passive: false });
    return () => svg.removeEventListener('wheel', onWheel);
  }, [svgRef, enabled, natural.w, natural.h, maxZoom, minZoom]);

  // Pan — pointer drag translates the viewBox in the opposite direction.
  const dragRef = useRef<{ startX: number; startY: number; vbX: number; vbY: number } | null>(null);
  const onPointerDown = useCallback(
    (e: React.PointerEvent<SVGSVGElement>) => {
      if (!enabled) return;
      // Only initiate panning on primary button drags
      if (e.button !== 0) return;
      (e.currentTarget as SVGSVGElement).setPointerCapture(e.pointerId);
      dragRef.current = {
        startX: e.clientX,
        startY: e.clientY,
        vbX: vbRef.current.x,
        vbY: vbRef.current.y,
      };
    },
    [enabled],
  );
  const onPointerMove = useCallback((e: React.PointerEvent<SVGSVGElement>) => {
    const drag = dragRef.current;
    const svg = svgRef.current;
    if (!drag || !svg) return;
    const rect = svg.getBoundingClientRect();
    const cur = vbRef.current;
    const dx = (e.clientX - drag.startX) * (cur.w / rect.width);
    const dy = (e.clientY - drag.startY) * (cur.h / rect.height);
    setVb({ x: drag.vbX - dx, y: drag.vbY - dy, w: cur.w, h: cur.h });
  }, [svgRef]);
  const onPointerUp = useCallback((e: React.PointerEvent<SVGSVGElement>) => {
    if (dragRef.current) {
      try { (e.currentTarget as SVGSVGElement).releasePointerCapture(e.pointerId); } catch { /* noop */ }
    }
    dragRef.current = null;
  }, []);
  const onDoubleClick = useCallback(() => reset(), [reset]);

  const zoomLevel = natural.w / vb.w;

  // Programmatic zoom-to-level — zooms from the current viewBox center so
  // panning position is preserved. Used by the zoom slider.
  const zoomToLevel = useCallback((level: number) => {
    const clamped = Math.max(minZoom, Math.min(maxZoom, level));
    setVb((cur) => {
      const newW = natural.w / clamped;
      const newH = natural.h / clamped;
      const cx = cur.x + cur.w / 2;
      const cy = cur.y + cur.h / 2;
      return { x: cx - newW / 2, y: cy - newH / 2, w: newW, h: newH };
    });
  }, [natural.w, natural.h, minZoom, maxZoom]);

  return {
    viewBox: `${vb.x} ${vb.y} ${vb.w} ${vb.h}`,
    zoomLevel,
    isZoomed: Math.abs(zoomLevel - 1) > 0.001,
    handlers: {
      onPointerDown,
      onPointerMove,
      onPointerUp,
      onPointerCancel: onPointerUp,
      onDoubleClick,
    },
    reset,
    zoomToLevel,
    isPanning: () => dragRef.current !== null,
  };
}
