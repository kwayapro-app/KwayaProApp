import React, { useState, useEffect, useRef } from 'react';
import { 
  Home, Music, Mic, Calendar, MessageCircle, User, Play, 
  Pause, Square, Search, Plus, MoreVertical, ChevronLeft, 
  Settings, CheckCircle2, Pin, Bell, Moon, Sun, Mic2,
  Share2, Info, Check, Users, FileMusic, AlertCircle, ArrowRight,
  CreditCard, ClipboardCheck, GripVertical, ShieldAlert, ListOrdered,
  ChevronDown, Trash2, Link, Send, UserMinus
} from 'lucide-react';

// --- M3X CSS INJECTION (Theming, Spring Physics, A11y & Animations) ---
const themeStyles = `
  :root {
    --fn: 'Nunito', system-ui, sans-serif;
    
    /* M3X Light Theme - Warm Gold/Amber */
    --pri: #6B4F00; --on-pri: #ffffff; --pri-c: #FFD97D; --on-pri-c: #211500;
    --sec: #5D5235; --on-sec: #ffffff; --sec-c: #E8D9A0; --on-sec-c: #1C1800;
    --ter: #3C6040; --on-ter: #ffffff; --ter-c: #BCEDC0; --on-ter-c: #002107;
    --err: #BA1A1A; --on-err: #ffffff; --err-c: #FFDAD6; --on-err-c: #410002;
    
    --sur: #FFF8EF; --on-sur: #1E1B13;
    --sur-lo: #FBF3E8; --sur-c: #F5EEE2; --sur-hi: #F0E8DA; --sur-hh: #EAE2D3;
    --out: #524D42; --out-v: #CCC5B3;
    
    --spring: cubic-bezier(0.34, 1.56, 0.64, 1);
    --shared-axis: cubic-bezier(0.2, 0, 0, 1);
  }

  .dark-theme {
    /* M3X Dark Theme */
    --pri: #E8C06A; --on-pri: #381F00; --pri-c: #503300; --on-pri-c: #FFD97D;
    --sec: #CCB96E; --on-sec: #312800; --sec-c: #493E00; --on-sec-c: #E8D9A0;
    --ter: #A0D1A4; --on-ter: #063A0D; --ter-c: #1E5224; --on-ter-c: #BCEDC0;
    --err: #FFB4AB; --on-err: #690005; --err-c: #93000A; --on-err-c: #FFDAD6;
    
    --sur: #15120B; --on-sur: #EAE2D5;
    --sur-lo: #1E1B13; --sur-c: #232017; --sur-hi: #2E2A22; --sur-hh: #38352C;
    --out: #999181; --out-v: #4D4636;
  }

  body {
    background-color: #000;
    font-family: var(--fn);
    margin: 0;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    overflow: hidden;
  }

  /* M3 Typography Scale Tokens */
  .m3-display-sm { font-size: 36px; line-height: 44px; font-weight: 900; letter-spacing: 0; }
  .m3-headline-lg { font-size: 32px; line-height: 40px; font-weight: 800; letter-spacing: 0; }
  .m3-title-lg { font-size: 22px; line-height: 28px; font-weight: 800; letter-spacing: 0; }
  .m3-title-md { font-size: 16px; line-height: 24px; font-weight: 800; letter-spacing: 0.15px; }
  .m3-body-md { font-size: 14px; line-height: 20px; font-weight: 600; letter-spacing: 0.25px; }
  .m3-label-sm { font-size: 11px; line-height: 16px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; }

  /* Targeted Transitions */
  .m3-transition { 
    transition: background-color 200ms ease, color 150ms ease, transform 200ms var(--spring), 
                border-color 200ms ease, opacity 150ms ease, box-shadow 200ms ease, border-radius 200ms var(--spring); 
  }
  .m3-press:active { transform: scale(0.95); }

  /* Horizontal X-Axis Transitions & Modals */
  @keyframes slideInRight { from { opacity: 0; transform: translateX(24px); } to { opacity: 1; transform: translateX(0); } }
  @keyframes slideInLeft { from { opacity: 0; transform: translateX(-24px); } to { opacity: 1; transform: translateX(0); } }
  @keyframes slideInBottom { from { opacity: 0; transform: translateY(100%); } to { opacity: 1; transform: translateY(0); } }
  .slide-right { animation: slideInRight 0.4s var(--shared-axis) forwards; }
  .slide-left { animation: slideInLeft 0.4s var(--shared-axis) forwards; }
  .slide-in-bottom { animation: slideInBottom 0.4s var(--spring) forwards; }
  .fade-in { animation: fadeIn 0.4s ease forwards; }
  @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

  /* M3 Snackbar & M3 Circular Progress */
  @keyframes snackbarEnter { from { opacity: 0; transform: translateY(100%); } to { opacity: 1; transform: translateY(0); } }
  .snackbar-anim { animation: snackbarEnter 0.4s var(--spring) forwards; }
  @keyframes m3-spin { 0% { stroke-dashoffset: 264; transform: rotate(0deg); } 50% { stroke-dashoffset: 100; transform: rotate(135deg); } 100% { stroke-dashoffset: 264; transform: rotate(360deg); } }
  .m3-spinner circle { stroke: var(--pri); stroke-width: 4; stroke-dasharray: 264; animation: m3-spin 2s linear infinite; transform-origin: center; fill: transparent; }

  .no-scrollbar::-webkit-scrollbar { display: none; }
  .no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }
  @keyframes shimmer { 0% { background-position: -200% 0; } 100% { background-position: 200% 0; } }
  .skeleton { background: linear-gradient(90deg, var(--sur-hh) 25%, var(--out-v) 50%, var(--sur-hh) 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; border-radius: 12px; }

  @keyframes wave { 0%, 100% { transform: scaleY(0.5); } 50% { transform: scaleY(1); } }
  .wave-bar { animation: wave 1s infinite ease-in-out; transform-origin: bottom; }
  @keyframes needleDrift { 0%, 100% { transform: rotate(-30deg); } 50% { transform: rotate(-25deg); } }
  .needle-idle { animation: needleDrift 4s ease-in-out infinite; transform-origin: 100px 100px; }
`;

// --- UI COMPONENTS ---

const IconButton = ({ icon: Icon, onClick, label, variant = 'standard', className = '', disabled = false }) => {
  const baseStyle = "flex items-center justify-center min-h-[48px] min-w-[48px] rounded-full m3-transition focus:outline-none focus:ring-2 focus:ring-[var(--pri)] disabled:opacity-50 disabled:cursor-not-allowed";
  const variants = {
    standard: "text-[var(--on-sur)] hover:bg-[var(--sur-hh)] m3-press",
    filled: "bg-[var(--pri-c)] text-[var(--on-pri-c)] m3-press",
    tonal: "bg-[var(--sec-c)] text-[var(--on-sec-c)] m3-press",
  };
  return (
    <button onClick={onClick} aria-label={label} disabled={disabled} className={`${baseStyle} ${variants[variant]} ${className}`}>
      <Icon size={24} />
    </button>
  );
};

const Button = ({ children, onClick, variant = 'filled', icon: Icon, className = '', disabled = false }) => {
  const baseStyle = "flex items-center justify-center gap-2 px-6 min-h-[48px] rounded-full m3-body-md m3-transition focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-[var(--sur)] focus:ring-[var(--pri)] disabled:opacity-50 disabled:cursor-not-allowed";
  const variants = {
    filled: "bg-[var(--pri)] text-[var(--on-pri)] m3-press shadow-sm hover:shadow-md",
    tonal: "bg-[var(--sec-c)] text-[var(--on-sec-c)] m3-press",
    outlined: "border-2 border-[var(--out)] text-[var(--pri)] bg-transparent m3-press",
    text: "text-[var(--pri)] bg-transparent hover:bg-[var(--pri-c)] hover:text-[var(--on-pri-c)]",
  };
  return (
    <button onClick={onClick} disabled={disabled} className={`${baseStyle} ${variants[variant]} ${className}`}>
      {Icon && <Icon size={20} />}
      {children}
    </button>
  );
};

const Chip = ({ label, selected, onClick, icon: Icon }) => (
  <div className="py-2 inline-flex">
    <button 
      onClick={onClick}
      aria-pressed={selected}
      className={`flex items-center justify-center px-4 min-h-[32px] rounded-lg m3-body-md whitespace-nowrap m3-transition m3-press focus:outline-none focus:ring-2 focus:ring-[var(--pri)] ${
        selected ? "bg-[var(--sec-c)] text-[var(--on-sec-c)] border-2 border-transparent" : "border-2 border-[var(--out)] text-[var(--on-sur)] bg-transparent"
      }`}
    >
      {selected && <Check size={16} strokeWidth={3} className="mr-2" />}
      {!selected && Icon && <Icon size={16} className="mr-2 text-[var(--out)]" />}
      {label}
    </button>
  </div>
);

const M3FAB = ({ icon: Icon, onClick, label, variant = 'primary' }) => (
  <button 
    onClick={onClick} aria-label={label}
    className={`absolute bottom-6 right-6 min-w-[56px] min-h-[56px] rounded-[16px] flex items-center justify-center shadow-lg m3-transition m3-press hover:shadow-xl hover:rounded-[20px] focus:outline-none focus:ring-4 focus:ring-[var(--pri-c)] z-40
      ${variant === 'primary' ? 'bg-[var(--pri-c)] text-[var(--on-pri-c)]' : 'bg-[var(--ter-c)] text-[var(--on-ter-c)]'}
    `}
  >
    <Icon size={28} />
  </button>
);

const EmptyState = ({ icon: Icon, title, description, actionLabel, onAction, color = "var(--sec)" }) => (
  <div className="flex flex-col items-center justify-center h-full px-8 text-center fade-in">
    <div className="w-32 h-32 rounded-full flex items-center justify-center mb-6" style={{ backgroundColor: `${color}20`, color: color }}>
      <Icon size={56} strokeWidth={1.5} />
    </div>
    <h3 className="m3-title-lg text-[var(--on-sur)] mb-3">{title}</h3>
    <p className="m3-body-md text-[var(--out)] leading-relaxed mb-8">{description}</p>
    {actionLabel && <Button onClick={onAction} icon={Plus}>{actionLabel}</Button>}
  </div>
);

// --- GLOBAL CONTEXT ---
const AppContext = React.createContext();

// --- MAIN APPLICATION ---
// Helper to get dynamically available tabs based on role
const getTabsForRole = (role) => {
  if (role === 'Director') return ['home', 'library', 'studio', 'rehearsals', 'chat'];
  return ['home', 'library', 'rehearsals', 'chat']; // Leader + Chorister hide studio
};

