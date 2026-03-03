/*
 * LangOver - Hebrew ↔ English keyboard layout text converter
 *
 * Converts selected text that was typed in the wrong keyboard layout.
 * Trigger: Middle mouse button click while text is selected.
 *
 * If no text is selected, the middle click passes through normally
 * (auto-scroll, paste, close tab, etc. all keep working).
 *
 * Pure Win32 C — no dependencies, no runtime needed.
 *
 * License: MIT
 */

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <shellapi.h>
#include "resource.h"

/* ─── Constants ─── */
#define APP_NAME        L"LangOver"
#define WM_TRAYICON     (WM_USER + 1)
#define ID_TRAY_EXIT    3001
#define ID_TRAY_ABOUT   3002
#define ID_TRAY_STARTUP 3003

#define STARTUP_REG_KEY  L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run"
#define STARTUP_REG_NAME L"LangOver"

/* ─── Hebrew↔English mapping (physical keyboard positions) ─── */
static const wchar_t MAP_EN[] = L"`qwertyuiop[]asdfghjkl;'zxcvbnm,./";
static const wchar_t MAP_HE[] = L"\x003B/\x0027\x05E7\x05E8\x05D0\x05D8\x05D5\x05DF\x05DD\x05E4][" /* ;/'קראטוןםפ][ */
                                 L"\x05E9\x05D3\x05D2\x05DB\x05E2\x05D9\x05D7\x05DC\x05DA\x05E3," /* שדגכעיחלךף, */
                                 L"\x05D6\x05E1\x05D1\x05D4\x05E0\x05DE\x05E6\x05EA\x05E5.";      /* זסבהנמצתץ.  */

static const int MAP_LEN = (sizeof(MAP_EN) / sizeof(wchar_t)) - 1; /* exclude NUL */

/* ─── Globals ─── */
static HHOOK    g_mouseHook;
static HWND     g_hwndHidden;
static HICON    g_hIcon;
static NOTIFYICONDATAW g_nid;

/* ─── Build lookup tables for O(1) conversion ─── */
/* We use two sparse arrays indexed by character code. */
/* Hebrew range 0x0590-0x05FF → small table of 112 entries. */
/* ASCII printable 0x20-0x7E → 95 entries. */

#define ASCII_BASE  0x20
#define ASCII_COUNT 95
#define HEB_BASE    0x0590
#define HEB_COUNT   112

static wchar_t g_en2he[ASCII_COUNT]; /* ASCII char → Hebrew char (0 = no mapping) */
static wchar_t g_he2en[HEB_COUNT];  /* Hebrew char → ASCII char (0 = no mapping) */

static void InitMappingTables(void)
{
    ZeroMemory(g_en2he, sizeof(g_en2he));
    ZeroMemory(g_he2en, sizeof(g_he2en));

    for (int i = 0; i < MAP_LEN; i++) {
        wchar_t e = MAP_EN[i];
        wchar_t h = MAP_HE[i];

        /* English → Hebrew (lowercase) */
        if (e >= ASCII_BASE && e < ASCII_BASE + ASCII_COUNT)
            g_en2he[e - ASCII_BASE] = h;

        /* English → Hebrew (uppercase maps to same Hebrew char) */
        if (e >= L'a' && e <= L'z') {
            wchar_t upper = e - 32;
            if (upper >= ASCII_BASE && upper < ASCII_BASE + ASCII_COUNT)
                g_en2he[upper - ASCII_BASE] = h;
        }

        /* Hebrew → English */
        if (h >= HEB_BASE && h < HEB_BASE + HEB_COUNT)
            g_he2en[h - HEB_BASE] = e;
    }
}

static BOOL IsHebrew(wchar_t ch)
{
    return (ch >= 0x0590 && ch <= 0x05FF);
}

static BOOL TextContainsHebrew(const wchar_t *text, int len)
{
    for (int i = 0; i < len; i++) {
        if (IsHebrew(text[i]))
            return TRUE;
    }
    return FALSE;
}

/* ─── Convert text in-place ─── */
static void ConvertText(wchar_t *text, int len)
{
    BOOL toEnglish = TextContainsHebrew(text, len);

    for (int i = 0; i < len; i++) {
        wchar_t ch = text[i];
        wchar_t mapped = 0;

        if (toEnglish) {
            if (ch >= HEB_BASE && ch < HEB_BASE + HEB_COUNT)
                mapped = g_he2en[ch - HEB_BASE];
        } else {
            if (ch >= ASCII_BASE && ch < ASCII_BASE + ASCII_COUNT)
                mapped = g_en2he[ch - ASCII_BASE];
        }

        if (mapped != 0)
            text[i] = mapped;
    }
}

