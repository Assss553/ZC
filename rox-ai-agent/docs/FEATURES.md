# Feature status / حالة الميزات

Legend: ✅ implemented & automatically tested · 🟡 implemented, needs first run on real Windows 11 · ⛔ not implemented

| Area | Feature | Status | Notes |
|---|---|---|---|
| Shell | Electron window, resize, fullscreen (F11), RTL/LTR | ✅ UI verified in Chromium; 🟡 Electron run on Windows | |
| Shell | Windows installer (NSIS, per-user, no admin) | 🟡 | `scripts/build-installer.ps1` (PyInstaller + electron-builder) not yet run on Windows |
| Claude | API key in Windows Credential Manager, mask, test, model list, model/effort select | ✅ (tested with file keyring) | Real key test requires your key |
| Claude | Usage counters (tokens/requests) | ✅ | From official `usage` fields; dollar cost not shown |
| Claude | Claude account via official Claude Code CLI login | 🟡 | Used for the Coding agent only; computer/game control needs the API |
| Claude | Local AI provider | ⛔ | Placeholder in Settings |
| Vision | Live screen stream (WebSocket JPEG, zoom, pause) | ✅ verified on a virtual display | |
| Vision | Window list / game window capture / focus | 🟡 | pygetwindow, Windows only |
| Vision | Game FPS | ⛔ | No reliable non-invasive API; stream fps shown instead |
| Input | Mouse/keyboard (pyautogui), Arabic text via clipboard, failsafe corner | 🟡 | Needs a desktop session |
| Computer agent | Plan → act → verify loop with `computer_toolset_20260801`, run_command, open_app, ask_user, mid-task edits | ✅ loop logic tested with mocked Claude; 🟡 live | |
| Game agent | Adapter system, window region, key allow-lists, freeze/closed-window/repeated-error detection, help requests | ✅ logic; 🟡 live | Adapters: generic, 2048, Solitaire, Minesweeper |
| Coding agent | Real files in allowed folders, backups, diffs, review-before-apply, undo, run tests, editor w/ highlighting | ✅ tested | |
| Chat | Conversations, history, images, screenshot attach, plan proposal → approve & run | ✅ UI; 🟡 live replies need key | |
| Scheduler | Start/end times, duration, periodic reports, timeline, crash recovery, auto-resume | ✅ tested | |
| Power | Keep awake during tasks, run at login (HKCU\Run) | 🟡 | Windows API calls |
| Security | Emergency stop (button, global hotkey, API), approvals, blocked categories, folder sandbox, audit log, localhost+token | ✅ tested | Global hotkey 🟡 |
| Security | Not admin by default | ✅ | Installer `asInvoker`; warning banner if elevated |
| Studio | Split workspace (resizable panels): workspace tree, live view + floating toolbar, target settings, timelines | ✅ verified in browser |  |
| Studio | Capture asset by dragging a box on the live view; OpenCV template matching with confidence, method, area of interest | ✅ tested on virtual display | Flat/featureless regions are rejected |
| Studio | Timeline engine: Target / Wait Target / Click / Key / Type / Delay, run/stop, playhead, saved presets | ✅ logic + matching tested; 🟡 clicks on Windows | |
| App Doctor | Real checks: Python syntax, JSON, Lua (luac or block heuristic), FiveM fxmanifest refs, HTML local links, TypeScript, npm lint/test, pytest | ✅ tested | Nothing installed automatically |
| App Doctor | AI repair loop with live view: file + highlighted diff, narration, plan, terminal, health ring, issues struck through as fixed | ✅ UI + loop verified with scripted Claude; 🟡 with real key | |
| App Doctor | Windows app crashes (Event Log 1000/1001/1002, read-only) + "Diagnose" with Claude | 🟡 Windows only | |
| Design | Icon set (lucide) across the app, ROX logo, Windows .ico for exe/installer/taskbar | ✅ | |
| Operator (instant) | Executes immediately from chat or the command bar; direct system tools first (system info, processes, disks, network, installed/startup apps, services, crashes, windows, find/read files, launch apps, URLs, clipboard, PowerShell), computer use for GUI | ✅ loop + tools tested (real data); 🟡 Windows-specific tools and live Claude | Risky steps still ask approval; system processes protected |
| Operator (instant) | Live card in chat: plan, narration, every tool call with its result, live screen thumbnail, pause/stop, add instructions mid-run | ✅ verified | |
| Operator (instant) | Command bar: Ctrl+K in app, Ctrl+Shift+Space global | ✅ in-app; 🟡 global hotkey on Windows | |
| Notifications | Push/email reports when away | ⛔ | Reports are in the app timeline only |
