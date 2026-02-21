import { Check } from 'lucide-react';

interface MessageBubbleProps {
  sender: 'juan' | 'mel';
  content: string;
  time: string;
  read?: boolean;
}

export function MessageBubble({ sender, content, time, read }: MessageBubbleProps) {
  const isJuan = sender === 'juan';
  
  // Convert WhatsApp style bold (*text*) to actual bold
  const formatContent = (text: string) => {
    const parts = text.split(/(\*[^*]+\*)/g);
    return parts.map((part, index) => {
      if (part.startsWith('*') && part.endsWith('*')) {
        return <strong key={index}>{part.slice(1, -1)}</strong>;
      }
      return part;
    });
  };

  return (
    <div className={`flex ${isJuan ? 'justify-end' : 'justify-start'} mb-1`}>
      <div
        className={`rounded-lg px-3 py-2 max-w-[280px] shadow-sm ${
          isJuan
            ? 'bg-[#DCF8C6] rounded-tr-sm'
            : 'bg-white rounded-tl-sm'
        }`}
      >
        <div className="text-[14.5px] leading-[1.4] text-gray-900 whitespace-pre-wrap break-words">
          {formatContent(content)}
        </div>
        
        <div className="text-[11px] text-gray-500 mt-0.5 flex items-center justify-end gap-1">
          <span>{time}</span>
          {isJuan && (
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
          )}
        </div>
      </div>
    </div>
  );
}