/* ─── Try to get selected text from the foreground window via clipboard ─── */
/* Returns allocated buffer (caller frees) or NULL if nothing selected.      */
static wchar_t *GetSelectedText(int *outLen)
{
    /* Save current clipboard */
    if (!OpenClipboard(NULL))
        return NULL;

    HANDLE hOld = GetClipboardData(CF_UNICODETEXT);
    wchar_t *oldText = NULL;
    int oldLen = 0;

    if (hOld) {
        wchar_t *p = (wchar_t *)GlobalLock(hOld);
        if (p) {
            oldLen = (int)wcslen(p);
            oldText = (wchar_t *)HeapAlloc(GetProcessHeap(), 0, (oldLen + 1) * sizeof(wchar_t));
            if (oldText)
                memcpy(oldText, p, (oldLen + 1) * sizeof(wchar_t));
            GlobalUnlock(hOld);
        }
    }
    CloseClipboard();

    /* Clear clipboard and send Ctrl+C */
    if (!OpenClipboard(NULL)) {
        if (oldText) HeapFree(GetProcessHeap(), 0, oldText);
        return NULL;
    }
    EmptyClipboard();
    CloseClipboard();

    /* Simulate Ctrl+C */
    INPUT inputs[4];
    ZeroMemory(inputs, sizeof(inputs));

    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;

    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 'C';

    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = 'C';
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

    SendInput(4, inputs, sizeof(INPUT));
    Sleep(100);

    /* Read new clipboard content */
    wchar_t *result = NULL;
    *outLen = 0;

    if (OpenClipboard(NULL)) {
        HANDLE hNew = GetClipboardData(CF_UNICODETEXT);
        if (hNew) {
            wchar_t *p = (wchar_t *)GlobalLock(hNew);
            if (p && wcslen(p) > 0) {
                int newLen = (int)wcslen(p);
                result = (wchar_t *)HeapAlloc(GetProcessHeap(), 0, (newLen + 1) * sizeof(wchar_t));
                if (result) {
                    memcpy(result, p, (newLen + 1) * sizeof(wchar_t));
                    *outLen = newLen;
                }
            }
            if (p) GlobalUnlock(hNew);
        }
        CloseClipboard();
    }

    /* Restore old clipboard */
    if (OpenClipboard(NULL)) {
        EmptyClipboard();
        if (oldText && oldLen > 0) {
            HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, (oldLen + 1) * sizeof(wchar_t));
            if (hMem) {
                wchar_t *dest = (wchar_t *)GlobalLock(hMem);
                if (dest) {
                    memcpy(dest, oldText, (oldLen + 1) * sizeof(wchar_t));
                    GlobalUnlock(hMem);
                    SetClipboardData(CF_UNICODETEXT, hMem);
                }
            }
        }
        CloseClipboard();
    }

    if (oldText) HeapFree(GetProcessHeap(), 0, oldText);
    return result;
}

/* ─── Paste text by putting it on clipboard and sending Ctrl+V ─── */
static void PasteText(const wchar_t *text, int len)
{
    /* Save clipboard first */
    wchar_t *savedClip = NULL;
    int savedLen = 0;

    if (OpenClipboard(NULL)) {
        HANDLE hOld = GetClipboardData(CF_UNICODETEXT);
        if (hOld) {
            wchar_t *p = (wchar_t *)GlobalLock(hOld);
            if (p) {
                savedLen = (int)wcslen(p);
                savedClip = (wchar_t *)HeapAlloc(GetProcessHeap(), 0, (savedLen + 1) * sizeof(wchar_t));
                if (savedClip) memcpy(savedClip, p, (savedLen + 1) * sizeof(wchar_t));
                GlobalUnlock(hOld);
            }
        }
        CloseClipboard();
    }

    /* Set converted text */
    if (OpenClipboard(NULL)) {
        EmptyClipboard();
        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, (len + 1) * sizeof(wchar_t));
        if (hMem) {
            wchar_t *dest = (wchar_t *)GlobalLock(hMem);
            if (dest) {
                memcpy(dest, text, (len + 1) * sizeof(wchar_t));
                GlobalUnlock(hMem);
                SetClipboardData(CF_UNICODETEXT, hMem);
            }
        }
        CloseClipboard();
    }

    /* Ctrl+V */
    INPUT inputs[4];
    ZeroMemory(inputs, sizeof(inputs));

    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;

    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 'V';

    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = 'V';
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

    SendInput(4, inputs, sizeof(INPUT));
    Sleep(150);

    /* Restore clipboard */
    if (OpenClipboard(NULL)) {
        EmptyClipboard();
        if (savedClip && savedLen > 0) {
            HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, (savedLen + 1) * sizeof(wchar_t));
            if (hMem) {
                wchar_t *dest = (wchar_t *)GlobalLock(hMem);
                if (dest) {
                    memcpy(dest, savedClip, (savedLen + 1) * sizeof(wchar_t));
                    GlobalUnlock(hMem);
                    SetClipboardData(CF_UNICODETEXT, hMem);
                }
            }
        }
        CloseClipboard();
    }

    if (savedClip) HeapFree(GetProcessHeap(), 0, savedClip);
}

