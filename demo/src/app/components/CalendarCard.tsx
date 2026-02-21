import { Calendar, Clock, MapPin } from 'lucide-react';

export function CalendarCard() {
  return (
    <div className="bg-white rounded-lg max-w-[280px] shadow-md overflow-hidden border border-gray-200 mb-1">
      <div className="bg-gradient-to-r from-[#008080] to-[#00a0a0] p-3 flex items-center gap-2">
        <div className="w-10 h-10 bg-white rounded-lg flex items-center justify-center">
          <Calendar className="w-5 h-5 text-[#008080]" />
        </div>
        <div>
          <div className="text-white text-[11px] font-medium opacity-90">Google Calendar</div>
          <div className="text-white text-[13px] font-semibold">Cita Agendada</div>
        </div>
      </div>
      
      <div className="p-3 space-y-2.5">
        <div>
          <div className="font-semibold text-[14px] text-gray-900 mb-0.5">
            Cita Odontología - Juan Pérez
          </div>
          <div className="text-[12px] text-gray-600">
            Consulta de urgencia dental
          </div>
        </div>
        
        <div className="space-y-1.5">
          <div className="flex items-center gap-2 text-[12px] text-gray-700">
            <Calendar className="w-3.5 h-3.5 text-gray-500" />
            <span>Martes 20 de mayo, 2025</span>
          </div>
          <div className="flex items-center gap-2 text-[12px] text-gray-700">
            <Clock className="w-3.5 h-3.5 text-gray-500" />
            <span>10:30 AM - 11:00 AM</span>
          </div>
          <div className="flex items-center gap-2 text-[12px] text-gray-700">
            <MapPin className="w-3.5 h-3.5 text-gray-500" />
            <span>Clínica OCAI - Santa Elena</span>
          </div>
        </div>
        
        <div className="pt-2 border-t border-gray-100">
          <button className="w-full bg-teal-50 hover:bg-teal-100 text-[#008080] text-[12px] font-medium py-2 rounded-md transition-colors">
            Ver en Calendario
          </button>
        </div>
      </div>
    </div>
  );
}
