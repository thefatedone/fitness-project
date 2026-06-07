"use client"
import { useState, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Camera, Upload, X, Loader2, CheckCircle, AlertCircle, Flame, Beef, Wheat, Droplets } from 'lucide-react'

interface NutritionResult {
food_name: string
calories: number
protein: number
carbs: number
fat: number
fiber: number
quantity: number
unit: string
confidence: 'high' | 'medium' | 'low'
description: string
ingredients?: string[]
}

interface PhotoLogModalProps {
isOpen: boolean
onClose: () => void
onSuccess: () => void
defaultMealType?: string
}

const API = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'

export default function PhotoLogModal({ isOpen, onClose, onSuccess, defaultMealType = 'snack' }: PhotoLogModalProps) {
const [step, setStep] = useState<'upload' | 'analyzing' | 'result' | 'error'>('upload')
const [selectedImage, setSelectedImage] = useState<string | null>(null)
const [selectedFile, setSelectedFile] = useState<File | null>(null)
const [mealType, setMealType] = useState(defaultMealType)
const [result, setResult] = useState<NutritionResult | null>(null)
const [errorMsg, setErrorMsg] = useState('')
const [allergyWarnings, setAllergyWarnings] = useState<string[]>([])
const [showAllergyWarning, setShowAllergyWarning] = useState(false)
const fileInputRef = useRef<HTMLInputElement>(null)

const mealTypes = [
{ value: 'breakfast', label: '🌅 Breakfast' },
{ value: 'lunch', label: '☀️ Lunch' },
{ value: 'dinner', label: '🌆 Dinner' },
{ value: 'snack', label: '🍎 Snack' },
]

const confidenceColors = { high: 'text-green-400', medium: 'text-yellow-400', low: 'text-red-400' }

const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
const file = e.target.files?.[0]
if (!file) return
setSelectedFile(file)
const reader = new FileReader()
reader.onload = (e) => setSelectedImage(e.target?.result as string)
reader.readAsDataURL(file)
}

const handleAnalyze = async () => {
if (!selectedFile) return
setStep('analyzing')
try {
const token = localStorage.getItem('nutrimind_token')
const formData = new FormData()
formData.append('file', selectedFile)
const res = await fetch(`${API}/api/v1/food/recognize-and-log?meal_type=${mealType}`, {
method: 'POST',
headers: { Authorization: `Bearer ${token}` },
body: formData,
})
if (!res.ok) { const err = await res.json(); throw new Error(err.detail || 'Analysis failed') }
const data = await res.json()
setResult(data.nutrition)
if (data.allergy_warning) {
  setErrorMsg('')
  setAllergyWarnings(data.allergy_warning)
  setShowAllergyWarning(true)
}
setStep('result')
} catch (err: any) {
setErrorMsg(err.message || 'Something went wrong')
setStep('error')
}
}

const handleClose = () => {
setStep('upload'); setSelectedImage(null); setSelectedFile(null)
setResult(null); setErrorMsg(''); setAllergyWarnings([]); setShowAllergyWarning(false); onClose()
}

if (!isOpen) return null