/* ─── Perform the conversion (called async from WM message) ─── */
#define WM_DO_CONVERT (WM_USER + 100)

/* Mouse hook state — declared here so DoConvert can reference g_mbDownPos */
static BOOL   g_mbDown = FALSE;
static POINT  g_mbDownPos;
static DWORD  g_mbDownTime;

/* Forward declaration — defined below with the mouse hook code */
static void ReplayMiddleClick(POINT pt);

static void DoConvert(void)
{
    int len = 0;
    wchar_t *text = GetSelectedText(&len);
    if (!text || len == 0) {
        if (text) HeapFree(GetProcessHeap(), 0, text);
        /* No selection → replay the original middle-click so normal actions work
           (close tab, auto-scroll, paste in terminal, etc.) */
        ReplayMiddleClick(g_mbDownPos);
        return;
    }

    ConvertText(text, len);
    PasteText(text, len);
    HeapFree(GetProcessHeap(), 0, text);
}

/* ─── Low-level mouse hook ─── */
/*
 * Strategy to avoid interfering with normal middle-click:
 *   1. On MBUTTONDOWN: record the click position and time, suppress the event.
 *   2. On MBUTTONUP:
 *      a. If the mouse moved significantly (>5px) → it was a drag/scroll, replay both events.
 *      b. If time > 400ms → long press (auto-scroll), replay.
 *      c. Otherwise → quick click. Try to get selected text:
 *         - If selection exists → convert it (eat the click).
 *         - If no selection → replay the middle click so the app gets it normally.
 */

static void ReplayMiddleClick(POINT pt)
{
    INPUT inputs[2];
    ZeroMemory(inputs, sizeof(inputs));

    /* Convert screen coords to absolute (0-65535) */
    int cx = GetSystemMetrics(SM_CXSCREEN);
    int cy = GetSystemMetrics(SM_CYSCREEN);

    inputs[0].type = INPUT_MOUSE;
    inputs[0].mi.dx = (pt.x * 65535) / cx;
    inputs[0].mi.dy = (pt.y * 65535) / cy;
    inputs[0].mi.dwFlags = MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE | MOUSEEVENTF_MIDDLEDOWN;

    inputs[1].type = INPUT_MOUSE;
    inputs[1].mi.dx = inputs[0].mi.dx;
    inputs[1].mi.dy = inputs[0].mi.dy;
    inputs[1].mi.dwFlags = MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE | MOUSEEVENTF_MIDDLEUP;

    SendInput(2, inputs, sizeof(INPUT));
}

static LRESULT CALLBACK MouseHookProc(int nCode, WPARAM wParam, LPARAM lParam)
{
    if (nCode < 0)
        return CallNextHookEx(g_mouseHook, nCode, wParam, lParam);

    MSLLHOOKSTRUCT *ms = (MSLLHOOKSTRUCT *)lParam;

    /* Ignore injected events (our own replays) */
    if (ms->flags & LLMHF_INJECTED)
        return CallNextHookEx(g_mouseHook, nCode, wParam, lParam);

    if (wParam == WM_MBUTTONDOWN) {
        g_mbDown = TRUE;
        g_mbDownPos = ms->pt;
        g_mbDownTime = ms->time;
        return 1; /* suppress */
    }

    if (wParam == WM_MBUTTONUP && g_mbDown) {
        g_mbDown = FALSE;

        DWORD elapsed = ms->time - g_mbDownTime;
        int dx = ms->pt.x - g_mbDownPos.x;
        int dy = ms->pt.y - g_mbDownPos.y;
        int dist = dx * dx + dy * dy;

        /* If dragged or held too long → replay as normal middle click */
        if (dist > 25 || elapsed > 400) {
            ReplayMiddleClick(g_mbDownPos);
            return 1;
        }

        /* Quick click with no movement → try to convert selection */
        /* Post message to our window to handle it outside the hook */
        PostMessage(g_hwndHidden, WM_DO_CONVERT, 0, 0);
        return 1; /* suppress */
    }

    return CallNextHookEx(g_mouseHook, nCode, wParam, lParam);
}

