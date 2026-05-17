"use client"
import { useState, useEffect, useRef } from 'react'
import { PromptInputBox } from '@/components/ui/ai-prompt-box'
import { BrainCircuit, Trash2 } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface Message { id: string; role: 'user' | 'assistant'; content: string; created_at: string; }

const SUGGESTIONS = [
  "What should I eat for lunch?",
  "Analyze today's nutrition",
  "High-protein snack ideas",
  "Am I hitting my goals today?",
]

export default function AssistantPage() {
  const [messages, setMessages] = useState<Message[]>([])
  const [isStreaming, setIsStreaming] = useState(false)
  const bottomRef = useRef<HTMLDivElement>(null)
  const token = typeof window !== 'undefined' ? localStorage.getItem('nutrimind_token') : null
  const API = process.env.NEXT_PUBLIC_API_URL 

  useEffect(() => {
    if (!token) { window.location.href = '/login'; return; }
    fetch(`${API}/api/v1/ai/history`, { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.json()).then(data => { if (Array.isArray(data)) setMessages(data); })
      .catch(() => {})
  }, [])

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }) }, [messages])

  const sendMessage = async (text: string) => {
    if (!text.trim() || isStreaming) return
    const userMsg: Message = { id: Date.now().toString(), role: 'user', content: text, created_at: new Date().toISOString() }
    setMessages(prev => [...prev, userMsg])
    setIsStreaming(true)
    const aiMsg: Message = { id: (Date.now()+1).toString(), role: 'assistant', content: '', created_at: new Date().toISOString() }
    setMessages(prev => [...prev, aiMsg])

    try {
      const res = await fetch(`${API}/api/v1/ai/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ message: text }),
      })
      const reader = res.body?.getReader()
      const decoder = new TextDecoder()
      if (!reader) return

      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        const chunk = decoder.decode(value)
        const lines = chunk.split('\n').filter(l => l.startsWith('data: '))
        for (const line of lines) {
          const data = line.replace('data: ', '')
          if (data === '[DONE]') break
          try {
            const { text: token } = JSON.parse(data)
            setMessages(prev => prev.map((m, i) => i === prev.length - 1 ? { ...m, content: m.content + token } : m))
          } catch {}
        }
      }
    } catch {
      setMessages(prev => prev.map((m, i) => i === prev.length - 1 ? { ...m, content: 'Sorry, something went wrong. Please try again.' } : m))
    } finally { setIsStreaming(false) }
  }

  const clearHistory = async () => {
    await fetch(`${API}/api/v1/ai/history`, { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } })
    setMessages([])
  }

  return (
    <div className="flex flex-col h-screen bg-gradient-to-b from-[#0d0d0d] to-[#0a0a0a]">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-[#1a1a1a]">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-green-500/20 flex items-center justify-center">
            <BrainCircuit className="w-5 h-5 text-green-400" />
          </div>
          <div>
            <h1 className="text-white font-semibold">NutriMind AI</h1>
            <p className="text-xs text-gray-500">Your personal nutrition coach</p>
          </div>
        </div>
        <button onClick={clearHistory} className="flex items-center gap-2 text-gray-500 hover:text-red-400 transition-colors text-sm px-3 py-2 rounded-lg hover:bg-red-500/10">
          <Trash2 className="w-4 h-4" /> Clear chat
        </button>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-6 space-y-4">
        {messages.length === 0 ? (
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}
            className="flex flex-col items-center justify-center h-full text-center px-4">
            <div className="w-16 h-16 rounded-2xl bg-green-500/20 flex items-center justify-center mb-4">
              <BrainCircuit className="w-8 h-8 text-green-400" />
            </div>
            <h2 className="text-white text-xl font-semibold mb-2">How can I help you today?</h2>
            <p className="text-gray-500 text-sm max-w-sm mb-8">I know your nutrition goals and today's intake. Ask me anything about food, calories, or health.</p>
            <div className="grid grid-cols-2 gap-3 w-full max-w-md">
              {SUGGESTIONS.map(s => (
                <button key={s} onClick={() => sendMessage(s)}
                  className="text-left px-4 py-3 rounded-xl bg-[#111111] border border-[#1a1a1a] text-gray-300 text-sm hover:border-green-500/50 hover:text-white transition-all">
                  {s}
                </button>
              ))}
            </div>
          </motion.div>
        ) : (
          <AnimatePresence initial={false}>
            {messages.map((msg) => (
              <motion.div key={msg.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
                className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'} gap-3`}>
                {msg.role === 'assistant' && (
                  <div className="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center flex-shrink-0 mt-1">
                    <span className="text-black text-xs font-bold">NM</span>
                  </div>
                )}
                <div className={`max-w-[70%] px-4 py-3 rounded-2xl text-sm leading-relaxed whitespace-pre-wrap
                  ${msg.role === 'user' ? 'bg-green-500 text-black rounded-tr-sm font-medium' : 'bg-[#1a1a1a] text-gray-100 rounded-tl-sm'}`}>
                  {msg.content}
                  {isStreaming && msg.role === 'assistant' && msg === messages[messages.length-1] && (
                    <span className="inline-block w-2 h-4 bg-green-400 ml-1 animate-pulse rounded-sm" />
                  )}
                </div>
              </motion.div>
            ))}
          </AnimatePresence>
        )}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="px-4 pb-4 pt-2 border-t border-[#1a1a1a]">
        <PromptInputBox
          onSend={(message) => sendMessage(message)}
          isLoading={isStreaming}
          placeholder="Ask your nutrition coach..."
        />
      </div>
    </div>
  )
}