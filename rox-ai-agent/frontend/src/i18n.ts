import { createContext, useContext } from "react";
export type Lang = "ar" | "en";
const dict = {
  dashboard: ["لوحة التحكم", "Dashboard"], chat: ["المحادثة", "Chat"], game: ["وكيل الألعاب", "Game Agent"],
  computer: ["التحكم بالكمبيوتر", "Computer Agent"], coding: ["وكيل البرمجة", "Coding Agent"], tasks: ["المهام المستقلة", "Autonomous Tasks"],
  settings: ["الإعدادات", "Settings"], audit: ["سجل التدقيق", "Audit Log"], estop: ["إيقاف طوارئ", "EMERGENCY STOP"],
  estopActive: ["الإيقاف مفعّل — إعادة تفعيل", "Stop active — re-arm"], liveDesktop: ["بث سطح المكتب المباشر", "Live Desktop View"],
  liveGame: ["بث اللعبة المباشر", "Live Game View"], aiStatus: ["حالة الذكاء الاصطناعي", "AI Status"], currentTask: ["المهمة الحالية", "Current Task"],
  progress: ["التقدم", "Progress"], connection: ["اتصال Claude", "Claude Connection"], cpu: ["المعالج", "CPU"], ram: ["الذاكرة", "RAM"],
  fps: ["FPS (البث)", "FPS (stream)"], session: ["مدة الجلسة", "Session"], recent: ["آخر الإجراءات", "Recent Actions"], idle: ["خامل", "Idle"],
  working: ["يعمل", "Working"], none: ["لا يوجد", "None"], connected: ["مفتاح API محفوظ", "API key saved"], notConnected: ["غير متصل", "Not connected"],
  send: ["إرسال", "Send"], attachShot: ["إرفاق لقطة شاشة", "Attach screenshot"], attachImg: ["إرفاق صورة", "Attach image"],
  approveRun: ["موافقة وتشغيل", "Approve & run"], newChat: ["محادثة جديدة", "New chat"], typeHere: ["اكتب طلبك…", "Type your request…"],
  selectGame: ["اختيار اللعبة", "Game adapter"], selectWindow: ["نافذة اللعبة", "Game window"], refresh: ["تحديث", "Refresh"],
  mission: ["المهمة المطلوبة", "Mission"], duration: ["المدة (دقائق)", "Duration (min)"], startPlaying: ["ابدأ اللعب", "Start Playing"],
  pause: ["إيقاف مؤقت", "Pause"], resume: ["استئناف", "Resume"], stop: ["إيقاف", "Stop"], decisions: ["قرارات الوكيل", "Agent decisions"],
  moves: ["سجل الحركات", "Move log"], errors: ["سجل الأخطاء", "Errors"], plan: ["الخطة", "Plan"], run: ["تنفيذ", "Run"],
  request: ["الطلب", "Request"], projectFolder: ["مجلد المشروع", "Project folder"], review: ["مراجعة كل تغيير قبل اعتماده", "Review every change before applying"],
  changes: ["التغييرات", "Changes"], undo: ["تراجع عن تغييرات المهمة", "Undo task changes"], save: ["حفظ", "Save"], files: ["الملفات", "Files"],
  startAt: ["وقت البدء", "Start at"], endAt: ["وقت الانتهاء", "End at"], schedule: ["جدولة", "Schedule"], kind: ["النوع", "Type"],
  status: ["الحالة", "Status"], approvalNeeded: ["مطلوب موافقتك", "Your approval is required"], approve: ["موافقة", "Approve"], deny: ["رفض", "Deny"],
  helpNeeded: ["الوكيل يطلب المساعدة", "The agent needs help"], reply: ["رد", "Reply"], message: ["تعديل المهمة أثناء العمل", "Modify the running task"],
  test: ["اختبار الاتصال", "Test connection"], language: ["اللغة", "Language"], fullscreen: ["ملء الشاشة", "Fullscreen"],
} as const;
export type Key = keyof typeof dict;
export const LangCtx = createContext<{ lang: Lang; setLang: (l: Lang) => void }>({ lang: "ar", setLang: () => {} });
export function useT() { const { lang } = useContext(LangCtx); return (k: Key) => dict[k][lang === "ar" ? 0 : 1]; }
