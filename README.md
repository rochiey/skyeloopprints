# SkyeLoop

SkyeLoop is an offline-first Flutter photobooth kiosk for Android tablets. It
supports venue branding, three payment QR tiers, multi-shot layouts, a simple
photo editor, 80 mm ESC/POS Bluetooth printing, and direct local-network photo
download without a cloud backend.

## Venue network

The customer flow and printing work with no Wi-Fi. Digital-copy transfer needs
the tablet and customer phone on the same LAN, but that LAN does not need
internet access. For unattended use, a small dedicated router is more reliable
than an Android hotspot. The Digital Copy screen reports when no reachable LAN
address is available.

## Photo frames

The editor's **Border** button wraps the finished photo(s) in a single printed
frame. Frames are vector art in solid black on white, and they are grouped by
layout, so the picker only ever offers what suits the session:

- **One photo:** wanted poster, music player, polaroid, airplane ticket,
  postage stamp, magazine cover, arcade screen, passport stamp.
- **Three-photo strip:** film strip, film rails, photo booth strip, comic strip,
  polaroid stack, receipt roll, stamp sheet.
- **Four-photo grid:** comic panels, contact sheet, photo booth sheet, polaroid
  collage, CCTV wall, yearbook page, ticket quartet, stamp block.

The frames are rendered into the exported composition, so they appear in both
the print and the digital copy. The print pipeline reduces the composition to a
1-bit halftone at 576 dots wide (see `MainActivity.kt`), so every frame uses
strokes of at least 3 px and text of at least 16 px in pure black: thinner or
grey artwork is lifted by the print tone curve and dithers away into a broken
dotted line. "No frame" draws nothing at all, leaving the original output
untouched.

## Hardware notes

- Emulator mode can use mock photos and a simulated printer.
- Real Classic Bluetooth SPP printing must be verified with the final printer.
- True lock-task kiosk mode requires provisioning the tablet as device owner;
  otherwise Android shows the standard screen-pinning confirmation.
- Put the supplied logo at `assets/default_branding/skyeloop_logo.png` before
  release. Until then, the app renders its built-in SkyeLoop mark.

