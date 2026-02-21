import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { WhatsAppHeader } from "./components/WhatsAppHeader";
import { AudioMessage } from "./components/AudioMessage";
import { MessageBubble } from "./components/MessageBubble";
import { CalendarCard } from "./components/CalendarCard";
import { MessageInput } from "./components/MessageInput";
import { TypingIndicator } from "./components/TypingIndicator";
import { BackendProcess } from "./components/BackendProcess";

interface Message {
  id: number;
  type: "audio" | "text" | "card";
  sender: "juan" | "mel";
  content: string;
  time: string;
  read?: boolean;
  transcription?: string;
}

interface BackendProcessData {
  processes: Array<{
    id: string;
    label: string;
    value: string;
    status: "loading" | "complete";
  }>;
  transcription?: string;
}

const conversationScript: Message[] = [
  {
    id: 1,
    type: "audio",
    sender: "juan",
    content:
      "Hola, tengo un dolor muy fuerte en una muela desde ayer. Necesito que me vea un doctor urgente",
    time: "09:15",
    transcription:
      "Hola, tengo un dolor muy fuerte en una muela desde ayer. Necesito que me vea un doctor urgente",
  },
  {
    id: 2,
    type: "text",
    sender: "mel",
    content:
      "¡Hola de nuevo Juan! 👋 Lamento mucho que estés pasando por ese dolor 😔\n\nVeo que ya eres paciente nuestro. Voy a ayudarte a agendar una cita urgente.",
    time: "09:15",
  },
  {
    id: 3,
    type: "text",
    sender: "mel",
    content:
      "Para confirmar, estos son tus datos:\n\n📛 Juan Pérez\n📱 3009998877\n🎂 15/03/1985\n\n¿Es correcto?",
    time: "09:16",
  },
  {
    id: 4,
    type: "text",
    sender: "juan",
    content: "Sí",
    time: "09:16",
  },
  {
    id: 5,
    type: "text",
    sender: "mel",
    content:
      "¿Podrías contarme más sobre el dolor que sientes?",
    time: "09:16",
  },
  {
    id: 6,
    type: "text",
    sender: "juan",
    content: "Me duele mucho al masticar y sangra un poco",
    time: "09:17",
  },
  {
    id: 7,
    type: "text",
    sender: "mel",
    content:
      "Entiendo. Para brindarte mejor atención, ¿quieres hacer una autoevaluación rápida de 30 segundos?",
    time: "09:17",
  },
  {
    id: 8,
    type: "text",
    sender: "juan",
    content: "Claro",
    time: "09:17",
  },
  {
    id: 9,
    type: "text",
    sender: "mel",
    content: "¿Del 0 al 10, qué tan fuerte es el dolor?",
    time: "09:17",
  },
  {
    id: 10,
    type: "text",
    sender: "juan",
    content: "8",
    time: "09:18",
  },
  {
    id: 11,
    type: "text",
    sender: "mel",
    content: "¿El dolor es constante o aparece de repente?",
    time: "09:18",
  },
  {
    id: 12,
    type: "text",
    sender: "juan",
    content: "Es constante",
    time: "09:18",
  },
  {
    id: 13,
    type: "text",
    sender: "mel",
    content:
      "Gracias Juan. Por la intensidad del dolor, te recomiendo *Odontología General - Urgencia*.\n\n¿Qué día prefieres?",
    time: "09:18",
  },
  {
    id: 14,
    type: "text",
    sender: "juan",
    content: "Lo más pronto posible, mañana si se puede",
    time: "09:19",
  },
  {
    id: 15,
    type: "text",
    sender: "mel",
    content:
      "Mañana martes 20 de mayo tengo estos espacios priorizados:\n\n• 10:30 AM\n• 02:00 PM\n• 04:30 PM\n\n¿Cuál te queda mejor?",
    time: "09:19",
  },
  {
    id: 16,
    type: "text",
    sender: "juan",
    content: "10:30 está bien",
    time: "09:19",
  },
  {
    id: 17,
    type: "text",
    sender: "mel",
    content:
      "Perfecto Juan, confirmemos todo:\n\n*Cita de Odontología General - Urgencia*\n\n👤 Juan Pérez\n📅 Martes 20 de mayo, 2025\n🕒 10:30 AM (30 min)\n👩‍⚕️ Dra. Ana García\n🦷 Dolor agudo en molar\n📍 Santa Elena, Medellín\n\n¿Procedo con el agendamiento?",
    time: "09:19",
  },
  {
    id: 18,
    type: "text",
    sender: "juan",
    content: "Sí, por favor",
    time: "09:20",
  },
  {
    id: 19,
    type: "text",
    sender: "mel",
    content:
      "¡Cita confirmada! ✅\n\nTu cita ha sido agendada exitosamente.\n\n📅 Mañana 20 de mayo\n🕒 10:30 AM - 11:00 AM\n📍 Clínica OCAI - Santa Elena\n\nTe llegará un recordatorio 24h antes y 2h antes de la cita.\n\nNos vemos mañana Juan! 😊",
    time: "09:20",
  },
  {
    id: 20,
    type: "text",
    sender: "mel",
    content:
      "Por cierto, ¿te gustaría responder una pregunta rápida de satisfacción?",
    time: "09:20",
  },
  {
    id: 21,
    type: "text",
    sender: "juan",
    content: "Dale",
    time: "09:21",
  },
  {
    id: 22,
    type: "text",
    sender: "mel",
    content: "¿De 1 a 5, cómo calificarías mi atención?",
    time: "09:21",
  },
  {
    id: 23,
    type: "text",
    sender: "juan",
    content: "5",
    time: "09:21",
  },
  {
    id: 24,
    type: "text",
    sender: "mel",
    content: "¡Gracias Juan! 🙏 Que te mejores pronto.",
    time: "09:21",
  },
];

