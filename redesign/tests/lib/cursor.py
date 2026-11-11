#!/usr/bin/env python3
"""Prints the X cursor now shown (XFixes): its name when it has one (libXcursor names them; Qt's xcb-cursor
does not), then size, hot spot and a hash of its pixels, so two cursors can be told apart:
    ? 24x24 hot 8,4 3f2a91c0"""
import ctypes
import ctypes.util
import zlib
import sys


class Image(ctypes.Structure):
    _fields_ = [('x', ctypes.c_short), ('y', ctypes.c_short), ('width', ctypes.c_ushort),
                ('height', ctypes.c_ushort), ('xhot', ctypes.c_ushort), ('yhot', ctypes.c_ushort),
                ('cursor_serial', ctypes.c_ulong), ('pixels', ctypes.c_void_p),
                ('atom', ctypes.c_ulong), ('name', ctypes.c_char_p)]


x11 = ctypes.CDLL(ctypes.util.find_library('X11'))
xf = ctypes.CDLL(ctypes.util.find_library('Xfixes'))
x11.XOpenDisplay.restype = ctypes.c_void_p
xf.XFixesGetCursorImage.restype = ctypes.POINTER(Image)
xf.XFixesGetCursorImage.argtypes = [ctypes.c_void_p]
d = x11.XOpenDisplay(None)
if not d:
    sys.exit('no display')
img = xf.XFixesGetCursorImage(d)
if not img:
    sys.exit('?')
c = img.contents
px = ctypes.cast(c.pixels, ctypes.POINTER(ctypes.c_ulong))
data = b''.join((px[i] & 0xffffffff).to_bytes(4, 'little') for i in range(c.width * c.height))
print(f"{(c.name or b'?').decode()} {c.width}x{c.height} hot {c.xhot},{c.yhot} {zlib.crc32(data):08x}")
