; NOTE: ~\Documents\AutoHotkey\key-remaps.ahk
: INFO:
; https://stackoverflow.com/questions/78384471/how-to-map-capslock-to-esc-and-ctrl-in-autohotkey
;    - *Wildcard: Fires the hotkey even if extra modifiers (in this case Ctrl)
;    are being held down.
;
;    - DownR has an effect similar to physically pressing the key.
;
;    - The Blind mode
;      avoids releasing the modifier keys (Alt, Ctrl, Shift, and Win) if they
;      started out in the down position...
;      Modifier keys are restored differently to allow a Send to turn off a
;      hotkey's modifiers even if the user is still physically holding them down.


#Requires AutoHotkey v2.0

#SingleInstance Force

; Tap = Esc, Hold = Ctrl+Shift
*CapsLock::Send "{Blind}{Ctrl down}{Shift down}"
*CapsLock Up::
{
    Send "{Blind}{Ctrl up}{Shift up}"
    If (A_PriorKey = "CapsLock")
        Send "{Esc}"
}

