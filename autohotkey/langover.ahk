#Requires AutoHotkey v2.0
#SingleInstance Force

; ═══════════════════════════════════════════════════════
;  LangOver - המרת הקלדה שגויה בין עברית לאנגלית
;
;  קיצור מקשים: ScrollLock
;  שימוש: סמן טקסט → לחץ ScrollLock → הטקסט יומר
;
;  דוגמה: "asdf" → "שדגכ"   |   "שדגכ" → "asdf"
; ═══════════════════════════════════════════════════════

A_IconTip := "LangOver - ScrollLock להמרת שפה"

; ── תפריט מגש המערכת ──
tray := A_TrayMenu
tray.Delete()
tray.Add("אודות", ShowAbout)
tray.Add()
tray.Add("יציאה", (*) => ExitApp())

ShowAbout(*) {
    msg := "LangOver - המרת הקלדה שגויה`n`n"
        . "סמן טקסט ולחץ ScrollLock`n"
        . "עברית ↔ אנגלית`n`n"
        . "דוגמה: asdf → שדגכ"
    MsgBox(msg, "LangOver", "Iconi")
}

; ═══ מיפוי תווים ═══
; כל תו באותו מיקום מייצג את אותו מקש פיזי במקלדת
enChars := "``qwertyuiop[]asdfghjkl;'zxcvbnm,./"
heChars := ";/'קראטוןםפ][שדגכעיחלךף,זסבהנמצתץ."

; בניית טבלאות מיפוי
En2He := Map()
En2He.CaseSense := "On"
He2En := Map()
He2En.CaseSense := "On"

Loop StrLen(enChars) {
    e := SubStr(enChars, A_Index, 1)
    h := SubStr(heChars, A_Index, 1)
    En2He[e] := h
    He2En[h] := e
    ; אותיות גדולות → אותו תו עברי
    if (Ord(e) >= 97 and Ord(e) <= 122)
        En2He[StrUpper(e)] := h
}

; ── בדיקה אם הטקסט מכיל תווים עבריים ──
ContainsHebrew(text) {
    Loop Parse, text {
        code := Ord(A_LoopField)
        if (code >= 0x0590 and code <= 0x05FF)
            return true
    }
    return false
}

; ── המרת כל תו בטקסט ──
ConvertText(text) {
    m := ContainsHebrew(text) ? He2En : En2He
    result := ""
    Loop Parse, text {
        ch := A_LoopField
        result .= m.Has(ch) ? m[ch] : ch
    }
    return result
}

; ═══════════════════════════════════════
;  קיצור מקשים: ScrollLock
; ═══════════════════════════════════════
ScrollLock:: {
    ; שמירת לוח גזירה
    clipSaved := ClipboardAll()
    A_Clipboard := ""

    ; העתקת הטקסט המסומן
    Send("^c")
    try {
        ClipWait(1)
    } catch {
        A_Clipboard := clipSaved
        ToolTip("סמן טקסט ולחץ ScrollLock")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; המרה והדבקה
    A_Clipboard := ConvertText(A_Clipboard)
    Send("^v")
    Sleep(150)

    ; שחזור לוח גזירה
    A_Clipboard := clipSaved
}

; הודעה בהפעלה
ToolTip("✓ LangOver פועל - ScrollLock להמרה")
SetTimer(() => ToolTip(), -3000)
