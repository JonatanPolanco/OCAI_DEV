export function TypingIndicator() {
  return (
    <div className="flex items-start gap-2">
      <div className="bg-white rounded-lg rounded-tl-sm px-4 py-3 shadow-sm">
        <div className="flex gap-1">
          <div 
            className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" 
            style={{ animationDelay: '0ms', animationDuration: '1s' }} 
          />
          <div 
            className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" 
            style={{ animationDelay: '150ms', animationDuration: '1s' }} 
          />
          <div 
            className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" 
            style={{ animationDelay: '300ms', animationDuration: '1s' }} 
          />
        </div>
      </div>
    </div>
  );
}
