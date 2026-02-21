import { ArrowLeft, Video, Phone, MoreVertical } from 'lucide-react';

export function WhatsAppHeader() {
  return (
    <div className="bg-[#008080] text-white px-4 py-3 flex items-center gap-3 shadow-md relative z-10">
      <button className="p-1 hover:bg-white/10 rounded-full transition-colors">
        <ArrowLeft className="w-6 h-6" />
      </button>

      <div className="flex items-center gap-3 flex-1 min-w-0">
        <div className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center overflow-hidden flex-shrink-0">
          <div className="w-full h-full bg-gradient-to-br from-teal-300 to-teal-500 flex items-center justify-center text-white font-semibold text-lg">
            O
          </div>
        </div>

        <div className="flex-1 min-w-0">
          <div className="font-semibold text-[15px] leading-tight flex items-center gap-1.5 text-white">
            <span>Clínica OCAI</span>
            <svg className="w-4 h-4 fill-white flex-shrink-0" viewBox="0 0 24 24">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
            </svg>
          </div>
          <div className="text-[13px] text-white/90 leading-tight">Mel • Asistente de IA</div>
        </div>
      </div>
      
      <div className="flex items-center gap-5">
        <button className="p-1">
          <Video className="w-6 h-6" />
        </button>
        <button className="p-1">
          <Phone className="w-6 h-6" />
        </button>
        <button className="p-1">
          <MoreVertical className="w-6 h-6" />
        </button>
      </div>
    </div>
  );
}
