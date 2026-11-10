import ctypes, sys
from ctypes import wintypes

version = ctypes.WinDLL("version")
path = sys.argv[1]

size = version.GetFileVersionInfoSizeW(path, None)
if not size:
    raise OSError(ctypes.get_last_error(), "no version info")
buf = ctypes.create_string_buffer(size)
if not version.GetFileVersionInfoW(path, 0, size, buf):
    raise ctypes.WinError()

class VS_FIXEDFILEINFO(ctypes.Structure):
    _fields_ = [(n, wintypes.DWORD) for n in (
        "dwSignature", "dwStrucVersion", "dwFileVersionMS", "dwFileVersionLS",
        "dwProductVersionMS", "dwProductVersionLS", "dwFileFlagsMask", "dwFileFlags",
        "dwFileOS", "dwFileType", "dwFileSubtype", "dwFileDateMS", "dwFileDateLS")]

ptr = ctypes.c_void_p()
length = wintypes.UINT()
if not version.VerQueryValueW(buf, "\\", ctypes.byref(ptr), ctypes.byref(length)):
    raise ctypes.WinError()
info = ctypes.cast(ptr, ctypes.POINTER(VS_FIXEDFILEINFO)).contents

def ver(ms, ls):
    return f"{ms >> 16}.{ms & 0xFFFF}.{ls >> 16}.{ls & 0xFFFF}"

print("file:", ver(info.dwFileVersionMS, info.dwFileVersionLS))
print("product:", ver(info.dwProductVersionMS, info.dwProductVersionLS))
