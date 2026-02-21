import { Plus, Camera, Mic, Smile } from 'lucide-react';

export function MessageInput() {
  return (
    <div className="bg-[#f0f0f0] px-2 py-2 flex items-end gap-2">
      <button className="p-2.5 text-gray-600 hover:bg-gray-200 rounded-full transition-colors">
        <Plus className="w-6 h-6" />
      </button>
      
      <div className="flex-1 bg-white rounded-[20px] flex items-end shadow-sm">
        <button className="p-2.5 pl-3 text-gray-600">
          <Smile className="w-5 h-5" />
        </button>
        
        <input
          type="text"
          placeholder="Mensaje"
          className="flex-1 py-2.5 text-[15px] bg-transparent outline-none"
        />
        
        <button className="p-2.5 pr-3 text-gray-600">
          <Camera className="w-5 h-5" />
        </button>
      </div>
      
      <button className="p-3 bg-[#008080] text-white rounded-full shadow-md active:scale-95 transition-transform">
        <Mic className="w-5 h-5" />
      </button>
    </div>
  );
}
