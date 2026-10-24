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

## Pricing on the customer screen

The customer flow never shows a price. The layout cards say what a session
includes ("1 photo", "3 photos", "4 photos") and the payment screen is titled
**Complete your payment**; the amount lives only in the PayMongo payment intent
and in Admin reporting, where the tiers still carry 20/30/50 PHP. Billing is
unchanged: `amountCentavos` is still sent for the selected tier.

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

## Pre-printed cafe name

The Vozy G80 cannot print the last 40 mm of a job: that paper is still between
its printhead and its cutter when the strip is fed to the cut, so it stays
inside the printer and comes back out as the **top of the next strip**. It used
to be fed blank, which is the empty gap that appeared above every print.

Every print now ends by printing the cafe name into that band (see
`PreprintBandRenderer.headerBand`), so the next strip arrives with its header
already on it. The composition no longer draws the venue name at all: a strip is
now `pre-printed header + photo/footer`, then the cut.

That makes each print depend on the one before it, so the first print of a run
starts with a **maintenance print** (`PreprintBandRenderer.maintenanceSlip`).
It ejects the paper that was already sitting in the gap and loads the cafe name
for the strip that follows. The same maintenance print can be run on demand from
**Admin → Pre-printed cafe name** after loading a fresh roll.

The band prints the cafe name and nothing else, centred in the strip's head.
`PreprintBandRenderer.mastheadTop` divides the band **plus the composition's own
18-dot top padding** into equal margins above and below the name;
`headerMarginRatio` biases that split (1.0 = exactly equal, 1.15 = a hair more
air above, the default), so a typical venue name lands about 19 mm below the cut
edge and about 16 mm above the first photo.

A long cafe name is **never cut off**: nothing printed on the band can be
corrected afterwards, so a name too wide for the paper is first shrunk to fit,
and if it would have to be printed below `minimumSingleLineFontSize` (32 of the
64-dot base size) it is word-wrapped over up to `headerMaxLines` (3) lines
instead, sharing one font size, with the margins re-balanced around the block.
It is never split mid-word and never ellipsized. Real measurements with Poppins:
"The Weekend Gathering" stays on one line at 35 dots, "Weekend Gathering" at
43, and a 56-character name becomes three lines at 37. Only a single
unbreakable word (no spaces at all) can be shrunk below 24, and it is still
printed whole.

`PreprintBandRenderer.gapDots` (320 rows = 40 mm at 8 dots/mm) is the
printhead-to-cutter distance, and therefore the height and position of the
band. If a strip ever shows a blank sliver above the header, or the top of the
name is clipped, measure the gap on real paper in millimetres and set the
constant to `mm x 8`. The native side clamps whatever the app sends to
64..1024 dot rows.

## Hardware notes

- Emulator mode can use mock photos and a simulated printer.
- Real Classic Bluetooth SPP printing must be verified with the final printer.
- True lock-task kiosk mode requires provisioning the tablet as device owner;
  otherwise Android shows the standard screen-pinning confirmation.
- Put the supplied logo at `assets/default_branding/skyeloop_logo.png` before
  release. Until then, the app renders its built-in SkyeLoop mark.