/* ─── Startup with Windows (registry-based) ─── */
static BOOL IsStartupEnabled(void)
{
    HKEY hKey;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, STARTUP_REG_KEY, 0, KEY_READ, &hKey) != ERROR_SUCCESS)
        return FALSE;
    DWORD type = 0, size = 0;
    BOOL exists = (RegQueryValueExW(hKey, STARTUP_REG_NAME, NULL, &type, NULL, &size) == ERROR_SUCCESS);
    RegCloseKey(hKey);
    return exists;
}

static void SetStartupEnabled(BOOL enable)
{
    HKEY hKey;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, STARTUP_REG_KEY, 0, KEY_WRITE, &hKey) != ERROR_SUCCESS)
        return;
    if (enable) {
        wchar_t exePath[MAX_PATH];
        GetModuleFileNameW(NULL, exePath, MAX_PATH);
        /* Wrap in quotes for paths with spaces */
        wchar_t value[MAX_PATH + 4];
        wsprintfW(value, L"\"%s\"", exePath);
        RegSetValueExW(hKey, STARTUP_REG_NAME, 0, REG_SZ,
                       (const BYTE *)value, (DWORD)((wcslen(value) + 1) * sizeof(wchar_t)));
    } else {
        RegDeleteValueW(hKey, STARTUP_REG_NAME);
    }
    RegCloseKey(hKey);
}

/* ─── Tray icon ─── */
static void CreateTrayIcon(HWND hwnd)
{
    ZeroMemory(&g_nid, sizeof(g_nid));
    g_nid.cbSize = sizeof(NOTIFYICONDATAW);
    g_nid.hWnd = hwnd;
    g_nid.uID = 1;
    g_nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    g_nid.uCallbackMessage = WM_TRAYICON;
    g_nid.hIcon = g_hIcon;
    wcscpy_s(g_nid.szTip, _countof(g_nid.szTip),
             L"LangOver - \x05DC\x05D7\x05E5 \x05D2\x05DC\x05D2\x05DC\x05EA \x05DC\x05D4\x05DE\x05E8\x05D4");
    Shell_NotifyIconW(NIM_ADD, &g_nid);
}

static void RemoveTrayIcon(void)
{
    Shell_NotifyIconW(NIM_DELETE, &g_nid);
}