return (
<AnimatePresence>
<div className="fixed inset-0 z-50 flex items-center justify-center p-4">
<motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={handleClose} />
<motion.div initial={{ opacity: 0, scale: 0.95, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }}
exit={{ opacity: 0, scale: 0.95, y: 20 }}
className="relative w-full max-w-md bg-[#111111] border border-[#1a1a1a] rounded-2xl p-6 shadow-2xl">
{/* Header */}
<div className="flex items-center justify-between mb-6">
<div className="flex items-center gap-3">
<div className="w-10 h-10 rounded-xl bg-green-500/20 flex items-center justify-center">
<Camera className="w-5 h-5 text-green-400" />
</div>
<div>
<h2 className="text-white font-semibold">Log Food by Photo</h2>
<p className="text-xs text-gray-500">Powered by Gemini AI</p>
</div>
</div>
<button onClick={handleClose} className="p-2 rounded-lg text-gray-500 hover:text-white hover:bg-[#1a1a1a] transition-colors">
<X className="w-5 h-5" />
</button>
</div>


      {/* STEP: Upload */}
      {step === 'upload' && (
        <div className="space-y-4">
          <div>
            <label className="text-xs text-gray-500 mb-2 block">Meal Type</label>
            <div className="grid grid-cols-4 gap-2">
              {mealTypes.map(m => (
                <button key={m.value} onClick={() => setMealType(m.value)}
                  className={`py-2 px-1 rounded-xl text-xs font-medium transition-all text-center
                    ${mealType === m.value ? 'bg-green-500/20 border border-green-500 text-green-400'
                      : 'bg-[#1a1a1a] border border-[#2a2a2a] text-gray-400 hover:border-[#3a3a3a]'}`}>
                  {m.label}
                </button>
              ))}
            </div>
          </div>

          <div onClick={() => fileInputRef.current?.click()}
            className={`relative border-2 border-dashed rounded-2xl cursor-pointer transition-all overflow-hidden
              ${selectedImage ? 'border-green-500/50' : 'border-[#2a2a2a] hover:border-green-500/30'}`}>
            {selectedImage ? (
              <div className="relative">
                <img src={selectedImage} alt="Food" className="w-full h-56 object-cover rounded-xl" />
                <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity rounded-xl">
                  <p className="text-white text-sm font-medium">Click to change photo</p>
                </div>
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12 px-4">
                <div className="w-16 h-16 rounded-2xl bg-[#1a1a1a] flex items-center justify-center mb-4">
                  <Upload className="w-8 h-8 text-gray-500" />
                </div>
                <p className="text-white font-medium mb-1">Upload food photo</p>
                <p className="text-gray-500 text-sm text-center">Take a photo or upload from gallery</p>
              </div>
            )}
          </div>
          <input ref={fileInputRef} type="file" accept="image/*" capture="environment" className="hidden" onChange={handleFileSelect} />

          {selectedImage && (
            <button onClick={handleAnalyze}
              className="w-full py-3 bg-green-500 hover:bg-green-600 text-black font-semibold rounded-xl transition-colors flex items-center justify-center gap-2">
              <Flame className="w-5 h-5" /> Analyze & Log Food
            </button>
          )}
        </div>
      )}

      {/* STEP: Analyzing */}
      {step === 'analyzing' && (
        <div className="flex flex-col items-center justify-center py-12 space-y-4">
          <div className="relative">
            <img src={selectedImage!} alt="Analyzing" className="w-32 h-32 object-cover rounded-2xl opacity-60" />
            <div className="absolute inset-0 flex items-center justify-center bg-black/50 rounded-2xl">
              <Loader2 className="w-10 h-10 text-green-400 animate-spin" />
            </div>
          </div>
          <p className="text-white font-medium">Analyzing your food...</p>
          <p className="text-gray-500 text-sm text-center">Gemini AI is calculating calories, protein, carbs and fat</p>
        </div>
      )}

      {/* STEP: Result */}
      {step === 'result' && result && (
        <div className="space-y-4">
          {/* Allergy Warning Banner */}
          {showAllergyWarning && allergyWarnings.length > 0 && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-6 h-6 text-red-400 flex-shrink-0 mt-0.5" />
                <div className="flex-1">
                  <p className="text-red-400 font-semibold text-sm mb-1">⚠️ Allergy Alert</p>
                  {allergyWarnings.map((warning, i) => (
                    <p key={i} className="text-red-300 text-xs mt-1">{warning}</p>
                  ))}
                  <p className="text-gray-500 text-xs mt-2">Please review before consuming this food</p>
                </div>
                <button onClick={() => setShowAllergyWarning(false)} className="text-red-400 hover:text-red-300 p-1">
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}

          <div className="flex items-center gap-3 p-3 bg-[#1a1a1a] rounded-xl">
            <img src={selectedImage!} alt="Food" className="w-14 h-14 object-cover rounded-xl flex-shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="text-white font-semibold truncate">{result.food_name}</p>
              <p className="text-gray-500 text-xs mt-0.5 line-clamp-2">{result.description}</p>
              <span className={`text-xs font-medium mt-1 inline-block ${confidenceColors[result.confidence]}`}>
                {result.confidence === 'high' ? '✓ High confidence' : result.confidence === 'medium' ? '~ Medium confidence' : '! Low confidence estimate'}
              </span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {[
              { icon: Flame, label: 'Calories', value: result.calories, unit: 'kcal', color: 'text-orange-400', bg: 'bg-orange-500/10' },
              { icon: Beef, label: 'Protein', value: result.protein, unit: 'g', color: 'text-blue-400', bg: 'bg-blue-500/10' },
              { icon: Wheat, label: 'Carbs', value: result.carbs, unit: 'g', color: 'text-yellow-400', bg: 'bg-yellow-500/10' },
              { icon: Droplets, label: 'Fat', value: result.fat, unit: 'g', color: 'text-purple-400', bg: 'bg-purple-500/10' },
            ].map(({ icon: Icon, label, value, unit, color, bg }) => (
              <div key={label} className={`${bg} rounded-xl p-3 flex items-center gap-3`}>
                <Icon className={`${color} w-5 h-5 flex-shrink-0`} />
                <div>
                  <p className="text-gray-500 text-xs">{label}</p>
                  <p className={`${color} font-bold text-lg leading-tight`}>{Math.round(value)}<span className="text-xs font-normal ml-1">{unit}</span></p>
                </div>
              </div>
            ))}
          </div>

          <div className="flex items-center justify-between px-1">
            <span className="text-gray-500 text-sm">Added to:</span>
            <span className="text-green-400 text-sm font-medium capitalize">{mealTypes.find(m => m.value === mealType)?.label}</span>
          </div>

          <div className="flex gap-3">
            <button onClick={() => setStep('upload')} className="flex-1 py-3 bg-[#1a1a1a] hover:bg-[#2a2a2a] text-gray-300 rounded-xl transition-colors text-sm">Retake Photo</button>
            <button onClick={() => { onSuccess(); handleClose(); }} className="flex-1 py-3 bg-green-500 hover:bg-green-600 text-black font-semibold rounded-xl transition-colors flex items-center justify-center gap-2 text-sm">
              <CheckCircle className="w-4 h-4" /> Confirm & Log
            </button>
          </div>
        </div>
      )}

      {/* STEP: Error */}
      {step === 'error' && (
        <div className="flex flex-col items-center justify-center py-8 space-y-4">
          <div className="w-16 h-16 rounded-2xl bg-red-500/20 flex items-center justify-center">
            <AlertCircle className="w-8 h-8 text-red-400" />
          </div>
          <p className="text-white font-medium">Analysis Failed</p>
          <p className="text-gray-500 text-sm text-center">{errorMsg}</p>
          <button onClick={() => setStep('upload')} className="px-6 py-2.5 bg-[#1a1a1a] hover:bg-[#2a2a2a] text-white rounded-xl transition-colors text-sm">Try Again</button>
        </div>
      )}
    </motion.div>
  </div>
</AnimatePresence>
)
}
