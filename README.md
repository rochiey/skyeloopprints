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

## Hardware notes

- Emulator mode can use mock photos and a simulated printer.
- Real Classic Bluetooth SPP printing must be verified with the final printer.
- True lock-task kiosk mode requires provisioning the tablet as device owner;
  otherwise Android shows the standard screen-pinning confirmation.
- Put the supplied logo at `assets/default_branding/skyeloop_logo.png` before
  release. Until then, the app renders its built-in SkyeLoop mark.