/* ─── Hidden window procedure ─── */
static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg) {
    case WM_DO_CONVERT:
        DoConvert();
        return 0;

    case WM_TRAYICON:
        if (lParam == WM_RBUTTONUP) {
            POINT pt;
            GetCursorPos(&pt);
            HMENU hMenu = CreatePopupMenu();
            AppendMenuW(hMenu, MF_STRING, ID_TRAY_ABOUT,
                        L"\x05D0\x05D5\x05D3\x05D5\x05EA LangOver");   /* אודות */
            AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);
            AppendMenuW(hMenu, MF_STRING | (IsStartupEnabled() ? MF_CHECKED : 0),
                        ID_TRAY_STARTUP,
                        L"\x05D4\x05E4\x05E2\x05DC\x05D4 \x05E2\x05DD \x05E2\x05DC\x05D9\x05D9\x05EA Windows");  /* הפעלה עם עליית */
            AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);
            AppendMenuW(hMenu, MF_STRING, ID_TRAY_EXIT,
                        L"\x05D9\x05E6\x05D9\x05D0\x05D4");            /* יציאה */
            SetForegroundWindow(hwnd);
            TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN,
                           pt.x, pt.y, 0, hwnd, NULL);
            DestroyMenu(hMenu);
        }
        return 0;

    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case ID_TRAY_EXIT:
            PostQuitMessage(0);
            return 0;
        case ID_TRAY_ABOUT:
            MessageBoxW(hwnd,
                L"LangOver - \x05DE\x05DE\x05D9\x05E8 \x05E2\x05D1\x05E8\x05D9\x05EA \x2194 \x05D0\x05E0\x05D2\x05DC\x05D9\x05EA\n\n"  /* ממיר עברית ↔ אנגלית */
                L"\x05D1\x05D7\x05E8 \x05D8\x05E7\x05E1\x05D8 \x05D5\x05DC\x05D7\x05E5 \x05E2\x05DC \x05D2\x05DC\x05D2\x05DC\x05EA \x05D4\x05E2\x05DB\x05D1\x05E8 \x05DC\x05D4\x05DE\x05E8\x05D4.\n\n"  /* בחר טקסט ולחץ על גלגלת העכבר להמרה. */
                L"\x05D0\x05DD \x05DC\x05D0 \x05E0\x05D1\x05D7\x05E8 \x05D8\x05E7\x05E1\x05D8, \x05DC\x05D7\x05D9\x05E6\x05D4 \x05E2\x05DC \x05D4\x05D2\x05DC\x05D2\x05DC\x05EA \x05E4\x05D5\x05E2\x05DC\x05EA \x05DB\x05E8\x05D2\x05D9\x05DC.\n\n" /* אם לא נבחר טקסט, לחיצה על הגלגלת פועלת כרגיל. */
                L"\x05D3\x05D5\x05D2\x05DE\x05D4: asdf \x2192 \x05E9\x05D3\x05D2\x05DB\n"  /* דוגמה: */
                L"\x05E9\x05D3\x05D2\x05DB \x2192 asdf\n\n"
                L"https://github.com/nachlib/LangOver",
                L"\x05D0\x05D5\x05D3\x05D5\x05EA LangOver",  /* אודות LangOver */
                MB_OK | MB_ICONINFORMATION | MB_RTLREADING | MB_RIGHT);
            return 0;
        case ID_TRAY_STARTUP:
            SetStartupEnabled(!IsStartupEnabled());
            return 0;
        }
        break;

    case WM_DESTROY:
        RemoveTrayIcon();
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

/* ─── Entry point ─── */
int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                    LPWSTR lpCmdLine, int nCmdShow)
{
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    /* Single instance check */
    HANDLE hMutex = CreateMutexW(NULL, TRUE, L"LangOver_SingleInstance_Mutex");
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        MessageBoxW(NULL,
                    L"LangOver \x05DB\x05D1\x05E8 \x05E4\x05D5\x05E2\x05DC.\n"  /* LangOver כבר פועל. */
                    L"\x05D1\x05D3\x05D5\x05E7 \x05D1\x05D0\x05D6\x05D5\x05E8 \x05D4\x05D4\x05EA\x05E8\x05D0\x05D5\x05EA.",  /* בדוק באזור ההתראות. */
                    APP_NAME, MB_OK | MB_ICONINFORMATION | MB_RTLREADING | MB_RIGHT);
        return 0;
    }

    InitMappingTables();

    /* Load icon */
    g_hIcon = LoadIconW(hInstance, MAKEINTRESOURCEW(IDI_LANGOVER));
    if (!g_hIcon)
        g_hIcon = LoadIconW(NULL, IDI_APPLICATION);

    /* Register window class */
    WNDCLASSEXW wc;
    ZeroMemory(&wc, sizeof(wc));
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = L"LangOverClass";
    wc.hIcon = g_hIcon;
    RegisterClassExW(&wc);

    /* Create hidden window */
    g_hwndHidden = CreateWindowExW(0, L"LangOverClass", APP_NAME,
                                   0, 0, 0, 0, 0,
                                   HWND_MESSAGE, NULL, hInstance, NULL);
    if (!g_hwndHidden)
        return 1;

    CreateTrayIcon(g_hwndHidden);

    /* Install low-level mouse hook */
    g_mouseHook = SetWindowsHookExW(WH_MOUSE_LL, MouseHookProc, hInstance, 0);
    if (!g_mouseHook) {
        MessageBoxW(NULL, L"Failed to install mouse hook.", APP_NAME, MB_ICONERROR);
        RemoveTrayIcon();
        return 1;
    }

    /* Message loop */
    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    UnhookWindowsHookEx(g_mouseHook);
    RemoveTrayIcon();
    if (hMutex) ReleaseMutex(hMutex);

    return (int)msg.wParam;
}
