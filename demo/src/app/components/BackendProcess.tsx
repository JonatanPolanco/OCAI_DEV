import { motion, AnimatePresence } from 'motion/react';
import { CheckCircle2, Loader2 } from 'lucide-react';

interface BackendProcessProps {
  processes: Array<{
    id: string;
    label: string;
    value: string;
    status: 'loading' | 'complete';
  }>;
  transcription?: string;
}

export function BackendProcess({ processes, transcription }: BackendProcessProps) {
  return (
    <motion.div
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: 20 }}
      className="bg-gradient-to-br from-gray-900 to-gray-800 backdrop-blur-md rounded-2xl p-6 shadow-2xl border border-gray-700/50 max-w-[360px]"
    >
      <div className="flex items-center justify-between mb-5">
        <div className="flex items-center gap-2.5">
          <div className="w-2.5 h-2.5 bg-green-500 rounded-full animate-pulse" />
          <h3 className="text-white font-semibold text-base">Sistema Multi-Agente</h3>
        </div>
        <div className="text-xs text-[#008080] font-mono bg-[#008080]/10 px-2 py-0.5 rounded">v2.6</div>
      </div>
      
      {transcription && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          className="mb-5 p-3.5 bg-gray-800/50 rounded-xl border border-gray-700/50"
        >
          <div className="text-[#008080] text-xs font-semibold mb-2 flex items-center gap-1.5">
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/>
              <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/>
            </svg>
            AUDIO → TEXTO
          </div>
          <div className="text-gray-300 text-xs leading-relaxed italic">
            "{transcription}"
          </div>
        </motion.div>
      )}
      
      <div className="space-y-2.5">
        {processes.map((process, index) => (
          <motion.div
            key={process.id}
            initial={{ opacity: 0, x: -10 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: index * 0.15 }}
            className="flex items-start gap-2.5"
          >
            <div className="mt-0.5">
              {process.status === 'loading' ? (
                <Loader2 className="w-4 h-4 text-blue-400 animate-spin" />
              ) : (
                <CheckCircle2 className="w-4 h-4 text-green-500" />
              )}
            </div>
            <div className="flex-1">
              <div className="text-gray-400 text-xs">{process.label}</div>
              <div className="text-white text-sm font-medium">{process.value}</div>
            </div>
          </motion.div>
        ))}
      </div>
    </motion.div>
  );
}
