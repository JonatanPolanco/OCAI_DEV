import { Play, Mic, Check } from 'lucide-react';
import { useState } from 'react';

interface AudioMessageProps {
  read?: boolean;
  time: string;
}

export function AudioMessage({ read = false, time }: AudioMessageProps) {
  const [isPlaying, setIsPlaying] = useState(false);
  
  return (
    <div className="bg-[#DCF8C6] rounded-lg rounded-tr-sm p-2.5 max-w-[280px] ml-auto shadow-sm">
      <div className="flex items-center gap-2.5">
        <button
          onClick={() => setIsPlaying(!isPlaying)}
          className="w-9 h-9 rounded-full bg-[#008080] flex items-center justify-center flex-shrink-0 active:scale-95 transition-transform"
        >
          {isPlaying ? (
            <div className="w-3 h-3 bg-white rounded-sm" />
          ) : (
            <Play className="w-4 h-4 text-white fill-white ml-0.5" />
          )}
        </button>
        
        <div className="flex-1 flex items-center gap-1.5">
          <Mic className="w-3.5 h-3.5 text-gray-600 flex-shrink-0" />
          <div className="flex items-end gap-0.5 flex-1 h-5">
            {[3, 6, 4, 8, 5, 9, 7, 10, 6, 8, 5, 7, 4, 6, 3, 7, 5, 8, 6, 9, 7, 5, 4, 6, 8, 5].map((height, index) => (
              <div
                key={index}
                className="flex-1 bg-gray-600 rounded-full min-w-[2px]"
                style={{ height: `${height * 2}px` }}
              />
            ))}
          </div>
        </div>
        
        <div className="text-[11px] text-gray-600 flex-shrink-0">0:12</div>
      </div>
      
      <div className="text-[11px] text-gray-500 text-right mt-1 flex items-center justify-end gap-1">
        <span>{time}</span>
        <div className="flex items-center">
          {read ? (
            <>
              <Check className="w-3.5 h-3.5 text-[#53bdeb] -mr-2" />
              <Check className="w-3.5 h-3.5 text-[#53bdeb]" />
            </>
          ) : (
            <>
              <Check className="w-3.5 h-3.5 text-gray-400 -mr-2" />
              <Check className="w-3.5 h-3.5 text-gray-400" />
            </>
          )}
        </div>
      </div>
    </div>
  );
}