// Timing configuration for realistic conversation flow
const getMessageTiming = (
  index: number,
  message: Message,
  prevMessage?: Message,
): number => {
  if (index === 0) return 1500; // Initial delay

  // Mel's messages need typing time
  if (message.sender === "mel") {
    const baseDelay = 1200;
    const typingTime =
      message.content.length > 100
        ? 2500
        : message.content.length > 50
          ? 1800
          : 1200;
    return baseDelay + typingTime;
  }

  // Juan's messages
  if (message.type === "audio") return 2500;
  return message.content.length > 30 ? 1500 : 1000;
};

export default function App() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isTyping, setIsTyping] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(true);
  const [elapsedTime, setElapsedTime] = useState(0);
  const [backendProcess, setBackendProcess] =
    useState<BackendProcessData | null>(null);
  const chatContainerRef = useRef<HTMLDivElement>(null);
  const startTimeRef = useRef<number>(Date.now());

  // Reset animation
  const resetAnimation = () => {
    setMessages([]);
    setCurrentIndex(0);
    setIsTyping(false);
    setIsPlaying(true);
    setElapsedTime(0);
    setBackendProcess(null);
    startTimeRef.current = Date.now();
  };

  // Track elapsed time
  useEffect(() => {
    if (!isPlaying) return;

    const interval = setInterval(() => {
      setElapsedTime(
        Math.floor((Date.now() - startTimeRef.current) / 1000),
      );
    }, 100);

    return () => clearInterval(interval);
  }, [isPlaying]);

  // Auto-scroll to bottom when new messages appear
  useEffect(() => {
    if (chatContainerRef.current) {
      chatContainerRef.current.scrollTo({
        top: chatContainerRef.current.scrollHeight,
        behavior: "smooth",
      });
    }
  }, [messages, isTyping]);

  // Animate conversation
  useEffect(() => {
    if (
      !isPlaying ||
      currentIndex >= conversationScript.length
    ) {
      if (currentIndex >= conversationScript.length) {
        setIsPlaying(false);
      }
      return;
    }

    const currentMessage = conversationScript[currentIndex];
    const prevMessage =
      currentIndex > 0
        ? conversationScript[currentIndex - 1]
        : undefined;
    const timing = getMessageTiming(
      currentIndex,
      currentMessage,
      prevMessage,
    );

    const timer = setTimeout(() => {
      // Show backend processing for appointment creation (when Juan confirms with "Sí, por favor")
      if (currentMessage.id === 18 && currentMessage.content === "Sí, por favor") {
        setBackendProcess({
          processes: [
            {
              id: "calendar-1",
              label: "Google Calendar API",
              value: "Creando evento...",
              status: "loading",
            },
          ],
        });

        setTimeout(() => {
          setBackendProcess({
            processes: [
              {
                id: "calendar-1",
                label: "Google Calendar API",
                value: "Evento creado en agenda Dra. Ana García",
                status: "complete",
              },
              {
                id: "db-1",
                label: "Base de datos",
                value: "Guardando información...",
                status: "loading",
              },
            ],
          });
        }, 800);

        setTimeout(() => {
          setBackendProcess({
            processes: [
              {
                id: "calendar-1",
                label: "Google Calendar API",
                value: "Evento creado en agenda Dra. Ana García",
                status: "complete",
              },
              {
                id: "db-1",
                label: "Base de datos",
                value: "Cita y datos guardados exitosamente",
                status: "complete",
              },
            ],
          });
        }, 1500);
      }

      // Show backend processing for audio message
      if (
        currentMessage.type === "audio" &&
        currentMessage.sender === "juan"
      ) {
        // Show transcription and processing
        setBackendProcess({
          transcription: currentMessage.transcription,
          processes: [
            {
              id: "1",
              label: "Clasificador de idioma",
              value: "Español",
              status: "loading",
            },
          ],
        });

        // Animate backend processes
        setTimeout(() => {
          setBackendProcess({
            transcription: currentMessage.transcription,
            processes: [
              {
                id: "1",
                label: "Clasificador de idioma",
                value: "Español",
                status: "complete",
              },
              {
                id: "2",
                label: "Clasificador de intención",
                value: "Gestión de cita",
                status: "loading",
              },
            ],
          });
        }, 300);

        setTimeout(() => {
          setBackendProcess({
            transcription: currentMessage.transcription,
            processes: [
              {
                id: "1",
                label: "Clasificador de idioma",
                value: "Español",
                status: "complete",
              },
              {
                id: "2",
                label: "Clasificador de intención",
                value: "Gestión de cita",
                status: "complete",
              },
              {
                id: "3",
                label: "Análisis de sentimiento",
                value: "Negativo (dolor)",
                status: "loading",
              },
            ],
          });
        }, 600);

        setTimeout(() => {
          setBackendProcess({
            transcription: currentMessage.transcription,
            processes: [
              {
                id: "1",
                label: "Clasificador de idioma",
                value: "Español",
                status: "complete",
              },
              {
                id: "2",
                label: "Clasificador de intención",
                value: "Gestión de cita",
                status: "complete",
              },
              {
                id: "3",
                label: "Análisis de sentimiento",
                value: "Negativo (dolor)",
                status: "complete",
              },
              {
                id: "4",
                label: "Human in the loop",
                value: "No requiere",
                status: "loading",
              },
            ],
          });
        }, 900);

        setTimeout(() => {
          setBackendProcess({
            transcription: currentMessage.transcription,
            processes: [
              {
                id: "1",
                label: "Clasificador de idioma",
                value: "Español",
                status: "complete",
              },
              {
                id: "2",
                label: "Clasificador de intención",
                value: "Gestión de cita",
                status: "complete",
              },
              {
                id: "3",
                label: "Análisis de sentimiento",
                value: "Negativo (dolor)",
                status: "complete",
              },
              {
                id: "4",
                label: "Human in the loop",
                value: "No requiere",
                status: "complete",
              },
              {
                id: "5",
                label: "Base de datos",
                value:
                  "Juan Pérez encontrado (paciente recurrente)",
                status: "loading",
              },
            ],
          });
        }, 1200);

        setTimeout(() => {
          setBackendProcess({
            transcription: currentMessage.transcription,
            processes: [
              {
                id: "1",
                label: "Clasificador de idioma",
                value: "Español",
                status: "complete",
              },
              {
                id: "2",
                label: "Clasificador de intención",
                value: "Gestión de cita",
                status: "complete",
              },
              {
                id: "3",
                label: "Análisis de sentimiento",
                value: "Negativo (dolor)",
                status: "complete",
              },
              {
                id: "4",
                label: "Human in the loop",
                value: "No requiere",
                status: "complete",
              },
              {
                id: "5",
                label: "Base de datos",
                value:
                  "Juan Pérez encontrado (paciente recurrente)",
                status: "complete",
              },
            ],
          });
        }, 1500);

        // Keep backend process visible (removed auto-clear)
      }

      // Show typing indicator for Mel's messages
      if (currentMessage.sender === "mel") {
        setIsTyping(true);
        const typingDuration =
          currentMessage.content.length > 100
            ? 2000
            : currentMessage.content.length > 50
              ? 1500
              : 1000;

        setTimeout(() => {
          setIsTyping(false);
          setMessages((prev) => [
            ...prev,
            { ...currentMessage, read: false },
          ]);
          setCurrentIndex((prev) => prev + 1);

          // Mark messages as read after a delay
          setTimeout(() => {
            setMessages((prev) =>
              prev.map((msg) =>
                msg.id === currentMessage.id
                  ? { ...msg, read: true }
                  : msg,
              ),
            );
          }, 500);
        }, typingDuration);
      } else {
        setMessages((prev) => [
          ...prev,
          { ...currentMessage, read: false },
        ]);
        setCurrentIndex((prev) => prev + 1);

        // Mark messages as read
        setTimeout(() => {
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === currentMessage.id
                ? { ...msg, read: true }
                : msg,
            ),
          );
        }, 500);
      }
    }, timing);

    return () => clearTimeout(timer);
  }, [currentIndex, isPlaying]);

  return (
    <div className="h-screen w-full bg-black flex items-center justify-center relative overflow-hidden">
      {/* Control Panel */}
      <div className="absolute top-6 left-1/2 -translate-x-1/2 z-50 bg-white/10 backdrop-blur-md rounded-full px-5 py-2.5 flex items-center gap-3 text-sm">
        <button
          onClick={() => setIsPlaying(!isPlaying)}
          className="text-white hover:text-[#008080] transition-colors"
        >
          {isPlaying ? (
            <svg
              className="w-6 h-6"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
            </svg>
          ) : (
            <svg
              className="w-6 h-6"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <path d="M8 5v14l11-7z" />
            </svg>
          )}
        </button>

        <button
          onClick={resetAnimation}
          className="text-white hover:text-[#008080] transition-colors"
        >
          <svg
            className="w-6 h-6"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
            />
          </svg>
        </button>

        <div className="border-l border-white/30 h-6" />

        <div className="text-white text-sm font-medium flex items-center gap-3">
          <span>
            {String(Math.floor(elapsedTime / 60)).padStart(
              2,
              "0",
            )}
            :{String(elapsedTime % 60).padStart(2, "0")}
          </span>
          <span className="text-white/60">•</span>
          <span>
            {currentIndex} / {conversationScript.length}
          </span>
        </div>

        <div className="border-l border-white/30 h-6" />

        <div className="flex items-center gap-2">
          <div className="w-6 h-6 bg-[#008080] rounded-full flex items-center justify-center">
            <span className="text-white text-xs font-bold">
              M
            </span>
          </div>
          <span className="text-white text-sm font-medium">
            OCAi Health • Mel v2.6
          </span>
        </div>
      </div>

      {/* iPhone 14 Pro Mockup */}
      <div className="relative w-[393px] h-[852px] bg-black rounded-[55px] p-[3px] shadow-2xl" style={{ transform: 'scale(0.75)', transformOrigin: 'center' }}>
        {/* iPhone Screen Border */}
        <div className="w-full h-full bg-black rounded-[52px] overflow-hidden relative">
          {/* Dynamic Island */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[126px] h-[37px] bg-black rounded-b-[20px] z-50" />

          {/* App Content */}
          <div className="w-full h-full flex flex-col bg-[#e5ddd5] relative">
            {/* WhatsApp Background Pattern */}
            <div className="absolute inset-0 opacity-[0.04] pointer-events-none">
              <svg
                width="100%"
                height="100%"
                xmlns="http://www.w3.org/2000/svg"
              >
                <defs>
                  <pattern
                    id="whatsapp-pattern"
                    x="0"
                    y="0"
                    width="280"
                    height="280"
                    patternUnits="userSpaceOnUse"
                  >
                    <g fill="none" fillRule="evenodd">
                      <path d="M0 0h280v280H0z" />
                      <path
                        d="M140 0c77.32 0 140 62.68 140 140s-62.68 140-140 140S0 217.32 0 140 62.68 0 140 0zm0 10c-71.797 0-130 58.203-130 130s58.203 130 130 130 130-58.203 130-130S211.797 10 140 10z"
                        fill="#000"
                        opacity=".5"
                      />
                    </g>
                  </pattern>
                </defs>
                <rect
                  width="100%"
                  height="100%"
                  fill="url(#whatsapp-pattern)"
                />
              </svg>
            </div>

            {/* Header */}
            <div className="pt-[37px]">
              <WhatsAppHeader />
            </div>

            {/* Chat Area */}
            <div
              ref={chatContainerRef}
              className="flex-1 overflow-y-auto px-3 py-3 space-y-2"
              style={{ scrollBehavior: "smooth" }}
            >
              {/* Date Divider */}
              <div className="flex justify-center mb-3">
                <div className="bg-white/80 backdrop-blur-sm shadow-sm px-3 py-1 rounded-md text-[12px] text-gray-700">
                  HOY
                </div>
              </div>

              <AnimatePresence>
                {messages.map((message, index) => (
                  <motion.div
                    key={message.id}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.3 }}
                    className={
                      message.sender === "juan"
                        ? "flex justify-end"
                        : ""
                    }
                  >
                    {message.type === "audio" ? (
                      <AudioMessage
                        read={message.read}
                        time={message.time}
                      />
                    ) : message.type === "card" ? (
                      <CalendarCard />
                    ) : (
                      <MessageBubble
                        sender={message.sender}
                        content={message.content}
                        time={message.time}
                        read={message.read}
                      />
                    )}
                  </motion.div>
                ))}
              </AnimatePresence>

              {/* Typing Indicator */}
              {isTyping && (
                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0 }}
                >
                  <TypingIndicator />
                </motion.div>
              )}
            </div>

            {/* Message Input */}
            <MessageInput />
          </div>
        </div>
      </div>

      {/* Backend Process Display - Fixed position on right */}
      <div className="absolute right-4 top-1/2 -translate-y-1/2 z-40" style={{ transform: 'scale(0.85) translateY(-50%)', transformOrigin: 'right center' }}>
        <AnimatePresence mode="wait">
          {backendProcess && (
            <BackendProcess
              processes={backendProcess.processes}
              transcription={backendProcess.transcription}
            />
          )}
        </AnimatePresence>
      </div>

      {/* CTA Overlay when demo ends */}
      <AnimatePresence>
        {currentIndex >= conversationScript.length && !isPlaying && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ delay: 0.2 }}
              className="bg-white rounded-3xl p-8 max-w-md text-center shadow-2xl"
            >
              <div className="w-16 h-16 bg-[#008080] rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h3 className="text-2xl font-bold text-gray-900 mb-2">
                ¿Listo para automatizar tu clínica?
              </h3>
              <p className="text-gray-600 mb-6">
                Agenda una demo de 30 minutos y descubre cómo OCAi puede transformar tu operación dental
              </p>
              <div className="flex flex-col sm:flex-row gap-3 justify-center">
                <button
                  onClick={() => window.open('https://calendar.app.google/EFAdNjqsdibXRdYd9', '_blank')}
                  className="bg-[#008080] text-white px-6 py-3 rounded-full font-semibold hover:bg-[#006666] transition-all hover:scale-105 shadow-lg"
                >
                  📅 Agendar Demo Gratuita
                </button>
                <button
                  onClick={resetAnimation}
                  className="bg-gray-100 text-gray-700 px-6 py-3 rounded-full font-semibold hover:bg-gray-200 transition-all"
                >
                  🔄 Ver de Nuevo
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}