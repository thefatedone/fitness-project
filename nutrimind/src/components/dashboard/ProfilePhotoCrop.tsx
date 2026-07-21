"use client";
import { useState, useRef, useCallback, useEffect, useMemo } from "react";
import { X, Check, Upload, ZoomIn, ZoomOut, Maximize2 } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";

interface ProfilePhotoCropProps {
  isOpen: boolean;
  onClose: () => void;
  onCropped: (base64: string) => void;
  currentPhoto?: string | null;
}

// The fixed crop circle. The image inside is sized & positioned to fit/cover it.
const CIRCLE_SIZE = 280;          // px, CSS
const FRAME_SIZE = 320;           // outer square frame, px, CSS
const OUTPUT_SIZE = 400;          // exported JPEG, px
const MIN_ZOOM = 1;               // at 1x, image's shorter side == circle diameter
const MAX_ZOOM = 3;

type NaturalSize = { width: number; height: number };
type Vec2 = { x: number; y: number };

/**
 * Compute the natural-image source rect that maps to the visible circle, then
 * rasterise it to OUTPUT_SIZE × OUTPUT_SIZE. Honors the live pan + zoom.
 */
function exportCroppedImg(
  image: HTMLImageElement,
  natural: NaturalSize,
  pan: Vec2,
  zoom: number,
  fitBaseW: number
): string {
  const canvas = document.createElement("canvas");
  canvas.width = OUTPUT_SIZE;
  canvas.height = OUTPUT_SIZE;
  const ctx = canvas.getContext("2d")!;

  // Render-fitting size at zoom=1 (= CIRCLE_SIZE for the shorter side)
  // fitBaseW is exactly that base width — used to recover the scale factor.
  const renderedW = fitBaseW * zoom;
  const scale = renderedW / natural.width;                       // CSS → image px

  // The circle is fixed at (CIRCLE_SIZE/2, CIRCLE_SIZE/2) in container coords.
  // The image's top-left sits at bgPos = (CIRCLE_SIZE/2 − rendered/2 − pan).
  // So the image-space point currently under the circle center is:
  //   (CIRCLE_SIZE/2 − bgPos) / scale = (renderedW/2 + pan) / scale
  const cxImg = (renderedW / 2 + pan.x) / scale;
  const cyImg = ((fitBaseW * zoom) * (natural.height / natural.width) / 2 + pan.y) / scale;
  const rImg = (CIRCLE_SIZE / 2) / scale;                         // circle radius, image space

  // Bounding box clamped to image bounds.
  const sx = Math.max(0, Math.min(natural.width  - 2 * rImg, cxImg - rImg));
  const sy = Math.max(0, Math.min(natural.height - 2 * rImg, cyImg - rImg));
  const sw = Math.min(2 * rImg, natural.width  - sx);
  const sh = Math.min(2 * rImg, natural.height - sy);

  // Pad transparent edges with neutral dark so the resulting square looks balanced
  // even if the circle clip is unusually near a corner of the source image.
  ctx.fillStyle = "#111111";
  ctx.fillRect(0, 0, OUTPUT_SIZE, OUTPUT_SIZE);
  ctx.drawImage(image, sx, sy, sw, sh, 0, 0, OUTPUT_SIZE, OUTPUT_SIZE);

  return canvas.toDataURL("image/jpeg", 0.9);
}

async function resizeImage(file: File, maxDim: number = 1600): Promise<string> {
  // Downscale huge uploads so the browser doesn't choke on a 12-MP background image.
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement("canvas");
        let { width, height } = img;
        if (width > height && width > maxDim) {
          height = (height * maxDim) / width;
          width = maxDim;
        } else if (height > maxDim) {
          width = (width * maxDim) / height;
          height = maxDim;
        }
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d")!;
        ctx.drawImage(img, 0, 0, width, height);
        resolve(canvas.toDataURL("image/jpeg", 0.92));
      };
      img.onerror = reject;
      img.src = e.target?.result as string;
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