// All screens deeper than the main tabs (Profile included for immersive routing)
const IMMERSIVE_SCREENS = ['studio', 'billing', 'attendance', 'planner', 'members', 'member_detail', 'guest_director', 'profile'];

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(true); 
  const [isDark, setIsDark] = useState(false);
  const [userRole, setUserRole] = useState('Leader'); // Options: 'Leader', 'Director', 'Chorister'
  
  const [currentTab, setCurrentTab] = useState('home');
  const [prevTab, setPrevTab] = useState('home');
  
  const [isLoading, setIsLoading] = useState(true);
  const [snackbar, setSnackbar] = useState({ show: false, msg: '' });
  const [dialog, setDialog] = useState({ show: false, title: '', desc: '', onConfirm: null, isDestructive: false });

  const [showEmptyStates, setShowEmptyStates] = useState(false);

  // Dynamic Tabs Evaluation
  const currentTabs = getTabsForRole(userRole);

  // Fallback safety if role changes while on a hidden tab (but ignoring immersive screens)
  useEffect(() => {
    if (!currentTabs.includes(currentTab) && !IMMERSIVE_SCREENS.includes(currentTab)) {
      setCurrentTab('home');
      setPrevTab('home');
    }
  }, [userRole, currentTab, currentTabs]);

  useEffect(() => {
    setIsLoading(true);
    const timer = setTimeout(() => setIsLoading(false), 600);
    return () => clearTimeout(timer);
  }, [currentTab, isAuthenticated]);

  useEffect(() => {
    if (dialog.show) setTimeout(() => document.getElementById('dialog-confirm')?.focus(), 50);
  }, [dialog.show]);

  const handleTabChange = (newTab) => {
    setPrevTab(currentTab);
    setCurrentTab(newTab);
  };

  const showMsg = (msg) => {
    setSnackbar({ show: true, msg });
    setTimeout(() => setSnackbar({ show: false, msg: '' }), 4000);
  };

  const confirmAction = (title, desc, onConfirm, isDestructive = false) => {
    setDialog({ show: true, title, desc, onConfirm: () => { onConfirm(); setDialog({ show: false }); }, isDestructive });
  };

  const isImmersive = IMMERSIVE_SCREENS.includes(currentTab) && isAuthenticated;
  const isLandscape = currentTab === 'studio' && isAuthenticated;
  
  const frameClass = isLandscape 
    ? "w-[820px] h-[380px] rounded-[32px] flex-row" 
    : "w-[380px] h-[820px] rounded-[40px] flex-col";

  const currIdx = currentTabs.indexOf(currentTab) !== -1 ? currentTabs.indexOf(currentTab) : 0;
  const prevIdx = currentTabs.indexOf(prevTab) !== -1 ? currentTabs.indexOf(prevTab) : 0;
  
  const slideDirectionClass = (currIdx !== -1 && prevIdx !== -1) 
    ? (currIdx > prevIdx ? 'slide-right' : currIdx < prevIdx ? 'slide-left' : 'fade-in')
    : 'fade-in';

  // Dynamic Indicator sliding math
  const indicatorWidth = 64;
  const itemWidth = 380 / currentTabs.length;
  const indicatorOffset = (currIdx * itemWidth) + ((itemWidth - indicatorWidth) / 2);

  return (
    <AppContext.Provider value={{ showMsg, confirmAction, userRole, setUserRole, setIsAuthenticated, showEmptyStates, setShowEmptyStates }}>
      <style>{themeStyles}</style>
      <div className={isDark ? 'dark-theme' : ''}>
        
        <div className={`relative bg-[var(--sur)] shadow-2xl overflow-hidden border-[8px] border-[var(--sur-hh)] flex text-[var(--on-sur)] transition-all duration-700 ease-[var(--spring)] ${frameClass}`}>
          
          {/* Status Bar */}
          {!isLandscape && (
            <div className="h-12 w-full flex justify-between items-center px-6 pt-2 z-50 bg-[var(--sur)] transition-colors duration-500 shrink-0">
              <span className="text-[14px] font-bold tracking-wider">9:41</span>
              <div className="w-32 h-7 bg-black rounded-full absolute left-1/2 -translate-x-1/2 top-1"></div>
              <div className="flex gap-2">
                <div className="w-4 h-4 rounded-full bg-[var(--on-sur)] opacity-80"></div>
                <div className="w-6 h-4 rounded-sm bg-[var(--on-sur)] opacity-80"></div>
              </div>
            </div>
          )}

          {!isAuthenticated ? (
            <div className="flex-1 w-full h-full relative fade-in bg-[var(--sur)] overflow-y-auto no-scrollbar">
              <OnboardingFlow />
            </div>
          ) : (
            <>
              <div key={currentTab} className={`flex-1 overflow-y-auto no-scrollbar relative ${isLandscape ? 'w-full h-full' : (isImmersive ? 'pb-0' : 'pb-24')} ${slideDirectionClass}`}>
                {currentTab === 'home' && <HomeScreen isLoading={isLoading} setTab={handleTabChange} />}
                {currentTab === 'library' && <LibraryScreen isLoading={isLoading} />}
                {currentTab === 'rehearsals' && <RehearsalsScreen isLoading={isLoading} setTab={handleTabChange} />}
                {currentTab === 'chat' && <ChatScreen />}
                
                {/* IMMERSIVE SCREENS */}
                {currentTab === 'profile' && <ProfileScreen isDark={isDark} setIsDark={setIsDark} setTab={handleTabChange} />}
                {currentTab === 'studio' && <StudioLandscapeScreen setTab={handleTabChange} />}
                {currentTab === 'billing' && <BillingScreen setTab={handleTabChange} />}
                {currentTab === 'attendance' && <AttendanceScreen setTab={handleTabChange} />}
                {currentTab === 'planner' && <PlannerScreen setTab={handleTabChange} />}
                {currentTab === 'members' && <MembersScreen setTab={handleTabChange} />}
                {currentTab === 'member_detail' && <MemberDetailScreen setTab={handleTabChange} />}
                {currentTab === 'guest_director' && <GuestDirectorScreen setTab={handleTabChange} />}
              </div>

              {/* M3 Snackbar */}
              {snackbar.show && (
                <div className={`absolute left-4 right-4 bg-[var(--on-sur)] text-[var(--sur)] rounded-[12px] min-h-[48px] px-4 py-3 flex items-center justify-between shadow-lg z-50 snackbar-anim ${isImmersive && !isLandscape ? 'bottom-4 max-w-sm mx-auto' : isLandscape ? 'bottom-20 max-w-sm mx-auto' : 'bottom-[100px]'}`} role="status" aria-live="polite">
                  <span className="m3-body-md">{snackbar.msg}</span>
                </div>
              )}

              {/* M3 Modal Dialog */}
              {dialog.show && (
                <div className="absolute inset-0 bg-black/50 z-[100] flex items-center justify-center p-6 m3-transition fade-in" role="dialog" aria-modal="true">
                  <div className="bg-[var(--sur-hi)] w-full max-w-sm rounded-[28px] p-6 shadow-2xl scale-100 m3-transition">
                    <div className={`w-12 h-12 rounded-full flex items-center justify-center mb-4 ${dialog.isDestructive ? 'bg-[#FFDAD6] text-[#BA1A1A] dark:bg-[#93000A] dark:text-[#FFDAD6]' : 'bg-[var(--pri-c)] text-[var(--on-pri-c)]'}`}>
                      <AlertCircle size={24} />
                    </div>
                    <h2 className="m3-title-lg mb-2">{dialog.title}</h2>
                    <p className="m3-body-md text-[var(--out)] mb-6">{dialog.desc}</p>
                    <div className="flex justify-end gap-2">
                      <Button variant="text" onClick={() => setDialog({ show: false })}>Cancel</Button>
                      <Button id="dialog-confirm" variant="filled" onClick={dialog.onConfirm} className={dialog.isDestructive ? "bg-[#BA1A1A] text-white dark:bg-[#FFB4AB] dark:text-[#690005]" : ""}>Confirm</Button>
                    </div>
                  </div>
                </div>
              )}

              {/* M3X Bottom Navigation */}
              {!isImmersive && (
                <div className="absolute bottom-0 w-full h-[88px] bg-[var(--sur-c)] border-t border-[var(--out-v)] flex justify-between items-center px-0 pb-4 z-40">
                  <div 
                    className="absolute top-[16px] h-8 bg-[var(--sec-c)] rounded-full transition-transform duration-400 ease-[var(--shared-axis)]"
                    style={{ width: `${indicatorWidth}px`, transform: `translateX(${indicatorOffset}px)` }}
                  />
                  {currentTabs.map((tabId) => {
                    const widthStyle = { width: `${100 / currentTabs.length}%` };
                    return (
                      <NavItem 
                        key={tabId}
                        style={widthStyle}
                        icon={{home: Home, library: Music, studio: Mic, rehearsals: Calendar, chat: MessageCircle}[tabId]} 
                        label={tabId.charAt(0).toUpperCase() + tabId.slice(1)} 
                        id={tabId} 
                        current={currentTab} 
                        onClick={() => handleTabChange(tabId)} 
                        badge={tabId === 'chat' ? 3 : null}
                      />
                    );
                  })}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </AppContext.Provider>
  );
}

const NavItem = ({ icon: Icon, label, id, current, onClick, badge, style }) => {
  const active = current === id;
  return (
    <button onClick={onClick} aria-label={`${label} tab`} aria-current={active ? "page" : undefined} style={style} className="flex flex-col items-center justify-center min-h-[48px] gap-1 relative focus:outline-none group z-10">
      <div className={`flex items-center justify-center w-16 h-8 rounded-full m3-transition ${active ? 'text-[var(--on-sec-c)]' : 'bg-transparent text-[var(--out)] group-hover:bg-[var(--sur-hh)]'}`}>
        <Icon size={22} strokeWidth={active ? 2.5 : 2} />
        {badge && <span className="absolute top-0 right-2 bg-[var(--err)] text-[var(--on-err)] m3-label-sm w-[18px] h-[18px] flex items-center justify-center rounded-full border-2 border-[var(--sur-c)]">{badge}</span>}
      </div>
      <span className={`m3-label-sm m3-transition tracking-wide ${active ? 'text-[var(--on-sur)]' : 'text-[var(--out)]'}`}>{label}</span>
    </button>
  );
};

// --- ONBOARDING FLOW ---
const OnboardingFlow = () => {
  const { setIsAuthenticated } = React.useContext(AppContext);
  const [step, setStep] = useState(0); 

  return (
    <div className="w-full min-h-full flex flex-col items-center justify-center p-6 text-center">
      {step === 0 && (
        <div className="fade-in w-full">
          <div className="w-32 h-32 rounded-full bg-[var(--pri)] text-[var(--on-pri)] flex items-center justify-center mx-auto mb-8 shadow-lg"><Music size={56} /></div>
          <h1 className="m3-display-sm text-[var(--on-sur)] mb-4">KwayaPro</h1>
          <p className="m3-title-md text-[var(--out)] mb-12">The digital home for African church choirs.</p>
          <Button onClick={() => setStep(1)} className="w-full h-14" icon={ArrowRight}>Get Started</Button>
        </div>
      )}
      {step === 1 && (
        <div className="fade-in w-full text-left">
          <h1 className="m3-headline-lg text-[var(--on-sur)] mb-2">Welcome</h1>
          <p className="m3-body-md text-[var(--out)] mb-8">Enter your phone number to join your choir.</p>
          <div className="flex bg-[var(--sur-hh)] rounded-[16px] p-2 border-b-2 border-[var(--out)] focus-within:border-[var(--pri)] m3-transition mb-8">
            <div className="m3-title-md text-[var(--on-sur)] px-4 py-3 border-r border-[var(--out-v)]">+256</div>
            <input type="tel" placeholder="770 123 456" className="bg-transparent border-none outline-none flex-1 px-4 m3-title-md text-[var(--on-sur)] placeholder:text-[var(--out)]" autoFocus />
          </div>
          <Button onClick={() => setStep(2)} className="w-full h-14">Send Code</Button>
        </div>
      )}
      {step === 2 && (
        <div className="fade-in w-full text-left">
          <IconButton icon={ChevronLeft} onClick={() => setStep(1)} className="mb-6 -ml-4" />
          <h1 className="m3-headline-lg text-[var(--on-sur)] mb-2">Verify Phone</h1>
          <p className="m3-body-md text-[var(--out)] mb-8">Code sent to +256 770 *** ***</p>
          <div className="flex gap-2 justify-between mb-8">
            {[4,8,3, '','',''].map((d, i) => (
              <div key={i} className={`w-12 h-14 rounded-[12px] flex items-center justify-center m3-title-lg ${d ? 'bg-[var(--sur-hh)] text-[var(--on-sur)] border-2 border-[var(--sec)]' : 'bg-[var(--sur-lo)] border-2 border-[var(--out-v)] text-[var(--out)]'}`}>{d || '·'}</div>
            ))}
          </div>
          <Button onClick={() => setStep(3)} className="w-full h-14">Verify & Continue</Button>
        </div>
      )}
      {step === 3 && (
        <div className="fade-in w-full text-left">
          <h1 className="m3-headline-lg text-[var(--on-sur)] mb-2">Your Profile</h1>
          <p className="m3-body-md text-[var(--out)] mb-8">How should the choir know you?</p>
          <div className="w-24 h-24 rounded-full bg-[var(--sur-hh)] flex items-center justify-center text-[var(--out)] mx-auto mb-8 m3-press"><Plus size={32} /></div>
          <div className="bg-[var(--sur-hh)] rounded-[16px] p-2 border-b-2 border-[var(--out)] focus-within:border-[var(--pri)] m3-transition mb-8">
            <input type="text" placeholder="Full Name" defaultValue="Simon Peter" className="bg-transparent border-none outline-none w-full px-4 py-3 m3-title-md text-[var(--on-sur)]" />
          </div>
          <Button onClick={() => setStep(4)} className="w-full h-14">Next</Button>
        </div>
      )}
      {step === 4 && (
        <div className="fade-in w-full text-left">
          <h1 className="m3-headline-lg text-[var(--on-sur)] mb-8">Join or Create</h1>
          <div onClick={() => setStep(5)} className="bg-[var(--pri-c)] text-[var(--on-pri-c)] rounded-[24px] p-6 mb-4 m3-press cursor-pointer border border-[var(--pri)] border-opacity-20 shadow-sm">
            <div className="w-12 h-12 bg-[var(--pri)] text-[var(--on-pri)] rounded-full flex items-center justify-center mb-4"><Users size={24} /></div>
            <h3 className="m3-title-lg mb-1">Join a Choir</h3>
            <p className="m3-body-md opacity-80">I have an invite link or code.</p>
          </div>
          <div onClick={() => setStep(5)} className="bg-[var(--sur-c)] text-[var(--on-sur)] rounded-[24px] p-6 m3-press cursor-pointer border border-[var(--out-v)]">
            <div className="w-12 h-12 bg-[var(--ter-c)] text-[var(--ter)] rounded-full flex items-center justify-center mb-4"><Plus size={24} /></div>
            <h3 className="m3-title-lg mb-1">Create a Choir</h3>
            <p className="m3-body-md text-[var(--out)]">I am a director or leader.</p>
          </div>
        </div>
      )}
      {step === 5 && (
        <div className="fade-in w-full text-left">
          <h1 className="m3-headline-lg text-[var(--on-sur)] mb-2">Voice Part</h1>
          <p className="m3-body-md text-[var(--out)] mb-8">What part do you sing? We'll personalize your practice view.</p>
          <div className="space-y-3 mb-12">
            {['Soprano', 'Alto', 'Tenor', 'Bass'].map((p, i) => (
              <button key={p} className={`w-full text-left p-5 rounded-[20px] m3-title-md m3-transition focus:outline-none focus:ring-2 focus:ring-[var(--pri)] ${i === 1 ? 'bg-[var(--pri)] text-[var(--on-pri)] shadow-md' : 'bg-[var(--sur-c)] border border-[var(--out-v)] text-[var(--on-sur)] hover:bg-[var(--sur-hh)]'}`}>{p}</button>
            ))}
          </div>
          <Button onClick={() => setIsAuthenticated(true)} className="w-full h-14" icon={CheckCircle2}>Finish Setup</Button>
        </div>
      )}
    </div>
  );
};

// --- CORE SCREENS ---

const HomeScreen = ({ isLoading, setTab }) => {
  const { userRole, showMsg } = React.useContext(AppContext);
  const [showChoirSwitcher, setShowChoirSwitcher] = useState(false);
  
  const isLeader = userRole === 'Leader';
  const isDirector = userRole === 'Director'; 
  const isManagement = isLeader || isDirector;

  return (
    <div className="px-4 pt-4 pb-6 relative">
      <div className="flex justify-between items-center mb-6 pl-2">
        <div>
          <p className="m3-label-sm text-[var(--out)]">Good morning ☀️</p>
          <h1 className="m3-headline-lg text-[var(--on-sur)]">Simon Peter</h1>
        </div>
        <button onClick={() => setTab('profile')} aria-label="Profile" className="min-w-[48px] min-h-[48px] rounded-full bg-[var(--pri-c)] text-[var(--on-pri-c)] flex items-center justify-center font-black text-lg m3-press relative shadow-sm">SP</button>
      </div>

      <div className="bg-[var(--pri-c)] text-[var(--on-pri-c)] rounded-[32px] p-6 relative overflow-hidden shadow-sm mb-8">
        <div className="absolute top-0 right-0 p-5">
          <span className="bg-[var(--pri)] text-[var(--on-pri)] m3-label-sm px-3 py-1.5 rounded-full">PRO TIER</span>
        </div>
        <p className="m3-label-sm opacity-70 mb-1 flex items-center gap-1"><Users size={14}/> YOUR CHOIR</p>
        
        {/* Choir Switcher Trigger */}
        <button onClick={() => setShowChoirSwitcher(true)} className="flex items-center gap-1 m3-title-lg mb-1 hover:opacity-80 m3-transition focus:outline-none text-left">
          St. Agnes Parish <ChevronDown size={20} className="mt-0.5" />
        </button>

        <p className="m3-body-md opacity-80 mb-6">{isLeader ? 'Leader Dashboard' : isDirector ? 'Director Dashboard' : 'Active Member'}</p>
        
        {isManagement ? (
          <div className="flex gap-3">
            <div className="flex-1 bg-white/20 rounded-[20px] p-3 text-center">
              <div className="m3-title-lg">42</div><div className="m3-label-sm opacity-80 mt-1">Members</div>
            </div>
            <div className="flex-1 bg-white/20 rounded-[20px] p-3 text-center">
              <div className="m3-title-lg">18</div><div className="m3-label-sm opacity-80 mt-1">Songs</div>
            </div>
            <div className="flex-1 bg-white/20 rounded-[20px] p-3 text-center">
              <div className="m3-title-lg">82%</div><div className="m3-label-sm opacity-80 mt-1">Attend</div>
            </div>
          </div>
        ) : (
          <div className="bg-white/20 rounded-[20px] p-4 flex items-center justify-between">
            <div><div className="m3-label-sm opacity-80">Your Attendance</div><div className="m3-display-sm">94%</div></div>
            <CheckCircle2 size={32} className="opacity-80" />
          </div>
        )}
      </div>

      {isManagement && (
        <div className="mb-8">
          <h3 className="m3-label-sm text-[var(--out)] mb-3 ml-2 flex items-center gap-2"><Settings size={16}/> MANAGEMENT & ADMIN</h3>
          <div className="grid grid-cols-2 gap-3">
            <Button icon={ListOrdered} variant="tonal" onClick={() => setTab('planner')} className={`h-14 rounded-[16px] justify-start px-4 ${isDirector ? 'col-span-2' : ''}`}>Programs</Button>
            {isLeader && (
              <>
                <Button icon={CreditCard} variant="tonal" onClick={() => setTab('billing')} className="h-14 rounded-[16px] justify-start px-4">Billing</Button>
                <Button icon={Users} variant="tonal" onClick={() => setTab('members')} className="h-14 rounded-[16px] justify-start px-4 col-span-2">Manage Members & Permissions</Button>
              </>
            )}
          </div>
        </div>
      )}

      <div className="space-y-6">
        <div>
          <h3 className="m3-label-sm text-[var(--out)] mb-3 ml-2 flex items-center gap-2"><Calendar size={16}/> UPCOMING</h3>
          <div className="bg-[var(--sur-c)] rounded-[28px] p-5 flex gap-4 items-center m3-press cursor-pointer border border-[var(--out-v)] border-opacity-30">
            <div className="w-16 h-16 rounded-[20px] bg-[var(--ter-c)] text-[var(--on-ter-c)] flex flex-col items-center justify-center">
              <span className="m3-label-sm">APR</span><span className="m3-title-lg leading-none mt-1">27</span>
            </div>
            <div className="flex-1">
              <h4 className="m3-title-md text-[var(--on-sur)]">Sunday Mass Prep</h4>
              <p className="m3-body-md text-[var(--out)] mt-1">10:00 AM • Main Hall</p>
            </div>
          </div>
        </div>
        <div>
          <h3 className="m3-label-sm text-[var(--out)] mb-3 ml-2 flex items-center gap-2"><Mic2 size={16}/> CONTINUE PRACTICING</h3>
          <div className="bg-[var(--sur-hi)] rounded-[28px] p-4 flex gap-4 items-center m3-press shadow-sm">
            <div className="w-14 h-14 rounded-[20px] bg-[var(--sec-c)] text-[var(--on-sec-c)] flex items-center justify-center shrink-0"><Music size={28} /></div>
            <div className="flex-1 min-w-0">
              <h4 className="m3-title-md text-[var(--on-sur)] truncate">Tukutendereza Yesu</h4>
              <p className="m3-body-md text-[var(--out)] mt-0.5 truncate">Alto Part • Chorus</p>
            </div>
            <IconButton icon={Play} variant="filled" label="Play Alto Part" className="w-12 h-12 shrink-0 shadow-md" />
          </div>
        </div>
      </div>

      {/* Multi-Choir Switcher Bottom Sheet - AUDIT FIX: absolute inset-0 scope */}
      {showChoirSwitcher && (
        <div className="absolute inset-0 bg-black/50 z-50 flex flex-col justify-end fade-in" onClick={() => setShowChoirSwitcher(false)}>
          <div className="bg-[var(--sur-hi)] w-full rounded-t-[28px] p-6 slide-in-bottom shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="w-10 h-1 bg-[var(--out-v)] rounded-full mx-auto mb-6"></div>
            <h3 className="m3-title-lg mb-2">Switch Choir</h3>
            <p className="m3-body-md text-[var(--out)] mb-6">You are a member of 2 choirs.</p>

            <div className="space-y-3 mb-6">
              <button className="w-full flex items-center justify-between p-4 bg-[var(--pri-c)] rounded-[20px] m3-press focus:outline-none border border-[var(--pri)] border-opacity-20">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-full bg-[var(--pri)] text-[var(--on-pri)] flex items-center justify-center">
                    <Music size={20} />
                  </div>
                  <div className="text-left">
                    <h4 className="m3-title-md text-[var(--on-pri-c)]">St. Agnes Parish</h4>
                    <p className="m3-label-sm text-[var(--pri)] mt-1">Role: {userRole}</p>
                  </div>
                </div>
                <CheckCircle2 size={24} className="text-[var(--pri)]" />
              </button>

              <button onClick={() => { showMsg("Switched to Christ the King"); setShowChoirSwitcher(false); }} className="w-full flex items-center justify-between p-4 bg-[var(--sur-c)] rounded-[20px] m3-press focus:outline-none border border-[var(--out-v)]">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-full bg-[var(--sur-hh)] text-[var(--out)] flex items-center justify-center">
                    <Music size={20} />
                  </div>
                  <div className="text-left">
                    <h4 className="m3-title-md text-[var(--on-sur)]">Christ the King</h4>
                    <p className="m3-label-sm text-[var(--out)] mt-1">Role: Chorister</p>
                  </div>
                </div>
              </button>
            </div>

            <Button variant="outlined" className="w-full h-14" icon={Plus} onClick={() => { showMsg("Opening Join/Create flow"); setShowChoirSwitcher(false); }}>
              Join or Create Another
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

const LibraryScreen = ({ isLoading }) => {
  const [filter, setFilter] = useState('All');
  const { showMsg, showEmptyStates, userRole } = React.useContext(AppContext);

  return (
    <div className="flex flex-col h-full">
      <div className="px-4 pt-6 pb-2 sticky top-0 bg-[var(--sur)] z-10">
        <h1 className="m3-headline-lg text-[var(--on-sur)] mb-4 pl-2">Library</h1>
        <div className="flex items-center bg-[var(--sur-hh)] min-h-[56px] rounded-full px-5 mb-4 border-2 border-transparent focus-within:border-[var(--pri)] m3-transition shadow-sm">
          <Search size={22} className="text-[var(--out)]" />
          <input type="text" placeholder="Search songs, keys, tags..." className="bg-transparent border-none outline-none flex-1 ml-3 m3-title-md text-[var(--on-sur)] placeholder:text-[var(--out)] placeholder:font-semibold" />
        </div>
        <div className="flex gap-2 overflow-x-auto no-scrollbar pb-2 pt-1">
          {['All', 'Soprano', 'Alto', 'Tenor', 'Bass'].map(f => (
            <Chip key={f} label={f} selected={filter === f} onClick={() => setFilter(f)} />
          ))}
        </div>
      </div>

      <div className="px-4 space-y-3 mt-2 pb-8">
        {isLoading ? (
          Array.from({length: 4}).map((_, i) => (
            <div key={i} className="flex gap-4 items-center p-4 bg-[var(--sur-c)] rounded-[24px]">
              <div className="w-14 h-14 rounded-[18px] skeleton shrink-0"></div>
              <div className="flex-1 space-y-3">
                <div className="h-4 w-2/3 skeleton"></div>
                <div className="h-3 w-1/3 skeleton"></div>
              </div>
            </div>
          ))
        ) : showEmptyStates ? (
          <EmptyState 
            icon={FileMusic} 
            title="No Songs Yet" 
            description="Your choir's library is empty. Start building your digital repertoire by adding your first sheet music or audio track."
            actionLabel={userRole !== 'Chorister' ? "Add First Song" : null}
            onAction={() => showMsg("Opening 'Add Song' flow...")}
            color="var(--pri)"
          />
        ) : (
          <>
            <div className="bg-[var(--pri-c)] text-[var(--on-pri-c)] rounded-[16px] px-4 py-3 mb-2 flex items-center justify-between">
              <span className="m3-label-sm"><Info size={16} className="inline mr-2 -mt-0.5"/>YOUR PART: ALTO</span>
              <span className="m3-body-md opacity-80 text-[12px]">Tap parts to listen</span>
            </div>
            <ul aria-label="Song library" className="space-y-3 m-0 p-0 list-none">
              <SongItem title="Nkwagala Omukama" subtitle="Praise · Key of G" parts={['S','A','T','B']} userPart="A" iconBg="bg-[var(--pri-c)]" iconColor="text-[var(--on-pri-c)]" />
              <SongItem title="Holy Holy Holy" subtitle="Mass · Key of Bb" parts={['S','A','T','B']} userPart="A" iconBg="bg-[var(--sec-c)]" iconColor="text-[var(--on-sec-c)]" />
              <SongItem title="Tukutendereza Yesu" subtitle="Worship · Key of F" parts={['S','A','B']} userPart="A" iconBg="bg-[var(--ter-c)]" iconColor="text-[var(--on-ter-c)]" />
            </ul>
          </>
        )}
      </div>
      {userRole !== 'Chorister' && <M3FAB icon={Plus} label="Add new song" onClick={() => showMsg("Opening Add Song flow...")} />}
    </div>
  );
};

const SongItem = ({ title, subtitle, parts, userPart, iconBg, iconColor }) => (
  <li className="flex items-center gap-4 p-4 rounded-[24px] bg-[var(--sur-c)] hover:bg-[var(--sur-hi)] m3-transition m3-press border border-[var(--out-v)] border-opacity-40">
    <button className="flex items-center gap-4 flex-1 min-w-0 text-left focus:outline-none rounded-xl" aria-label={`Play ${title}`}>
      <div className={`w-14 h-14 rounded-[18px] ${iconBg} ${iconColor} flex items-center justify-center shrink-0 shadow-sm`}><Music size={24} /></div>
      <div className="flex-1 min-w-0">
        <h4 className="m3-title-md text-[var(--on-sur)] truncate">{title}</h4>
        <p className="m3-body-md text-[var(--out)] mt-1">{subtitle}</p>
        <div className="flex gap-1.5 mt-3">
          {parts.map(p => (
            <span key={p} className={`m3-label-sm px-2.5 py-1 rounded-md border ${p === userPart ? 'bg-[var(--sec-c)] text-[var(--on-sec-c)] border-[var(--sec)]' : 'bg-[var(--sur-hh)] text-[var(--on-sur)] border-transparent'}`}>{p}</span>
          ))}
        </div>
      </div>
    </button>
    <IconButton icon={MoreVertical} label={`Options`} variant="standard" className="w-12 h-12 shrink-0 -mr-2" />
  </li>
);

const RehearsalsScreen = ({ isLoading, setTab }) => {
  const { confirmAction, showMsg, userRole, showEmptyStates } = React.useContext(AppContext);

  const handleRSVP = () => {
    confirmAction(
      "Confirm Attendance", 
      "Mark yourself as 'Going' to Sunday Mass Prep? This helps the director plan the sections.",
      () => showMsg("RSVP Confirmed for Sunday Mass Prep!")
    );
  };

  const isManagement = userRole === 'Director' || userRole === 'Leader';

  return (
    <div className="px-4 pt-6 pb-8 h-full flex flex-col">
      <h1 className="m3-headline-lg text-[var(--on-sur)] mb-6 pl-2">Schedule</h1>
      
      {isLoading ? (
        <div className="space-y-4">
          <div className="h-48 w-full skeleton rounded-[32px]"></div>
          <div className="h-48 w-full skeleton rounded-[32px]"></div>
        </div>
      ) : showEmptyStates ? (
        <div className="flex-1">
          <EmptyState 
            icon={Calendar} 
            title="No Upcoming Rehearsals" 
            description="Your choir hasn't scheduled any sessions yet. Directors can schedule practices to notify members."
            actionLabel={isManagement ? "Schedule Session" : null}
            color="var(--sec)"
          />
        </div>
      ) : (
        <div className="space-y-5">
          <div className="border-2 border-[var(--pri)] rounded-[32px] p-6 bg-[var(--sur)] relative overflow-hidden shadow-sm">
            <div className="absolute top-0 left-0 w-3 h-full bg-[var(--pri)]"></div>
            <div className="flex justify-between items-start mb-4 pl-2">
              <div>
                <h3 className="m3-title-lg text-[var(--on-sur)]">Sunday Mass Prep</h3>
                <p className="m3-body-md text-[var(--out)] mt-1">27 Apr • 10:00 AM</p>
              </div>
              <div className="bg-[var(--pri-c)] text-[var(--on-pri-c)] m3-label-sm px-3.5 py-1.5 rounded-full shadow-sm">Next</div>
            </div>
            <div className="flex items-center gap-3 mb-6 pl-2">
              <Pin size={18} className="text-[var(--out)]" />
              <span className="m3-body-md text-[var(--on-sur)]">Main Parish Hall</span>
            </div>

            {isManagement && (
              <div className="flex gap-2 mb-4">
                <Button variant="tonal" icon={ClipboardCheck} onClick={() => setTab('attendance')} className="flex-1 h-14 px-4">Attendance</Button>
                <Button variant="outlined" icon={User} onClick={() => setTab('guest_director')} className="flex-1 h-14 px-4">Guest</Button>
              </div>
            )}

            <div className="bg-[var(--sur-hh)] rounded-[20px] p-1.5 flex gap-1 shadow-inner">
              <button onClick={handleRSVP} className="flex-1 min-h-[48px] m3-body-md bg-[var(--sec-c)] text-[var(--on-sec-c)] rounded-[16px] m3-transition flex justify-center items-center gap-2 shadow-sm focus:outline-none"><CheckCircle2 size={18}/> Going</button>
              <button className="flex-1 min-h-[48px] m3-body-md text-[var(--out)] hover:bg-[var(--sur-lo)] rounded-[16px] m3-transition">Maybe</button>
              <button className="flex-1 min-h-[48px] m3-body-md text-[var(--out)] hover:bg-[var(--sur-lo)] rounded-[16px] m3-transition">Can't</button>
            </div>
          </div>

          <div className="border-2 border-[var(--out-v)] rounded-[32px] p-6 bg-[var(--sur-lo)] opacity-85">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h3 className="m3-title-lg text-[var(--on-sur)]">Wednesday Practice</h3>
                <p className="m3-body-md text-[var(--out)] mt-1">30 Apr • 6:00 PM</p>
              </div>
            </div>
            <div className="bg-[var(--sur-hh)] rounded-[20px] p-1.5 flex gap-1">
              <button className="flex-1 min-h-[48px] m3-body-md text-[var(--out)] hover:bg-[var(--sur-c)] rounded-[16px] m3-transition">Going</button>
              <button className="flex-1 min-h-[48px] m3-body-md bg-[var(--out-v)] text-[var(--sur)] rounded-[16px] m3-transition shadow-sm">Maybe</button>
              <button className="flex-1 min-h-[48px] m3-body-md text-[var(--out)] hover:bg-[var(--sur-c)] rounded-[16px] m3-transition">Can't</button>
            </div>
          </div>
        </div>
      )}
      {(!showEmptyStates && isManagement) && <M3FAB icon={Plus} label="Schedule new rehearsal" />}
    </div>
  );
};

const ChatScreen = () => {
  const { showEmptyStates, showMsg, userRole } = React.useContext(AppContext);
  const [isRecording, setIsRecording] = useState(false);
  const [targetPart, setTargetPart] = useState('All');

  if (showEmptyStates) {
    return (
      <div className="h-[calc(100vh-136px)]">
        <EmptyState 
          icon={MessageCircle} 
          title="No Messages Yet" 
          description="Start the conversation! Share an update, ask a question about a song, or send a voice note to the choir."
          actionLabel="Send First Message"
          color="var(--ter)"
        />
      </div>
    );
  }

  return (
    <div className="flex flex-col h-[calc(100vh-136px)] bg-[var(--sur-lo)] relative">
      <div className="flex items-center gap-3 px-4 py-4 bg-[var(--sur)] shadow-sm z-10 border-b border-[var(--out-v)]">
        <div className="w-12 h-12 rounded-full bg-[var(--pri-c)] text-[var(--on-pri-c)] flex items-center justify-center font-black text-[15px]">SA</div>
        <div className="flex-1">
          <h2 className="m3-title-md text-[var(--on-sur)]">St. Agnes Choir</h2>
          <p className="m3-body-md text-[var(--ter)]">● 8 members online</p>
        </div>
        <IconButton icon={MoreVertical} label="Chat Options" variant="standard" />
      </div>
      <div className="mx-4 mt-5 bg-[var(--pri-c)] rounded-[20px] p-4 flex gap-4 shadow-sm border border-[var(--pri)] border-opacity-20 relative overflow-hidden">
        <div className="absolute left-0 top-0 bottom-0 w-2 bg-[var(--pri)]"></div>
        <Pin size={20} className="text-[var(--pri)] shrink-0 mt-0.5" />
        <div className="flex-1">
          <p className="m3-label-sm text-[var(--pri)] mb-1">PINNED BY DIRECTOR</p>
          <p className="m3-body-md text-[var(--on-pri-c)]">Sunday rehearsal is MANDATORY. Bring your music copies.</p>
        </div>
        <IconButton icon={Share2} label="Share to WhatsApp" variant="tonal" className="w-10 h-10 self-center shrink-0" onClick={() => showMsg("Opening WhatsApp sharing...")}/>
      </div>
      <ol aria-label="Choir chat messages" aria-live="polite" aria-relevant="additions" className="flex-1 overflow-y-auto p-4 space-y-6 pt-6 m-0 list-none">
        <li className="flex gap-3 items-end">
          <div className="w-10 h-10 rounded-full bg-[var(--sec-c)] text-[var(--on-sec-c)] flex items-center justify-center font-black text-[12px] shrink-0">VK</div>
          <div>
            <div className="bg-[var(--sur-hh)] text-[var(--on-sur)] rounded-[24px] rounded-bl-md p-4 max-w-[260px] shadow-sm"><p className="m3-body-md">Sopranos, please review the Chorus part before Sunday 🎵</p></div>
            <p className="m3-label-sm text-[var(--out)] mt-1.5 ml-2">9:42 AM</p>
          </div>
        </li>
      </ol>

      <div className="p-3 bg-[var(--sur)] border-t border-[var(--out-v)] flex flex-col gap-2 z-20">
        {userRole !== 'Chorister' && (
          <div className="flex gap-2">
            <button className="m3-label-sm flex items-center gap-1 bg-[var(--sur-hh)] text-[var(--on-sur)] px-3 py-1.5 rounded-full m3-press">
              To: {targetPart} <ChevronDown size={14} />
            </button>
          </div>
        )}

        <div className="flex items-center gap-2">
          {isRecording ? (
            <div className="flex-1 bg-[var(--err-c)] rounded-full flex items-center px-4 min-h-[56px] justify-between shadow-sm slide-in-bottom">
              <div className="flex items-center gap-3">
                <div className="w-3 h-3 bg-[var(--err)] rounded-full animate-pulse"></div>
                <span className="m3-body-md text-[var(--err)] font-mono">0:04</span>
              </div>
              <span className="m3-body-md text-[var(--err)] font-bold">Recording...</span>
              <IconButton icon={Trash2} variant="standard" className="text-[var(--err)] w-10 h-10 hover:bg-[var(--err)] hover:text-white" onClick={() => setIsRecording(false)} />
            </div>
          ) : (
            <div className="flex-1 bg-[var(--sur-hh)] rounded-full flex items-center px-5 min-h-[56px] focus-within:ring-2 ring-[var(--pri)]">
              <input type="text" placeholder="Message the choir..." className="bg-transparent border-none outline-none flex-1 m3-body-md text-[var(--on-sur)] placeholder:text-[var(--out)]" aria-label="Type message" />
            </div>
          )}
          
          {isRecording ? (
            <IconButton icon={Send} variant="filled" label="Send Voice Note" className="min-w-[56px] min-h-[56px] shadow-sm slide-in-bottom" onClick={() => { setIsRecording(false); showMsg("Voice note sent" + (userRole !== 'Chorister' ? " to " + targetPart : "")); }} />
          ) : (
            <IconButton icon={Mic} variant="tonal" label="Record Voice Note" className="min-w-[56px] min-h-[56px] bg-[var(--sur-hh)]" onClick={() => setIsRecording(true)} />
          )}
        </div>
      </div>
    </div>
  );
};

// --- SETTINGS / PROFILE SCREEN ---
const ProfileScreen = ({ isDark, setIsDark, setTab }) => {
  const { confirmAction, userRole, setUserRole, setIsAuthenticated, showEmptyStates, setShowEmptyStates } = React.useContext(AppContext);

  return (
    <div className="px-4 pt-6 pb-12 w-full h-full bg-[var(--sur)] absolute z-30">
      <div className="flex justify-between items-center mb-8">
        <IconButton icon={ChevronLeft} onClick={() => setTab('home')} label="Back" variant="standard" />
        <h1 className="m3-title-lg text-[var(--on-sur)]">Settings</h1>
        <div className="w-12 h-12"></div>
      </div>
      <div className="flex flex-col items-center mb-10">
        <div className="w-28 h-28 rounded-full bg-[var(--pri)] text-[var(--on-pri)] flex items-center justify-center text-4xl font-black mb-5 relative shadow-lg m3-press cursor-pointer">
          SP
          <button aria-label="Edit Photo" className="absolute bottom-0 right-0 w-10 h-10 bg-[var(--sec-c)] text-[var(--on-sec-c)] rounded-full border-4 border-[var(--sur)] flex items-center justify-center m3-transition hover:scale-110"><Settings size={18} /></button>
        </div>
        <h2 className="m3-headline-lg text-[var(--on-sur)] mb-1">Simon Peter</h2>
        <p className="m3-body-md text-[var(--out)]">{userRole} • Tenor</p>
      </div>
      <div className="space-y-3">
        <h3 className="m3-label-sm text-[var(--out)] mb-4 ml-4 mt-8">PREFERENCES</h3>
        
        <div className="bg-[var(--sur-c)] rounded-[24px] p-3 flex items-center justify-between border border-[var(--out-v)] border-opacity-30 m3-press cursor-pointer">
          <div className="flex items-center gap-4 pl-3">
            <div className="w-12 h-12 rounded-[16px] bg-[var(--sur-hi)] flex items-center justify-center text-[var(--out)]">{isDark ? <Moon size={24} /> : <Sun size={24} />}</div>
            <span className="m3-title-md text-[var(--on-sur)]">Dark Mode</span>
          </div>
          <button onClick={() => setIsDark(!isDark)} role="switch" aria-checked={isDark} aria-label="Toggle Dark Mode" className={`w-16 h-10 rounded-full p-1.5 m3-transition flex items-center focus:outline-none focus:ring-2 focus:ring-offset-2 ring-offset-[var(--sur-c)] ring-[var(--pri)] ${isDark ? 'bg-[var(--pri)]' : 'bg-[var(--out-v)]'}`}>
            <div className={`w-7 h-7 rounded-full m3-transition ${isDark ? 'bg-[var(--on-pri)] translate-x-6' : 'bg-[var(--sur)] translate-x-0'}`}></div>
          </button>
        </div>

        <div className="bg-[var(--sur-c)] rounded-[24px] p-3 flex items-center justify-between border border-[var(--out-v)] border-opacity-30 m3-press cursor-pointer">
          <div className="flex items-center gap-4 pl-3">
            <div className="w-12 h-12 rounded-[16px] bg-[var(--sur-hi)] flex items-center justify-center text-[var(--sec)]"><Info size={24} /></div>
            <div><span className="m3-title-md text-[var(--on-sur)] block">Empty States</span><span className="m3-body-md text-[var(--out)] text-[12px]">Simulate fresh account</span></div>
          </div>
          <button onClick={() => setShowEmptyStates(!showEmptyStates)} role="switch" aria-checked={showEmptyStates} aria-label="Toggle Empty States" className={`w-16 h-10 rounded-full p-1.5 m3-transition flex items-center focus:outline-none ${showEmptyStates ? 'bg-[var(--sec)]' : 'bg-[var(--out-v)]'}`}>
            <div className={`w-7 h-7 rounded-full m3-transition ${showEmptyStates ? 'bg-[var(--on-sec)] translate-x-6' : 'bg-[var(--sur)] translate-x-0'}`}></div>
          </button>
        </div>

        <h3 className="m3-label-sm text-[var(--out)] mb-4 ml-4 mt-8">PROTOTYPE CONTROLS</h3>
        <div className="bg-[var(--sur-c)] rounded-[24px] p-3 flex flex-col border border-[var(--out-v)] border-opacity-30">
          <div className="flex items-center gap-4 pl-3 mb-3 mt-1">
            <div className="w-10 h-10 rounded-[16px] bg-[var(--sur-hi)] flex items-center justify-center text-[var(--ter)]"><Users size={20} /></div>
            <div>
              <span className="m3-title-md text-[var(--on-sur)] block">Switch Role</span>
              <span className="m3-body-md text-[var(--out)] text-[12px]">Cycles access surfaces</span>
            </div>
          </div>
          <div className="flex bg-[var(--sur-hh)] rounded-full p-1 shadow-inner">
            {['Leader', 'Director', 'Chorister'].map(r => (
              <button key={r} onClick={() => setUserRole(r)} className={`flex-1 py-1.5 m3-label-sm rounded-full m3-transition focus:outline-none ${userRole === r ? 'bg-[var(--ter)] text-[var(--on-ter)] shadow-md' : 'text-[var(--out)]'}`}>{r}</button>
            ))}
          </div>
        </div>
        
        <h3 className="m3-label-sm text-[var(--err)] mb-4 ml-4 mt-10">DANGER ZONE</h3>
        <button onClick={() => confirmAction("Sign Out", "Are you sure you want to log out of KwayaPro?", () => { setIsAuthenticated(false); }, true)} className="w-full bg-[#FFDAD6] dark:bg-[#93000A] rounded-[24px] p-3 flex items-center justify-between m3-press focus:outline-none focus:ring-2 focus:ring-[#BA1A1A]">
          <div className="flex items-center gap-4 pl-3">
            <div className="w-12 h-12 rounded-[16px] bg-white/30 flex items-center justify-center text-[#BA1A1A] dark:text-[#FFDAD6]"><User size={24} /></div>
            <span className="m3-title-md text-[#BA1A1A] dark:text-[#FFDAD6]">Sign Out</span>
          </div>
        </button>
      </div>
    </div>
  );
};

// --- IMMERSIVE SCREENS (Admin & Studio) ---

const BillingScreen = ({ setTab }) => {
  const [step, setStep] = useState(0); 

  useEffect(() => {
    if (step === 2) {
      const timer = setTimeout(() => setStep(3), 2500);
      return () => clearTimeout(timer);
    }
  }, [step]);

  return (
    <div className="h-full flex flex-col bg-[var(--sur)]">
      <div className="px-4 py-4 flex items-center justify-between">
        <IconButton icon={ChevronLeft} onClick={() => setTab('home')} label="Back" />
        <h2 className="m3-title-lg">KwayaPro Pro</h2>
        <div className="w-12 h-12"></div>
      </div>
      <div className="flex-1 flex flex-col p-6 text-center">
        {step === 0 && (
          <div className="fade-in flex flex-col h-full">
            <div className="w-24 h-24 rounded-full bg-gradient-to-br from-[var(--pri-c)] to-[var(--ter-c)] mx-auto mb-6 flex items-center justify-center shadow-lg border-4 border-[var(--sur-c)]"><Music size={40} className="text-[var(--on-pri-c)]" /></div>
            <h3 className="m3-headline-lg mb-2">Unlock Pro</h3>
            <p className="m3-body-md text-[var(--out)] mb-8">You've reached the 3-song limit on the free tier. Upgrade for unlimited features.</p>
            <div className="bg-[var(--pri-c)] rounded-[24px] p-6 mb-8 text-left text-[var(--on-pri-c)] shadow-sm">
              <h4 className="m3-title-lg mb-4 text-center">UGX 40,000<span className="text-[14px] opacity-70"> / month</span></h4>
              <ul className="space-y-4 m3-body-md">
                <li className="flex gap-3"><CheckCircle2 size={20} className="text-[var(--pri)]" /> Unlimited songs & parts</li>
                <li className="flex gap-3"><CheckCircle2 size={20} className="text-[var(--pri)]" /> Program Planner</li>
                <li className="flex gap-3"><CheckCircle2 size={20} className="text-[var(--pri)]" /> Attendance Analytics</li>
              </ul>
            </div>
            <div className="mt-auto"><Button onClick={() => setStep(1)} className="w-full h-14">Upgrade Now</Button></div>
          </div>
        )}
        {step === 1 && (
          <div className="fade-in flex flex-col h-full text-left">
            <h3 className="m3-title-lg mb-6">Select Payment</h3>
            <div className="space-y-4 mb-8">
              <button onClick={() => setStep(2)} className="w-full bg-[#FFCC00] text-black rounded-[24px] p-5 flex items-center justify-between m3-press focus:outline-none focus:ring-4 focus:ring-black/20 shadow-sm border border-black/10">
                <div className="flex items-center gap-4"><div className="w-12 h-12 bg-black text-white rounded-full flex items-center justify-center font-black">MTN</div><span className="m3-title-md font-black">MTN MoMo</span></div>
                <ArrowRight size={20} />
              </button>
            </div>
            <div className="bg-[var(--sur-c)] p-4 rounded-[20px]">
              <p className="m3-label-sm text-[var(--out)] mb-2">ENTER PHONE NUMBER</p>
              <div className="flex bg-[var(--sur)] rounded-[12px] p-2 border-b-2 border-[var(--pri)]">
                <div className="m3-title-md px-3 py-2 border-r border-[var(--out-v)]">+256</div>
                <input type="tel" defaultValue="770123456" className="bg-transparent border-none outline-none flex-1 px-4 m3-title-md text-[var(--on-sur)]" />
              </div>
            </div>
          </div>
        )}
        {step === 2 && (
          <div className="fade-in flex flex-col items-center justify-center h-full">
            <div className="w-20 h-20 mb-6 relative m3-spinner">
              <svg viewBox="0 0 100 100" className="w-full h-full"><circle cx="50" cy="50" r="42" /></svg>
            </div>
            <h3 className="m3-title-lg mb-2">Check Your Phone</h3>
            <p className="m3-body-md text-[var(--out)]">Please enter your PIN on the prompt sent to +256 770123456.</p>
          </div>
        )}
        {step === 3 && (
          <div className="fade-in flex flex-col items-center justify-center h-full">
            <div className="w-32 h-32 rounded-full bg-[var(--ter-c)] text-[var(--on-ter-c)] flex items-center justify-center mb-6"><Check size={56} strokeWidth={3} /></div>
            <h3 className="m3-title-lg mb-2">Payment Successful!</h3>
            <p className="m3-body-md text-[var(--out)] mb-8">St. Agnes Parish is now on KwayaPro Pro.</p>
            <div className="bg-[var(--sur-c)] w-full rounded-[24px] p-6 text-left mb-8 space-y-4 shadow-sm border border-[var(--out-v)]">
              <div className="flex justify-between border-b border-[var(--out-v)] pb-3"><span className="m3-body-md text-[var(--out)]">Amount</span><span className="m3-title-md">UGX 40,000</span></div>
              <div className="flex justify-between border-b border-[var(--out-v)] pb-3"><span className="m3-body-md text-[var(--out)]">Transaction ID</span><span className="m3-body-md font-mono">TXN-882145</span></div>
              <div className="flex justify-between"><span className="m3-body-md text-[var(--out)]">Valid Until</span><span className="m3-title-md text-[var(--pri)]">27 May 2026</span></div>
            </div>
            <Button onClick={() => setTab('home')} className="w-full h-14">Return to Dashboard</Button>
          </div>
        )}
      </div>
    </div>
  );
};

const GuestDirectorScreen = ({ setTab }) => {
  const { showMsg } = React.useContext(AppContext);
  return (
    <div className="h-full flex flex-col bg-[var(--sur)]">
      <div className="px-4 py-4 flex items-center justify-between border-b border-[var(--out-v)]">
        <IconButton icon={ChevronLeft} onClick={() => setTab('rehearsals')} label="Back" />
        <h2 className="m3-title-lg">Guest Director</h2>
        <div className="w-12"></div>
      </div>
      <div className="flex-1 overflow-y-auto p-6 space-y-6">
        <div className="text-center mb-8">
          <div className="w-24 h-24 bg-[var(--sec-c)] text-[var(--on-sec-c)] rounded-full mx-auto flex items-center justify-center mb-4"><Link size={40} /></div>
          <h3 className="m3-headline-lg">Invite a Guest</h3>
          <p className="m3-body-md text-[var(--out)] mt-2">Generate a temporary access link for a guest director to lead this rehearsal.</p>
        </div>
        
        <div className="bg-[var(--sur-c)] rounded-[24px] p-5 border border-[var(--out-v)]">
          <h4 className="m3-label-sm text-[var(--out)] mb-4">GUEST PERMISSIONS</h4>
          <ul className="space-y-3">
            <li className="flex gap-3 m3-body-md"><Check size={18} className="text-[var(--ter)]" /> View all songs & audio parts</li>
            <li className="flex gap-3 m3-body-md"><Check size={18} className="text-[var(--ter)]" /> Mark attendance</li>
            <li className="flex gap-3 m3-body-md"><Check size={18} className="text-[var(--ter)]" /> Upload new audio recordings</li>
          </ul>
          <div className="mt-4 pt-4 border-t border-[var(--out-v)]">
            <p className="m3-label-sm text-[var(--err)] flex items-center gap-1"><AlertCircle size={14}/> Auto-expires when session ends.</p>
          </div>
        </div>
      </div>
      <div className="p-4 bg-[var(--sur)] border-t border-[var(--out-v)]">
        <Button variant="filled" className="w-full h-14" icon={Share2} onClick={() => showMsg("Link generated. Opening WhatsApp...")}>Generate Invite Link</Button>
      </div>
    </div>
  );
};

const AttendanceScreen = ({ setTab }) => {
  const { showMsg } = React.useContext(AppContext);
  const groupedMembers = {
    Soprano: [{ n: 'Sarah Kizza' }, { n: 'Mary K.' }, { n: 'Ruth A.' }],
    Alto: [{ n: 'Patricia N.' }, { n: 'Grace M.' }, { n: 'Florence' }],
    Tenor: [{ n: 'Simon P.' }, { n: 'David S.' }],
    Bass: [{ n: 'Vincent K.' }, { n: 'John L.' }, { n: 'Robert' }]
  };
  
  const [attended, setAttended] = useState(['Sarah Kizza', 'Patricia N.', 'Simon P.', 'Vincent K.']);
  const [overrideSheet, setOverrideSheet] = useState(null); 
  
  const toggle = (name) => setAttended(prev => prev.includes(name) ? prev.filter(n => n !== name) : [...prev, name]);

  return (
    <div className="h-full flex flex-col bg-[var(--sur)] relative">
      <div className="px-4 py-4 flex items-center justify-between border-b border-[var(--out-v)] shadow-sm z-10">
        <IconButton icon={ChevronLeft} onClick={() => setTab('rehearsals')} label="Back" />
        <div className="text-center"><h2 className="m3-title-md">Sunday Mass Prep</h2><p className="m3-label-sm text-[var(--out)]">27 APR • {attended.length}/11 PRESENT</p></div>
        <IconButton icon={CheckCircle2} variant="tonal" label="Save" onClick={() => setTab('rehearsals')} />
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-6 pb-8">
        <div className="bg-[var(--pri-c)] rounded-[16px] px-4 py-3 flex items-center justify-between shadow-sm">
          <span className="m3-body-md text-[var(--on-pri-c)]"><Info size={16} className="inline mr-2 -mt-0.5"/>Tap part badge to override</span>
        </div>

        {Object.entries(groupedMembers).map(([part, members]) => (
          <div key={part}>
            <h3 className="m3-label-sm text-[var(--out)] mb-2 ml-2 flex items-center justify-between">
              {part} <span className="bg-[var(--sur-hh)] px-2 py-0.5 rounded-md text-[var(--on-sur)]">{members.length}</span>
            </h3>
            <div className="bg-[var(--sur-c)] rounded-[24px] border border-[var(--out-v)] overflow-hidden">
              {members.map((m, i) => {
                const isPresent = attended.includes(m.n);
                return (
                  <div key={m.n} onClick={() => toggle(m.n)} className={`flex items-center justify-between p-3 m3-transition cursor-pointer m3-press ${isPresent ? 'bg-[var(--sec-c)]' : ''} ${i < members.length - 1 ? 'border-b border-[var(--out-v)]' : ''}`}>
                    <div className="flex items-center gap-4">
                      <div className={`w-6 h-6 rounded-md border-2 flex items-center justify-center m3-transition ${isPresent ? 'bg-[var(--sec)] border-[var(--sec)] text-[var(--on-sec)]' : 'border-[var(--out)]'}`}>{isPresent && <Check size={16} strokeWidth={3} />}</div>
                      <span className={`m3-title-md ${isPresent ? 'text-[var(--on-sec-c)]' : 'text-[var(--on-sur)]'}`}>{m.n}</span>
                    </div>
                    <button 
                      className="flex items-center gap-1 bg-[var(--sur-hh)] text-[var(--on-sur)] px-3 py-1.5 rounded-lg focus:outline-none focus:ring-2 focus:ring-[var(--pri)]" 
                      onClick={(e) => { e.stopPropagation(); setOverrideSheet({ show: true, member: m.n, currentPart: part }); }}
                      aria-label={`Override part for ${m.n}`}
                    >
                      <span className="m3-label-sm">{part.charAt(0)}</span>
                      <ChevronDown size={14} />
                    </button>
                  </div>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      {overrideSheet && overrideSheet.show && (
        <div className="absolute inset-0 bg-black/50 z-50 flex flex-col justify-end fade-in" onClick={() => setOverrideSheet(null)}>
          <div className="bg-[var(--sur-hi)] w-full rounded-t-[28px] p-6 slide-in-bottom shadow-2xl" onClick={e => e.stopPropagation()}>
             <div className="w-10 h-1 bg-[var(--out-v)] rounded-full mx-auto mb-6"></div>
             <h3 className="m3-title-lg mb-2">Override Voice Part</h3>
             <p className="m3-body-md text-[var(--out)] mb-4">Assign {overrideSheet.member} to a different section for this rehearsal.</p>

             <div className="bg-[var(--sur-hh)] px-4 py-3 rounded-xl mb-6 flex gap-3 items-start border border-[var(--out-v)] border-opacity-50">
               <Info size={18} className="text-[var(--out)] shrink-0 mt-0.5" />
               <div>
                 <p className="m3-label-sm text-[var(--on-sur)] mb-0.5">SESSION-SPECIFIC OVERRIDE</p>
                 <p className="text-[12px] font-semibold text-[var(--out)] leading-snug">This assignment applies to this rehearsal only. Her default part in the Library remains unchanged.</p>
               </div>
             </div>

             <div className="bg-[var(--sur-c)] border border-[var(--out-v)] rounded-[20px] overflow-hidden mb-6">
               {['Soprano', 'Alto', 'Tenor', 'Bass'].map((p, idx) => (
                 <button 
                   key={p} 
                   onClick={() => { showMsg(`${overrideSheet.member} assigned to ${p} for this session`); setOverrideSheet(null); }} 
                   className={`w-full text-left p-4 m3-title-md m3-transition m3-press focus:outline-none flex justify-between items-center ${idx < 3 ? 'border-b border-[var(--out-v)]' : ''} ${p === overrideSheet.currentPart ? 'bg-[var(--sec-c)] text-[var(--on-sec-c)]' : 'hover:bg-[var(--sur-hh)] text-[var(--on-sur)]'}`}
                 >
                   {p}
                   {p === overrideSheet.currentPart && <CheckCircle2 size={20} />}
                 </button>
               ))}
             </div>
          </div>
        </div>
      )}
    </div>
  );
};

const PlannerScreen = ({ setTab }) => {
  return (
    <div className="h-full flex flex-col bg-[var(--sur)]">
      <div className="px-4 py-4 flex items-center justify-between border-b border-[var(--out-v)] shadow-sm">
        <IconButton icon={ChevronLeft} onClick={() => setTab('home')} label="Back" />
        <h2 className="m3-title-lg">Program Planner</h2>
        <IconButton icon={MoreVertical} label="Options" />
      </div>
      <div className="flex-1 overflow-y-auto p-5 pb-8 space-y-6">
        <div className="bg-[var(--sur-c)] p-4 rounded-[24px] border border-[var(--out-v)]">
          <p className="m3-label-sm text-[var(--out)] mb-3">EVENT DETAILS</p>
          <div className="bg-[var(--sur)] rounded-[12px] p-2 border-b-2 border-[var(--pri)] mb-4">
            <input type="text" defaultValue="Sunday Mass - 27th Apr" className="bg-transparent border-none outline-none w-full px-2 py-1 m3-title-md text-[var(--on-sur)]" />
          </div>
          <div className="flex gap-2"><Chip label="Mass" selected={true} onClick={() => {}} /><Chip label="Wedding" selected={false} onClick={() => {}} /></div>
        </div>
        <div>
          <div className="flex justify-between items-end mb-3 ml-2"><h3 className="m3-label-sm text-[var(--out)]">SONG ORDER</h3><span className="m3-label-sm bg-[var(--pri-c)] text-[var(--on-pri-c)] px-2 py-1 rounded">3 Songs</span></div>
          <ul className="space-y-3 m-0 p-0 list-none">
            {[ 
              { id: 1, title: 'Nkwagala Omukama', type: 'Entrance', warning: null }, 
              { id: 2, title: 'Holy Holy Holy', type: 'Offertory', warning: 'Missing Tenor audio' },
              { id: 3, title: 'Tukutendereza Yesu', type: 'Communion', warning: null }
            ].map(song => (
              <li key={song.id} className={`flex items-center gap-3 p-3 bg-[var(--sur-hi)] rounded-[20px] border m3-press cursor-grab shadow-sm ${song.warning ? 'border-[var(--err)]' : 'border-[var(--out-v)]'}`}>
                <GripVertical size={20} className="text-[var(--out)] ml-1 cursor-grab" />
                <div className="w-8 h-8 rounded-full bg-[var(--sur-hh)] text-[var(--on-sur)] flex items-center justify-center m3-title-md">{song.id}</div>
                <div className="flex-1">
                  <h4 className="m3-title-md text-[var(--on-sur)]">{song.title}</h4>
                  <div className="flex items-center gap-2 mt-0.5">
                    <p className="m3-body-md text-[var(--out)]">{song.type}</p>
                    {song.warning && <span className="flex items-center gap-1 m3-label-sm text-[var(--err)] bg-[var(--err-c)] px-2 py-0.5 rounded"><AlertCircle size={12}/> {song.warning}</span>}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
      <div className="p-4 bg-[var(--sur)] border-t border-[var(--out-v)] flex gap-3"><Button variant="outlined" className="flex-1">Save Draft</Button><Button variant="filled" className="flex-1" icon={Share2}>Publish</Button></div>
    </div>
  );
};

const MembersScreen = ({ setTab }) => {
  return (
    <div className="h-full flex flex-col bg-[var(--sur)]">
      <div className="px-4 py-4 flex items-center justify-between border-b border-[var(--out-v)] shadow-sm">
        <IconButton icon={ChevronLeft} onClick={() => setTab('home')} label="Back" />
        <h2 className="m3-title-lg">Members & Roles</h2>
        <IconButton icon={Search} label="Search" />
      </div>
      <div className="flex-1 overflow-y-auto p-4 space-y-6">
        <div className="bg-[var(--ter-c)] text-[var(--on-ter-c)] rounded-[24px] p-5 shadow-sm">
          <ShieldAlert size={32} className="mb-2" /><h3 className="m3-title-md mb-1">Granular Permissions</h3><p className="m3-body-md opacity-80">Delegate specific admin tasks to choristers.</p>
        </div>
        <div>
          <h3 className="m3-label-sm text-[var(--out)] mb-3 ml-2">MANAGEMENT TEAM</h3>
          <div className="space-y-3">
            <div className="flex items-center gap-4 p-4 bg-[var(--sur-lo)] rounded-[24px] border border-[var(--out-v)] m3-press cursor-pointer">
              <div className="w-12 h-12 rounded-full bg-[var(--pri)] text-[var(--on-pri)] flex items-center justify-center m3-title-md">SP</div>
              <div className="flex-1"><h4 className="m3-title-md text-[var(--on-sur)]">Simon Peter (You)</h4><p className="m3-body-md text-[var(--pri)]">Choir Leader</p></div>
            </div>
          </div>
        </div>
        <div>
          <h3 className="m3-label-sm text-[var(--out)] mb-3 ml-2">CHORISTERS</h3>
          <div onClick={() => setTab('member_detail')} className="flex items-center gap-4 p-4 bg-[var(--sur-c)] rounded-[24px] border border-[var(--out-v)] m3-press cursor-pointer relative overflow-hidden shadow-sm">
            <div className="absolute left-0 top-0 w-2 h-full bg-[var(--ter)]"></div>
            <div className="w-12 h-12 rounded-[16px] bg-[var(--sur-hh)] text-[var(--on-sur)] flex items-center justify-center m3-title-md">PN</div>
            <div className="flex-1">
              <h4 className="m3-title-md text-[var(--on-sur)]">Patricia Nalwoga</h4><p className="m3-body-md text-[var(--out)]">Alto • 1 Permission</p>
              <div className="flex gap-2 mt-2 flex-wrap">
                <span className="m3-label-sm bg-[var(--ter-c)] text-[var(--on-ter-c)] px-2 py-1 rounded">Song Planner</span>
              </div>
            </div>
            <ChevronLeft size={20} className="rotate-180 text-[var(--out)]" />
          </div>
        </div>
      </div>
    </div>
  );
};

const MemberDetailScreen = ({ setTab }) => {
  const { showMsg, confirmAction } = React.useContext(AppContext);
  const [permissions, setPermissions] = useState({ planner: true, audio: false, scores: false });

  const toggle = (key) => {
    setPermissions(prev => ({ ...prev, [key]: !prev[key] }));
    showMsg("Permissions updated.");
  };

  return (
    <div className="h-full flex flex-col bg-[var(--sur)]">
      <div className="px-4 py-4 flex items-center justify-between border-b border-[var(--out-v)] shadow-sm">
        <IconButton icon={ChevronLeft} onClick={() => setTab('members')} label="Back" />
        <h2 className="m3-title-md">Manage Member</h2>
        <div className="w-12"></div>
      </div>
      <div className="flex-1 overflow-y-auto p-4 space-y-6">
        <div className="flex items-center gap-4 bg-[var(--sur-c)] p-5 rounded-[24px] border border-[var(--out-v)]">
          <div className="w-16 h-16 rounded-[20px] bg-[var(--sur-hh)] text-[var(--on-sur)] flex items-center justify-center m3-headline-lg">PN</div>
          <div>
            <h3 className="m3-title-lg">Patricia Nalwoga</h3>
            <p className="m3-body-md text-[var(--out)]">Role: Chorister</p>
          </div>
        </div>

        <div>
          <h3 className="m3-label-sm text-[var(--out)] mb-3 ml-2">GRANT PERMISSIONS</h3>
          <div className="bg-[var(--sur-lo)] rounded-[24px] border border-[var(--out-v)] overflow-hidden">
            
            <div className="p-4 border-b border-[var(--out-v)] flex items-center justify-between m3-press cursor-pointer" onClick={() => toggle('planner')}>
              <div>
                <h4 className="m3-title-md">Song Program Planner</h4>
                <p className="m3-body-md text-[var(--out)] mt-1">Create and publish Mass programs</p>
              </div>
              <button role="switch" aria-checked={permissions.planner} className={`w-14 h-8 rounded-full p-1 m3-transition flex items-center ${permissions.planner ? 'bg-[var(--ter)]' : 'bg-[var(--out-v)]'}`}>
                <div className={`w-6 h-6 rounded-full m3-transition ${permissions.planner ? 'bg-[var(--on-ter)] translate-x-6' : 'bg-[var(--sur)] translate-x-0'}`}></div>
              </button>
            </div>

            <div className="p-4 border-b border-[var(--out-v)] flex items-center justify-between m3-press cursor-pointer" onClick={() => toggle('audio')}>
              <div>
                <h4 className="m3-title-md">Audio Uploader</h4>
                <p className="m3-body-md text-[var(--out)] mt-1">Upload voice part recordings</p>
              </div>
              <button role="switch" aria-checked={permissions.audio} className={`w-14 h-8 rounded-full p-1 m3-transition flex items-center ${permissions.audio ? 'bg-[var(--ter)]' : 'bg-[var(--out-v)]'}`}>
                <div className={`w-6 h-6 rounded-full m3-transition ${permissions.audio ? 'bg-[var(--on-ter)] translate-x-6' : 'bg-[var(--sur)] translate-x-0'}`}></div>
              </button>
            </div>

            <div className="p-4 flex items-center justify-between m3-press cursor-pointer" onClick={() => toggle('scores')}>
              <div>
                <h4 className="m3-title-md">Score Librarian</h4>
                <p className="m3-body-md text-[var(--out)] mt-1">Upload sheet music PDFs</p>
              </div>
              <button role="switch" aria-checked={permissions.scores} className={`w-14 h-8 rounded-full p-1 m3-transition flex items-center ${permissions.scores ? 'bg-[var(--ter)]' : 'bg-[var(--out-v)]'}`}>
                <div className={`w-6 h-6 rounded-full m3-transition ${permissions.scores ? 'bg-[var(--on-ter)] translate-x-6' : 'bg-[var(--sur)] translate-x-0'}`}></div>
              </button>
            </div>

          </div>
        </div>

        <div className="pt-4">
          <button onClick={() => confirmAction("Remove Member", "Are you sure you want to remove Patricia? Her attendance history will be preserved.", () => setTab('members'), true)} className="w-full flex items-center justify-center gap-2 p-4 bg-[#FFDAD6] text-[#BA1A1A] rounded-[24px] m3-title-md m3-press focus:outline-none focus:ring-2 focus:ring-[#BA1A1A]">
            <UserMinus size={20}/> Remove from Choir
          </button>
        </div>
      </div>
    </div>
  );
};

// --- LANDSCAPE STUDIO (Flutter Layout Mirror) ---
const StudioLandscapeScreen = ({ setTab }) => {
  const [isRecording, setIsRecording] = useState(false);
  const [part, setPart] = useState('Alto');
  const [isSustain, setIsSustain] = useState(false);
  const { showMsg } = React.useContext(AppContext);

  // Math Setup for Flutter Scroll Controller Translation
  const pianoRef = useRef(null);
  const whiteKeys = ['C3','D3','E3','F3','G3','A3','B3','C4','D4','E4','F4','G4','A4','B4','C5','D5','E5','F5','G5','A5','B5'];
  const numKeys = whiteKeys.length;
  
  // Aligning black keys to sit at the border of the appropriate white keys
  const blackKeys = [
    {i:0, n:'C#3'}, {i:1, n:'D#3'}, {i:3, n:'F#3'}, {i:4, n:'G#3'}, {i:5, n:'A#3'},
    {i:7, n:'C#4'}, {i:8, n:'D#4'}, {i:10, n:'F#4'}, {i:11, n:'G#4'}, {i:12, n:'A#4'},
    {i:14, n:'C#5'}, {i:15, n:'D#5'}, {i:17, n:'F#5'}, {i:18, n:'G#5'}, {i:19, n:'A#5'}
  ];

  // Translates to: scrollController.animateTo(offset) in Flutter
  const scrollOctave = (direction) => {
    if (pianoRef.current) {
      // 1 Octave = 7 white keys. Fixed key width = 56px. 7 * 56 = 392px.
      const scrollAmount = direction === 'left' ? -392 : 392;
      pianoRef.current.scrollBy({ left: scrollAmount, behavior: 'smooth' });
    }
  };

  return (
    <div className="w-full h-full flex flex-col bg-[var(--sur)] rounded-[32px] overflow-hidden fade-in relative shadow-inner">
      
      {/* TOP PANE: Controls & Context (The "Console") */}
      <div className="flex-1 flex flex-row px-6 pt-4 pb-3 w-full bg-[var(--sur)] z-10 relative">
        
        {/* LEFT: Context */}
        <div className="w-[260px] flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <IconButton icon={ChevronLeft} onClick={() => setTab('home')} label="Exit Studio" className="w-10 h-10 bg-[var(--sur-hh)] text-[var(--on-sur)]" />
            <h2 className="m3-title-md">Studio</h2>
            <IconButton icon={Settings} label="Settings" className="w-10 h-10 bg-[var(--sur-hh)] text-[var(--on-sur)]" />
          </div>
          <div className="bg-[var(--sur-lo)] rounded-[20px] p-3 text-center shadow-sm border border-[var(--out-v)] border-opacity-40">
            <h3 className="m3-title-md mb-0.5">Ave Maria</h3>
            <p className="m3-body-md text-[var(--out)] mb-2">Chorus • Key: Bb</p>
            <div className="flex bg-[var(--sur-hh)] rounded-full p-1 shadow-inner" role="group" aria-label="Select Voice Part">
              {['Soprano', 'Alto', 'Tenor', 'Bass'].map(p => (
                <button 
                  key={p} 
                  onClick={() => setPart(p)} 
                  aria-pressed={part === p} 
                  className={`flex-1 py-1 min-h-[32px] m3-label-sm rounded-full m3-transition focus:outline-none ${part === p ? 'bg-[var(--pri)] text-[var(--on-pri)] shadow-md' : 'text-[var(--out)] hover:bg-[var(--sur-c)]'}`}
                >
                  {p.charAt(0)}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* CENTER: Pitch / Visualizer */}
        <div className="flex-1 flex flex-col items-center justify-end relative h-full">
          {isRecording ? (
            <div className="flex flex-col items-center justify-end h-full mb-3 fade-in">
              <div className="flex items-center gap-2 mb-4 bg-[var(--err-c)] px-4 py-1.5 rounded-full shadow-sm">
                <div className="w-2.5 h-2.5 rounded-full bg-[var(--err)] animate-pulse"></div>
                <span className="m3-label-sm text-[var(--err)]">RECORDING</span>
                <span className="m3-label-sm text-[var(--err)] font-mono ml-2">00:12</span>
              </div>
              <div className="flex items-center gap-1.5 h-12 mb-2">
                {[3, 6, 8, 4, 9, 5, 7, 3, 8, 5, 7, 4].map((h, i) => (
                  <div key={i} className="w-2.5 rounded-full bg-[var(--err)] wave-bar" style={{ height: `${h * 5}px`, animationDelay: `${i * 0.1}s` }} />
                ))}
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center justify-end h-full mb-3 fade-in w-full relative">
              <p className="m3-label-sm text-[var(--out)] mb-2 z-20">READY TO RECORD</p>
              <div className="absolute bottom-0 w-[220px] h-[100px] overflow-hidden opacity-80 pointer-events-none">
                <svg viewBox="0 0 200 100" className="w-full h-full overflow-visible" aria-hidden="true">
                  <path d="M 10 100 A 90 90 0 0 1 190 100" fill="none" stroke="var(--sur-hh)" strokeWidth="16" strokeLinecap="round" />
                  <path d="M 60 40 A 90 90 0 0 1 140 40" fill="none" stroke="var(--ter-c)" strokeWidth="16" strokeLinecap="round" />
                  <g className="needle-idle"><line x1="100" y1="100" x2="100" y2="18" stroke="var(--out)" strokeWidth="6" strokeLinecap="round" /><circle cx="100" cy="100" r="10" fill="var(--out)" /></g>
                </svg>
              </div>
            </div>
          )}
          
          <div className="relative z-20">
            <button 
              onClick={() => { setIsRecording(!isRecording); if(isRecording) showMsg("Saved to Cloudflare R2."); }} 
              className={`flex items-center justify-center shadow-xl m3-transition focus:outline-none focus:ring-4 focus:ring-[var(--err)] ${isRecording ? 'w-[72px] h-[72px] bg-[var(--err)] text-[var(--on-err)] rounded-full hover:scale-95' : 'w-[220px] h-[64px] bg-[var(--pri)] text-[var(--on-pri)] rounded-[24px] hover:rounded-[28px] m3-press'}`}
            >
              {isRecording ? <Square size={28} fill="currentColor" /> : <span className="m3-title-md tracking-widest flex items-center gap-2"><Mic2 size={22}/> RECORD ALTO</span>}
            </button>
          </div>
        </div>

        {/* RIGHT: Controls */}
        <div className="w-[260px] flex flex-col justify-between items-end">
          <div className="flex items-center justify-between w-full mb-2 gap-3">
            <Button variant="outlined" className="h-[48px] px-4 border-2 m3-label-sm rounded-[16px] pointer-events-none flex-1">
              METRONOME: 72 BPM
            </Button>
            <IconButton icon={Settings} label="Studio Settings" className="w-[48px] h-[48px] bg-[var(--sur-hh)] text-[var(--on-sur)] shrink-0" />
          </div>
          
          <div className="flex gap-3 w-full mt-auto">
            <button 
              onClick={() => setIsSustain(!isSustain)}
              className={`flex-1 rounded-[24px] m3-label-sm m3-transition m3-press shadow-sm focus:outline-none border-2 h-[64px] ${isSustain ? 'bg-[var(--ter)] text-[var(--on-ter)] border-[var(--ter)]' : 'bg-[var(--sur-hi)] text-[var(--on-sur)] border-[var(--out-v)] hover:bg-[var(--sur-hh)]'}`}
            >
              SUSTAIN
            </button>
          </div>
        </div>

      </div>

      {/* BOTTOM PANE: Full-Width Scrollable Piano */}
      <div className="w-full h-[150px] relative flex bg-[var(--sur-lo)] shadow-inner border-t-4 border-[var(--out-v)] overflow-hidden shrink-0">
        
        {/* Left Octave Arrow Overlay */}
        <div className="absolute left-0 top-0 bottom-0 w-20 bg-gradient-to-r from-[rgba(0,0,0,0.5)] to-transparent z-20 flex items-center justify-start pl-2 pointer-events-none">
          <button onClick={() => scrollOctave('left')} className="w-12 h-12 rounded-full bg-[var(--sur)]/90 backdrop-blur shadow-lg flex items-center justify-center pointer-events-auto m3-press focus:outline-none focus:ring-2 focus:ring-[var(--pri)]">
            <ChevronLeft size={28} className="text-[var(--on-sur)]" />
          </button>
        </div>
        
        {/* FLUTTER TRANSLATION: SingleChildScrollView (Horizontal) -> Row / Stack */}
        <div ref={pianoRef} className="w-full h-full overflow-x-auto no-scrollbar scroll-smooth flex">
          {/* Inner container establishing explicit width (21 keys * 56px = 1176px) */}
          <div className="relative h-full flex shrink-0" style={{ minWidth: `${numKeys * 56}px` }}>
            {/* White Keys */}
            {whiteKeys.map((note) => (
              <button key={note} aria-label={`Play ${note}`} className="w-[56px] h-full bg-[#FCFBF9] border-r border-[#E5E0D8] last:border-none m3-press relative flex items-end justify-center pb-3 focus:outline-none focus:bg-[var(--pri-c)] shadow-sm shrink-0">
                <span className="m3-label-sm text-[var(--out)] opacity-70 mb-1">{note}</span>
              </button>
            ))}
            {/* Black Keys */}
            <div className="absolute top-0 left-0 w-full h-full pointer-events-none">
              {blackKeys.map((k) => (
                <button key={k.n} aria-label={`Play ${k.n}`} 
                  // Math: (index * 56px) - 16px (half of 32px width) perfectly straddles the white key borders
                  style={{ left: `calc(${((k.i + 1) / numKeys) * 100}% - 16px)`, width: '32px' }}
                  className="absolute top-0 h-[62%] bg-[#2A251D] rounded-b-[10px] pointer-events-auto m3-press focus:bg-[var(--pri)] shadow-xl border border-black/90 z-10">
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Right Octave Arrow Overlay */}
        <div className="absolute right-0 top-0 bottom-0 w-20 bg-gradient-to-l from-[rgba(0,0,0,0.5)] to-transparent z-20 flex items-center justify-end pr-2 pointer-events-none">
          <button onClick={() => scrollOctave('right')} className="w-12 h-12 rounded-full bg-[var(--sur)]/90 backdrop-blur shadow-lg flex items-center justify-center pointer-events-auto m3-press focus:outline-none focus:ring-2 focus:ring-[var(--pri)]">
            <ChevronLeft size={28} className="rotate-180 text-[var(--on-sur)]" />
          </button>
        </div>
      </div>
    </div>
  );
};