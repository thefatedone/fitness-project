"use client";
import { useState, useRef, useCallback, useEffect } from "react";
import ReactCrop, { Crop, PixelCrop } from "react-image-crop";
import { X, RotateCw, Check, Upload, ZoomIn, ZoomOut, Maximize2, Trash2 } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import "react-image-crop/dist/ReactCrop.css";

interface ProfilePhotoCropProps {
  isOpen: boolean;
  onClose: () => void;
  onCropped: (base64: string) => void;
  currentPhoto?: string | null;
}

async function getCroppedImg(
  image: HTMLImageElement,
  crop: PixelCrop,
  rotation: number
): Promise<string> {
  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d")!;

  const maxDim = 400;
  const minDim = Math.min(image.width, image.height);
  const sourceSize = minDim;
  const sx = (image.width - sourceSize) / 2;
  const sy = (image.height - sourceSize) / 2;

  canvas.width = maxDim;
  canvas.height = maxDim;

  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, maxDim, maxDim);

  ctx.save();
  ctx.translate(maxDim / 2, maxDim / 2);
  ctx.rotate((rotation * Math.PI) / 180);
  ctx.translate(-maxDim / 2, -maxDim / 2);
  ctx.drawImage(image, sx, sy, sourceSize, sourceSize, 0, 0, maxDim, maxDim);
  ctx.restore();

  return canvas.toDataURL("image/jpeg", 0.9);
}