export default function ProfilePhotoCrop({
  isOpen,
  onClose,
  onCropped,
  currentPhoto,
}: ProfilePhotoCropProps) {
  // -------- multi-step state --------
  const [step, setStep] = useState<"select" | "crop">("select");
  const [imageSrc, setImageSrc] = useState<string | null>(null);
  const [natural, setNatural] = useState<NaturalSize | null>(null);

  // -------- crop state (YouTube-style) --------
  const [pan, setPan] = useState<Vec2>({ x: 0, y: 0 });          // image-center offset, CSS px
  const [zoom, setZoom] = useState(1);                           // 1..MAX_ZOOM
  const [isUploading, setIsUploading] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [isDragOver, setIsDragOver] = useState(false);

  // Refs
  const fileInputRef = useRef<HTMLInputElement>(null);
  const dropRef = useRef<HTMLDivElement>(null);
  const frameRef = useRef<HTMLDivElement>(null);
  const imgElRef = useRef<HTMLImageElement | null>(null);

  // Pointer / pinch state lives in a ref so React doesn't re-render per pixel of movement
  type DragState = {
    pointers: Map<number, Vec2>;       // active pointerId → container-space coords
    panAtStart: Vec2;                  // pan at gesture start
    downAt: Vec2;                      // pointer position when this pointer went down (for delta)
    pinchStartDist: number;            // |p0 − p1| at gesture start
    pinchStartZoom: number;
    pinchCenter: Vec2;                 // midpoint of two pointers (container space)
    pinchPanStart: Vec2;               // pan at gesture start (for zoom anchoring)
  };
  const dragRef = useRef<DragState | null>(null);

  // ================== derived: rendered image fit ==================
  // At zoom=1 the image's shorter side == circle diameter (per spec).
  const fitBase = useMemo(() => {
    if (!natural) return null;
    const { width: W, height: H } = natural;
    if (W >= H) {
      // wider → height is the short side
      const fitH = CIRCLE_SIZE;
      const fitW = (W / H) * fitH;
      return { width: fitW, height: fitH, scale: fitW / W };
    } else {
      const fitW = CIRCLE_SIZE;
      const fitH = (H / W) * fitW;
      return { width: fitW, height: fitH, scale: fitW / W };
    }
  }, [natural]);

  const rendered = useMemo(() => {
    if (!fitBase) return null;
    return { width: fitBase.width * zoom, height: fitBase.height * zoom };
  }, [fitBase, zoom]);

  // background-position of the image's top-left in container (CSS px)
  //   image center = bgPos + renderedSize/2
  //   we want image center = (CIRCLE_SIZE/2 - pan.x, CIRCLE_SIZE/2 - pan.y)
  //   ⇒ bgPos.x = CIRCLE_SIZE/2 - rendered.width/2 - pan.x
  // (note the sign flip — positive pan.x means the IMAGE shifts in +x,
  // which means the bgPosition shifts in -x to keep the visible center fixed)
  const bgPos = useMemo<Vec2 | null>(() => {
    if (!rendered) return null;
    return {
      x: CIRCLE_SIZE / 2 - rendered.width  / 2 - pan.x,
      y: CIRCLE_SIZE / 2 - rendered.height / 2 - pan.y,
    };
  }, [rendered, pan]);

  // Max legal pan at the current zoom — keeps the image always covering the circle.
  const panBounds = useMemo<Vec2>(() => {
    if (!rendered) return { x: 0, y: 0 };
    return {
      x: Math.max(0, (rendered.width  - CIRCLE_SIZE) / 2),
      y: Math.max(0, (rendered.height - CIRCLE_SIZE) / 2),
    };
  }, [rendered]);

  const clampPan = useCallback((p: Vec2): Vec2 => ({
    x: Math.max(-panBounds.x, Math.min(panBounds.x, p.x)),
    y: Math.max(-panBounds.y, Math.min(panBounds.y, p.y)),
  }), [panBounds]);

  // ================== file flow (unchanged shape, lighter resize) ==================
  const startCropWith = useCallback((dataUrl: string) => {
    setImageSrc(dataUrl);
    const probe = new Image();
    probe.onload = () => {
      setNatural({ width: probe.naturalWidth, height: probe.naturalHeight });
      setPan({ x: 0, y: 0 });
      setZoom(1);
      setStep("crop");
    };
    probe.src = dataUrl;
  }, []);

  const processFile = useCallback(async (file: File) => {
    if (!file.type.startsWith("image/")) return;
    const dataUrl = await resizeImage(file);
    startCropWith(dataUrl);
  }, [startCropWith]);

  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) processFile(file);
  }, [processFile]);

  // drag-and-drop on the select step
  useEffect(() => {
    if (step !== "select") return;
    const node = dropRef.current;
    if (!node) return;
    const onEnter = (e: DragEvent) => { e.preventDefault(); setIsDragOver(true); };
    const onLeave = (e: DragEvent) => { e.preventDefault(); setIsDragOver(false); };
    const onOver  = (e: DragEvent) => { e.preventDefault(); };
    const onDrop  = (e: DragEvent) => {
      e.preventDefault();
      setIsDragOver(false);
      const f = e.dataTransfer?.files?.[0];
      if (f) processFile(f);
    };
    node.addEventListener("dragenter", onEnter);
    node.addEventListener("dragleave", onLeave);
    node.addEventListener("dragover",  onOver);
    node.addEventListener("drop",      onDrop);
    return () => {
      node.removeEventListener("dragenter", onEnter);
      node.removeEventListener("dragleave", onLeave);
      node.removeEventListener("dragover",  onOver);
      node.removeEventListener("drop",      onDrop);
    };
  }, [step, processFile]);

  // ================== pointer / pinch / zoom ==================
  const containerPoint = useCallback((clientX: number, clientY: number): Vec2 => {
    const rect = frameRef.current?.getBoundingClientRect();
    if (!rect) return { x: 0, y: 0 };
    // Translate viewport coords → container-relative coords, then scale to the
    // rendered CSS px of the inner CIRCLE_SIZE box (frame may be scaled by DPR/CSS zoom).
    const scale = CIRCLE_SIZE / rect.width;
    return {
      x: (clientX - rect.left) * scale,
      y: (clientY - rect.top)  * scale,
    };
  }, []);

  const onPointerDown = (e: React.PointerEvent) => {
    if (!rendered || e.button !== undefined && e.button !== 0) return;
    (e.target as Element).setPointerCapture?.(e.pointerId);

    const pt = containerPoint(e.clientX, e.clientY);

    // Second pointer while one is already down → upgrade to pinch.
    const existing = dragRef.current;
    if (existing && existing.pointers.size >= 1) {
      existing.pointers.set(e.pointerId, pt);
      const [a, b] = Array.from(existing.pointers.values());
      existing.pinchStartDist = Math.hypot(b.x - a.x, b.y - a.y);
      existing.pinchStartZoom = zoom;
      existing.pinchCenter = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
      existing.pinchPanStart = { ...pan };
      return;
    }

    // First pointer → start a single-pointer drag.
    const pointers = new Map<number, Vec2>();
    pointers.set(e.pointerId, pt);
    dragRef.current = {
      pointers,
      panAtStart: { ...pan },
      downAt: { ...pt },
      pinchStartDist: 0,
      pinchStartZoom: zoom,
      pinchCenter: pt,
      pinchPanStart: { ...pan },
    };
    setIsDragging(true);
  };

  const onPointerMove = (e: React.PointerEvent) => {
    const state = dragRef.current;
    if (!state) return;
    const pt = containerPoint(e.clientX, e.clientY);
    state.pointers.set(e.pointerId, pt);

    // ----- pinch: 2+ pointers -----
    if (state.pointers.size >= 2) {
      const [a, b] = Array.from(state.pointers.values());
      const dist = Math.hypot(b.x - a.x, b.y - a.y);
      if (state.pinchStartDist > 0 && dist > 0) {
        const k = dist / state.pinchStartDist;
        const targetZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, state.pinchStartZoom * k));
        applyZoom(state.pinchCenter, state.pinchPanStart, state.pinchStartZoom, targetZoom);
      }
      return;
    }

    // ----- single-pointer drag -----
    setPan(clampPan({
      x: state.panAtStart.x + (pt.x - state.downAt.x),
      y: state.panAtStart.y + (pt.y - state.downAt.y),
    }));
  };

  const onPointerEnd = (e: React.PointerEvent) => {
    const state = dragRef.current;
    if (!state) return;
    state.pointers.delete(e.pointerId);
    if (state.pointers.size === 0) {
      dragRef.current = null;
      setIsDragging(false);
    } else if (state.pointers.size === 1) {
      // Downgraded from pinch to single-pointer drag: capture fresh reference.
      const [only] = Array.from(state.pointers.values());
      state.panAtStart = { ...pan };
      state.downAt = { ...only };
      state.pinchStartDist = 0;
    }
  };

  /**
   * Apply a new zoom anchored at `anchor` (container-space coords). The image-
   * space point under the anchor stays under the anchor after the change.
   *
   * Derivation: with bgPos.x = CIRCLE_SIZE/2 − rendered.w/2 − pan.x and
   *   scale = rendered.w / naturalW, the image-space point under anchor is
   *   (anchor − bgPos) / scale. Setting that equal before & after a zoom factor
   *   k collapses to:
   *     newPan = (CIRCLE_SIZE/2 − anchor) · (1 − k) + panAtStart · k
   */
  const applyZoom = useCallback((
    anchor: Vec2,
    panAtStart: Vec2,
    zoomAtStart: number,
    targetZoom: number,
  ) => {
    if (zoomAtStart <= 0) return;
    const k = targetZoom / zoomAtStart;
    const c = CIRCLE_SIZE / 2;
    const newPan: Vec2 = {
      x: (c - anchor.x) * (1 - k) + panAtStart.x * k,
      y: (c - anchor.y) * (1 - k) + panAtStart.y * k,
    };
    setZoom(targetZoom);
    setPan(clampPan(newPan));
  }, [clampPan]);

  // Wheel zoom — always anchored at the cursor.
  const onWheel = (e: React.WheelEvent) => {
    if (!rendered) return;
    e.preventDefault();
    const anchor = containerPoint(e.clientX, e.clientY);
    // Normalize: scroll down (deltaY > 0) → zoom out
    const intensity = Math.min(Math.max(Math.abs(e.deltaY) / 100, 0.05), 0.5);
    const factor = e.deltaY > 0 ? (1 - intensity * 0.15) : (1 + intensity * 0.15);
    const target = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoom * factor));
    if (target === zoom) return;
    applyZoom(anchor, pan, zoom, target);
  };

  // +/- buttons + slider — anchored at the circle center.
  const bumpZoom = (factor: number) => {
    const target = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoom * factor));
    if (target === zoom) return;
    applyZoom({ x: CIRCLE_SIZE / 2, y: CIRCLE_SIZE / 2 }, pan, zoom, target);
  };

  // ================== confirm / close ==================
  const handleConfirm = async () => {
    if (!imageSrc || !natural || !fitBase) return;
    setIsUploading(true);
    try {
      if (!imgElRef.current) {
        imgElRef.current = new Image();
        imgElRef.current.crossOrigin = "anonymous";
      }
      const img = imgElRef.current;
      if (img.src !== imageSrc) {
        await new Promise<void>((res, rej) => {
          img.onload = () => res();
          img.onerror = () => rej(new Error("image decode failed"));
          img.src = imageSrc;
        });
      }
      const out = exportCroppedImg(img, natural, pan, zoom, fitBase.width);
      onCropped(out);
      handleClose();
    } catch (err) {
      console.error("Crop failed:", err);
    } finally {
      setIsUploading(false);
    }
  };

  const handleClose = () => {
    setStep("select");
    setImageSrc(null);
    setNatural(null);
    setPan({ x: 0, y: 0 });
    setZoom(1);
    dragRef.current = null;
    onClose();
  };

  // ESC closes lightbox / modal
  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        if (lightboxOpen) setLightboxOpen(false);
        else handleClose();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [isOpen, lightboxOpen]); // eslint-disable-line react-hooks/exhaustive-deps

  const triggerFileInput = () => fileInputRef.current?.click();

  return (
    <>
      {/* Full-size photo lightbox */}
      <AnimatePresence>
        {lightboxOpen && currentPhoto && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[60] flex items-center justify-center bg-black/95 backdrop-blur-sm"
            onClick={() => setLightboxOpen(false)}
          >
            <motion.div
              initial={{ scale: 0.96 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0.96 }}
              className="relative max-w-4xl max-h-[90vh] w-full"
              onClick={(e) => e.stopPropagation()}
            >
              <img src={currentPhoto} alt="Full size" className="w-full h-full object-contain rounded-2xl" />
              <button
                onClick={() => setLightboxOpen(false)}
                className="absolute top-4 right-4 p-3 bg-black/50 hover:bg-black/70 rounded-full text-white transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
              <p className="text-center text-gray-400 text-sm mt-4">Click outside to close</p>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main modal */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4"
          >
            <motion.div
              initial={{ scale: 0.94, opacity: 0, y: 8 }}
              animate={{ scale: 1,   opacity: 1, y: 0 }}
              exit={{    scale: 0.96, opacity: 0 }}
              transition={{ type: "spring", damping: 28, stiffness: 320 }}
              className="bg-[#111111] border border-[#1a1a1a] rounded-2xl w-full max-w-lg overflow-hidden shadow-[0_24px_60px_-20px_rgba(0,0,0,0.7)]"
            >
              {/* Header */}
              <div className="flex items-center justify-between px-6 py-4 border-b border-[#1a1a1a]">
                <div>
                  <h2 className="text-white font-semibold tracking-tight">
                    {step === "select" ? "Profile Photo" : "Adjust Photo"}
                  </h2>
                  {step === "crop" && (
                    <p className="text-xs text-gray-500 mt-0.5">
                      Drag to reposition &nbsp;·&nbsp; Scroll or pinch to zoom
                    </p>
                  )}
                </div>
                <button
                  onClick={handleClose}
                  className="p-2 text-gray-400 hover:text-white rounded-lg hover:bg-white/5 transition-colors"
                  aria-label="Close"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Body */}
              <div className="p-6">
                {step === "select" && (
                  <SelectStep
                    currentPhoto={currentPhoto}
                    dropRef={dropRef}
                    isDragOver={isDragOver}
                    onLightbox={() => setLightboxOpen(true)}
                    onChoose={triggerFileInput}
                  />
                )}

                {step === "crop" && imageSrc && rendered && bgPos && fitBase && (
                  <CropStep
                    frameRef={frameRef}
                    imageSrc={imageSrc}
                    rendered={rendered}
                    bgPos={bgPos}
                    zoom={zoom}
                    isDragging={isDragging}
                    onPointerDown={onPointerDown}
                    onPointerMove={onPointerMove}
                    onPointerUp={onPointerEnd}
                    onPointerCancel={onPointerEnd}
                    onWheel={onWheel}
                    onZoomIn={() => bumpZoom(1.2)}
                    onZoomOut={() => bumpZoom(1 / 1.2)}
                    onSliderChange={(v) => {
                      const target = MIN_ZOOM + (MAX_ZOOM - MIN_ZOOM) * v;
                      if (target === zoom) return;
                      applyZoom({ x: CIRCLE_SIZE / 2, y: CIRCLE_SIZE / 2 }, pan, zoom, target);
                    }}
                    onCancel={handleClose}
                    onConfirm={handleConfirm}
                    isUploading={isUploading}
                  />
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        onChange={handleFileSelect}
        className="hidden"
      />
    </>
  );
}

// ============================================================================
// Select step (kept as-is conceptually; extracted for clarity)
// ============================================================================

function SelectStep({
  currentPhoto,
  dropRef,
  isDragOver,
  onLightbox,
  onChoose,
}: {
  currentPhoto?: string | null;
  dropRef: React.RefObject<HTMLDivElement | null>;
  isDragOver: boolean;
  onLightbox: () => void;
  onChoose: () => void;
}) {
  return (
    <div className="flex flex-col items-center gap-6">
      {currentPhoto && (
        <div className="flex flex-col items-center gap-3">
          <button
            type="button"
            onClick={onLightbox}
            className="relative group cursor-pointer"
          >
            <img
              src={currentPhoto}
              alt="Current"
              className="w-32 h-32 rounded-full object-cover border-2 border-[#1a1a1a] transition-transform group-hover:scale-105"
            />
            <div className="absolute inset-0 flex items-center justify-center bg-black/50 rounded-full opacity-0 group-hover:opacity-100 transition-opacity">
              <Maximize2 className="w-6 h-6 text-white" />
            </div>
          </button>
          <span className="text-gray-500 text-xs">Click to view full size</span>
        </div>
      )}

      <div
        ref={dropRef}
        onClick={onChoose}
        className={`w-full border-2 border-dashed rounded-2xl p-8 text-center cursor-pointer transition-all ${
          isDragOver
            ? "border-green-500 bg-green-500/10"
            : "border-[#2a2a2a] hover:border-green-500/50 hover:bg-green-500/5"
        }`}
      >
        <div className="flex flex-col items-center gap-3">
          <div className={`w-16 h-16 rounded-full bg-[#1a1a1a] flex items-center justify-center ${isDragOver ? "bg-green-500/20" : ""}`}>
            <Upload className={`w-8 h-8 ${isDragOver ? "text-green-400" : "text-gray-500"}`} />
          </div>
          <div>
            <p className="text-white font-medium">
              {isDragOver ? "Drop image here" : "Drag & drop or click to upload"}
            </p>
            <p className="text-gray-500 text-sm mt-1">JPG or PNG up to 5MB</p>
          </div>
        </div>
      </div>

      <div className="flex gap-3 w-full">
        {currentPhoto && (
          <button
            type="button"
            onClick={onLightbox}
            className="flex-1 py-3 rounded-xl bg-[#1a1a1a] text-gray-400 font-medium hover:bg-[#2a2a2a] transition-colors flex items-center justify-center gap-2"
          >
            <Maximize2 className="w-4 h-4" />
            View Full
          </button>
        )}
        <button
          type="button"
          onClick={onChoose}
          className="flex-1 py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] active:scale-[0.98] transition-all flex items-center justify-center gap-2"
        >
          <Upload className="w-4 h-4" />
          Choose File
        </button>
      </div>
    </div>
  );
}

// ============================================================================
// Crop step — circular, fixed-size clip with a free-floating image underneath
// ============================================================================

function CropStep({
  frameRef,
  imageSrc,
  rendered,
  bgPos,
  zoom,
  isDragging,
  onPointerDown,
  onPointerMove,
  onPointerUp,
  onPointerCancel,
  onWheel,
  onZoomIn,
  onZoomOut,
  onSliderChange,
  onCancel,
  onConfirm,
  isUploading,
}: {
  frameRef: React.RefObject<HTMLDivElement | null>;
  imageSrc: string;
  rendered: { width: number; height: number };
  bgPos: Vec2;
  zoom: number;
  isDragging: boolean;
  onPointerDown: React.PointerEventHandler<HTMLDivElement>;
  onPointerMove: React.PointerEventHandler<HTMLDivElement>;
  onPointerUp: React.PointerEventHandler<HTMLDivElement>;
  onPointerCancel: React.PointerEventHandler<HTMLDivElement>;
  onWheel: React.WheelEventHandler<HTMLDivElement>;
  onZoomIn: () => void;
  onZoomOut: () => void;
  onSliderChange: (v: number) => void; // 0..1
  onCancel: () => void;
  onConfirm: () => void;
  isUploading: boolean;
}) {
  return (
    <div className="flex flex-col gap-5">
      {/* Fixed-size square frame. The image lives at the bottom of the stack; an
          overlay above it (CSS-masked) darkens the area outside the circle so the
          user sees exactly what the avatar will be. */}
      <div className="flex justify-center">
        <div
          ref={frameRef}
          style={{ width: FRAME_SIZE, height: FRAME_SIZE }}
          className="relative rounded-2xl bg-[#0a0a0a] overflow-hidden select-none touch-none ring-1 ring-[#1a1a1a]"
        >
          {/* Transparent hit-test layer for wheel + pointer on the entire frame */}
          <div
            className="absolute inset-0 z-30 cursor-grab active:cursor-grabbing"
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerCancel}
            onWheel={onWheel}
          />

          {/* The image — background-position / size driven by pan + zoom.
              Painted behind everything else, scrolling disabled. */}
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              backgroundImage: `url("${imageSrc}")`,
              backgroundRepeat: "no-repeat",
              backgroundSize: `${rendered.width}px ${rendered.height}px`,
              backgroundPosition: `${bgPos.x}px ${bgPos.y}px`,
              willChange: "background-position, background-size",
              transition: isDragging ? "none" : "background-position 80ms linear",
            }}
          />

          {/* Dark mask — transparent inside the circle, opaque outside, so
              anything outside the crop region is visibly de-emphasized. */}
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              backgroundColor: "rgba(0,0,0,0.55)",
              WebkitMaskImage:
                "radial-gradient(circle at center, transparent 0 calc(50% - 0.5px), black calc(50% + 0.5px))",
              maskImage:
                "radial-gradient(circle at center, transparent 0 calc(50% - 0.5px), black calc(50% + 0.5px))",
            }}
          />

          {/* Hairline ring around the crop area */}
          <div
            className="absolute inset-0 pointer-events-none rounded-full"
            style={{
              width: CIRCLE_SIZE,
              height: CIRCLE_SIZE,
              top: (FRAME_SIZE - CIRCLE_SIZE) / 2,
              left: (FRAME_SIZE - CIRCLE_SIZE) / 2,
              boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.06), 0 0 0 1px rgba(34,197,94,0.25)",
            }}
          />
        </div>
      </div>

      {/* Slider + -/+ controls (anchored at center for predictability) */}
      <div className="flex items-center gap-3 px-2">
        <button
          type="button"
          onClick={onZoomOut}
          aria-label="Zoom out"
          className="p-2 rounded-lg text-gray-400 hover:text-white hover:bg-white/5 transition-colors active:scale-95"
        >
          <ZoomOut className="w-4 h-4" />
        </button>
        <input
          type="range"
          min={0}
          max={1}
          step={0.005}
          value={(zoom - MIN_ZOOM) / (MAX_ZOOM - MIN_ZOOM)}
          onChange={(e) => onSliderChange(parseFloat(e.target.value))}
          aria-label="Zoom"
          className="flex-1 accent-[#22c55e] cursor-pointer"
          style={{ height: 4 }}
        />
        <button
          type="button"
          onClick={onZoomIn}
          aria-label="Zoom in"
          className="p-2 rounded-lg text-gray-400 hover:text-white hover:bg-white/5 transition-colors active:scale-95"
        >
          <ZoomIn className="w-4 h-4" />
        </button>
      </div>

      {/* Cancel + Apply (Skip Crop removed — default crop is good enough) */}
      <div className="flex gap-3">
        <button
          type="button"
          onClick={onCancel}
          className="flex-1 py-3 rounded-xl bg-[#1a1a1a] text-gray-400 font-medium hover:bg-[#2a2a2a] transition-colors active:scale-[0.99]"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={onConfirm}
          disabled={isUploading}
          className="flex-1 py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] disabled:opacity-50 active:scale-[0.99] transition-all flex items-center justify-center gap-2"
        >
          {isUploading ? (
            <span className="w-4 h-4 border-2 border-black/30 border-t-black rounded-full animate-spin" />
          ) : (
            <>
              <Check className="w-4 h-4" />
              Apply
            </>
          )}
        </button>
      </div>
    </div>
  );
}