async function resizeImage(file: File, maxDim: number = 800): Promise<string> {
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
        resolve(canvas.toDataURL("image/jpeg", 0.9));
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
  const [step, setStep] = useState<"select" | "crop">("select");
  const [imageSrc, setImageSrc] = useState<string | null>(null);
  const [previewSrc, setPreviewSrc] = useState<string | null>(null);
  const [crop, setCrop] = useState<Crop>();
  const [rotation, setRotation] = useState(0);
  const [isUploading, setIsUploading] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [isDragging, setIsDragging] = useState(false);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const dropRef = useRef<HTMLDivElement>(null);

  // Drag and drop handlers
  const handleDragEnter = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
  }, []);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);

    const files = e.dataTransfer.files;
    if (files.length > 0) {
      processFile(files[0]);
    }
  }, []);

  const processFile = useCallback((file: File) => {
    if (!file.type.startsWith("image/")) return;

    const reader = new FileReader();
    reader.onload = (ev) => {
      const dataUrl = ev.target?.result as string;
      setImageSrc(dataUrl);
      setPreviewSrc(dataUrl);
      setStep("crop");
      setRotation(0);
      setZoom(1);
    };
    reader.readAsDataURL(file);
  }, []);

  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    processFile(file);
  }, [processFile]);

  const handleCropComplete = useCallback((c: Crop) => {
    if (!c.width || !c.height || !imgRef.current) return;
    setCrop(c);
  }, []);

  const handleConfirm = async () => {
    setIsUploading(true);
    try {
      let result: string;

      if (crop && crop.width && crop.height && imgRef.current) {
        // Use cropped version
        result = await getCroppedImg(
          imgRef.current,
          { unit: "px", x: crop.x, y: crop.y, width: crop.width, height: crop.height } as PixelCrop,
          rotation
        );
      } else {
        // No crop, use preview as-is
        result = previewSrc || imageSrc || "";
      }

      onCropped(result);
      handleClose();
    } catch (err) {
      console.error("Crop failed:", err);
    } finally {
      setIsUploading(false);
    }
  };

  const handleSkipCrop = async () => {
    if (!previewSrc && !imageSrc) return;
    setIsUploading(true);
    try {
      onCropped(previewSrc || imageSrc || "");
      handleClose();
    } catch (err) {
      console.error("Upload failed:", err);
    } finally {
      setIsUploading(false);
    }
  };

  const handleClose = () => {
    setStep("select");
    setImageSrc(null);
    setPreviewSrc(null);
    setRotation(0);
    setZoom(1);
    setCrop(undefined);
    onClose();
  };

  const triggerFileInput = () => {
    fileInputRef.current?.click();
  };

  // Close lightbox on escape
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape" && lightboxOpen) {
        setLightboxOpen(false);
      }
    };
    window.addEventListener("keydown", handleEsc);
    return () => window.removeEventListener("keydown", handleEsc);
  }, [lightboxOpen]);

  return (
    <>
      {/* Lightbox for viewing full-size photo */}
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
              initial={{ scale: 0.9 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0.9 }}
              className="relative max-w-4xl max-h-[90vh] w-full"
              onClick={(e) => e.stopPropagation()}
            >
              <img
                src={currentPhoto}
                alt="Full size"
                className="w-full h-full object-contain rounded-2xl"
              />
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

      {/* Main upload modal */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4"
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              transition={{ type: "spring", damping: 25, stiffness: 300 }}
              className="bg-[#111111] border border-[#1a1a1a] rounded-2xl w-full max-w-lg overflow-hidden"
            >
              {/* Header */}
              <div className="flex items-center justify-between px-6 py-4 border-b border-[#1a1a1a]">
                <h2 className="text-white font-semibold">
                  {step === "select" ? "Profile Photo" : "Adjust Photo"}
                </h2>
                <button
                  onClick={handleClose}
                  className="p-2 text-gray-400 hover:text-white rounded-lg hover:bg-white/5 transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Body */}
              <div className="p-6">
                {step === "select" && (
                  <div className="flex flex-col items-center gap-6">
                    {/* Current photo preview */}
                    {currentPhoto && (
                      <div className="flex flex-col items-center gap-3">
                        <div
                          className="relative group cursor-pointer"
                          onClick={() => setLightboxOpen(true)}
                        >
                          <img
                            src={currentPhoto}
                            alt="Current"
                            className="w-32 h-32 rounded-full object-cover border-2 border-[#1a1a1a] transition-transform group-hover:scale-105"
                          />
                          <div className="absolute inset-0 flex items-center justify-center bg-black/50 rounded-full opacity-0 group-hover:opacity-100 transition-opacity">
                            <Maximize2 className="w-6 h-6 text-white" />
                          </div>
                        </div>
                        <span className="text-gray-500 text-xs">Click to view full size</span>
                      </div>
                    )}

                    {/* Hidden file input */}
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      onChange={handleFileSelect}
                      className="hidden"
                    />

                    {/* Drop zone */}
                    <div
                      ref={dropRef}
                      onDragEnter={handleDragEnter}
                      onDragLeave={handleDragLeave}
                      onDragOver={handleDragOver}
                      onDrop={handleDrop}
                      onClick={triggerFileInput}
                      className={`w-full border-2 border-dashed rounded-2xl p-8 text-center cursor-pointer transition-all ${
                        isDragging
                          ? "border-green-500 bg-green-500/10"
                          : "border-[#2a2a2a] hover:border-green-500/50 hover:bg-green-500/5"
                      }`}
                    >
                      <div className="flex flex-col items-center gap-3">
                        <div className={`w-16 h-16 rounded-full bg-[#1a1a1a] flex items-center justify-center ${isDragging ? "bg-green-500/20" : ""}`}>
                          <Upload className={`w-8 h-8 ${isDragging ? "text-green-400" : "text-gray-500"}`} />
                        </div>
                        <div>
                          <p className="text-white font-medium">
                            {isDragging ? "Drop image here" : "Drag & drop or click to upload"}
                          </p>
                          <p className="text-gray-500 text-sm mt-1">JPG, PNG or GIF up to 5MB</p>
                        </div>
                      </div>
                    </div>

                    {/* Quick actions */}
                    <div className="flex gap-3 w-full">
                      {currentPhoto && (
                        <button
                          onClick={() => setLightboxOpen(true)}
                          className="flex-1 py-3 rounded-xl bg-[#1a1a1a] text-gray-400 font-medium hover:bg-[#2a2a2a] transition-colors flex items-center justify-center gap-2"
                        >
                          <Maximize2 className="w-4 h-4" />
                          View Full
                        </button>
                      )}
                      <button
                        onClick={triggerFileInput}
                        className="flex-1 py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] transition-colors flex items-center justify-center gap-2"
                      >
                        <Upload className="w-4 h-4" />
                        Choose File
                      </button>
                    </div>
                  </div>
                )}

                {step === "crop" && imageSrc && (
                  <div className="flex flex-col gap-4">
                    {/* Rotation and zoom controls */}
                    <div className="flex items-center justify-center gap-6">
                      <button
                        onClick={() => setRotation((r) => (r - 90) % 360)}
                        className="p-2 text-gray-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
                        title="Rotate left"
                      >
                        <RotateCw className="w-5 h-5" style={{ transform: "scaleX(-1)" }} />
                      </button>

                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => setZoom((z) => Math.max(0.5, z - 0.25))}
                          className="p-2 text-gray-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
                        >
                          <ZoomOut className="w-5 h-5" />
                        </button>
                        <span className="text-gray-500 text-sm min-w-[60px] text-center">
                          {Math.round(zoom * 100)}%
                        </span>
                        <button
                          onClick={() => setZoom((z) => Math.min(3, z + 0.25))}
                          className="p-2 text-gray-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
                        >
                          <ZoomIn className="w-5 h-5" />
                        </button>
                      </div>

                      <button
                        onClick={() => setRotation((r) => (r + 90) % 360)}
                        className="p-2 text-gray-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
                        title="Rotate right"
                      >
                        <RotateCw className="w-5 h-5" />
                      </button>
                    </div>

                    {/* Crop area */}
                    <div className="flex justify-center overflow-hidden rounded-xl bg-[#1a1a1a] p-2">
                      <ReactCrop
                        crop={crop ?? undefined}
                        onChange={(c) => setCrop(c)}
                        onComplete={handleCropComplete}
                        circularCrop
                        keepSelection
                      >
                        <img
                          ref={imgRef}
                          src={imageSrc}
                          alt="Crop preview"
                          style={{
                            maxHeight: "300px",
                            maxWidth: "100%",
                            transform: `rotate(${rotation}deg) scale(${zoom})`,
                            transition: "transform 0.2s ease",
                          }}
                          crossOrigin="anonymous"
                        />
                      </ReactCrop>
                    </div>

                    <p className="text-gray-500 text-xs text-center">
                      Drag to reposition • Circular area will be your profile picture
                    </p>

                    {/* Actions */}
                    <div className="flex gap-3">
                      <button
                        onClick={handleClose}
                        className="flex-1 py-3 rounded-xl bg-[#1a1a1a] text-gray-400 font-medium hover:bg-[#2a2a2a] transition-colors"
                      >
                        Cancel
                      </button>
                      <button
                        onClick={handleSkipCrop}
                        disabled={isUploading}
                        className="flex-1 py-3 rounded-xl bg-[#2a2a2a] text-gray-400 font-medium hover:bg-[#3a3a3a] transition-colors"
                      >
                        Skip Crop
                      </button>
                      <button
                        onClick={handleConfirm}
                        disabled={isUploading}
                        className="flex-1 py-3 rounded-xl bg-[#22c55e] text-black font-semibold hover:bg-[#16a34a] disabled:opacity-50 transition-all flex items-center justify-center gap-2"
                      >
                        {isUploading ? (
                          <div className="w-4 h-4 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                        ) : (
                          <>
                            <Check className="w-4 h-4" />
                            Apply
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
