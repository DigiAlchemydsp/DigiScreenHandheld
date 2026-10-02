# DigiScreen — mirror your Elektron screen on a handheld

> **DigiScreen** is a PortMaster port of
> [screendump](https://github.com/DigiAlchemydsp/screendumpTUI) for Knulli /
> Batocera aarch64 handhelds (Anbernic RG40XX-V / H700). It mirrors an Elektron
> **Digitone / Digitakt / Syntakt** screen onto the handheld's display, over
> MIDI, using the instrument's own screenshot command. **Nothing on the machine
> is modified.**
>
> The screen-mirroring tool itself is **screendump by Jakob Bak** (MIT). This
> repository adds the PortMaster packaging, the vaixterm terminal + gptokeyb
> **control layer**, and the **pairing loop** that cycles the machines and
> streams the first one that answers.

Connect an Elektron **Digitone / Digitakt / Syntakt** by USB-MIDI
(`GLOBAL → USB CFG → USB MIDI` on the machine), launch DigiScreen, and the
handheld mirrors the machine's screen at its own refresh rate (~30 fps).

## DigiScreen-Stream — mirror + remote view

**DigiScreen-Stream** combines DigiScreen with the **FatmaVision** screen
stream: it starts the device's screen stream first (fb0 → H.264 over
`tcp:5555`, one client), then launches DigiScreen, and stops the stream when
DigiScreen exits. Someone on the **FatmaVision app** can then watch the
Elektron screen mirror live from anywhere on the network.

```
DigiScreen-Stream.sh     launches the stream, then DigiScreen
```

Install the **DigiScreen** port first — DigiScreen-Stream orchestrates it and
reuses its files. `stream.sh` is bundled from
[FatmaVision](https://github.com/DigiAlchemydsp/FatmaVision) and needs `ffmpeg`
(shipped with Knulli).

## Requirements

| Dependency | Source | Notes |
|---|---|---|
| `python3` | ships with Knulli | runs the screendump tool |
| `python-rtmidi` | **bundled** in the port (`DigiScreen/py/`) | vendored at build time |
| `vaixterm` terminal emulator | ships with Knulli (`/usr/bin/vaixterm`) | also called VAxTerm |
| PortMaster control layer (`control.txt`, `gptokeyb`) | ships with Knulli at `/userdata/system/.local/share/PortMaster/` | gamepad → keys |
| Elektron machine + USB-MIDI | — | nothing else |

## Install

Final layout on the device:

```
/userdata/roms/ports/
├── DigiScreen.sh          (executable launcher, shown in the Ports menu)
└── DigiScreen/
    ├── port.json
    ├── gameinfo.xml
    ├── DigiScreen.gptk    (gamepad → TUI keys)
    ├── pair.sh            (the pairing loop, run inside vaixterm)
    ├── screendump         (the tool, single file)
    ├── py/                (vendored python-rtmidi, aarch64)
    └── userdata/          (created at first run)
```

```bash
# from any machine with scp/ssh (Linux, macOS, WSL, Git Bash):
bash scripts/install-ssh.sh root@<knulli-ip>
# then restart EmulationStation (or reboot) and launch DigiScreen from the Ports menu.
```

Or by SD card: unzip `release/DigiScreen.zip` into `userdata/roms/ports/`
(`chmod +x DigiScreen.sh DigiScreen/pair.sh` if the port won't launch).

## How it works

The launcher (`DigiScreen.sh`) is a standard PortMaster shim: sources
`control.txt`, disables USB autosuspend (Knulli's 2 s idle timeout would
otherwise drop the USB-MIDI connection), and starts **vaixterm** with the
pairing loop. It also bundles `python-rtmidi` so nothing has to be installed
on the device.

`pair.sh` is the small loop that runs inside the terminal:

1. Probe each instrument in turn — `dn`, `dt`, `sy` — with a one-second
   single-shot capture (`screendump -x --timeout 1 --instrument <x>`).
2. The **first machine that answers** wins; launch the live stream
   (`screendump -x --framerate 30 --instrument <x> --blocks`).
3. When the stream ends (press `q`/B), loop back and pair again — so you can
   swap machines or unplug/replug without relaunching the port.
4. If nothing answers, it keeps retrying until a machine appears.

Because the Digitakt and Digitone answer the screenshot RPC on the **same id**,
either name finds either machine — the order just picks a label. The Syntakt
entry joins the cycle automatically once it is implemented in screendump.

### Display

The stream renders in **blocks mode** by default: half-block cells are solid,
and they are the glyphs DejaVu Sans Mono actually ships (it has no braille).
The font size is computed from the framebuffer width as a *fractional* point
size — vaixterm accepts fractions — so the 128-column screen fills the display
edge to edge on a 640×480 panel. Swap the font and the advance ratio changes;
set `SCREENDUP_FONT_PT` to override the computed size.

The live view redraws only when the picture actually changes and refreshes its
status line at ~2 Hz, so a static screen does not shimmer on vaixterm's
`--force-full-render`.

## Controls (gamepad → TUI keys)

| Gamepad | Key | DigiScreen action |
|---|---|---|
| A | `s` | save the current frame as a `.syx` |
| B | `q` | quit the stream (back to the pairing loop) |
| X | `m` | render mode: braille → blocks → ascii |
| Y | `i` | invert lit and unlit |
| L1 | `h` | show the key help |
| R1 | `f` | flip vertically |
| L2 / R2 | `p` / `space` | pause / resume the stream |
| Start | `space` | pause / resume |
| Guide | `h` | show the key help |

- **Fully exit the port** with the EmulationStation hotkey.
- Want different bindings? Edit `DigiScreen/DigiScreen.gptk` on the device
  (flat format — the device's gptokeyb v1 rejects a `[controls]` section).

## Building from source

`release/DigiScreen.zip` is built with `scripts/build-port.sh` — run it **on
the device** (aarch64 Linux, where `pip` resolves the right `python-rtmidi`
wheel for the device's Python), or on any host with Python 3:

```bash
# on the device:
ssh root@<knulli-ip>
cd /tmp
bash scripts/build-port.sh        # produces release/DigiScreen.zip
```

What it does:

1. Vendors `python-rtmidi` for aarch64 into `py/` (native `pip --target` on
   the device; a `manylinux_2_28_aarch64` wheel download on a host — set
   `RTPYTHON_VERSION` to the device's `cpXY` if the host Python differs).
2. Copies `screendump` + the `portmaster/` metadata into the port dir.
3. Assembles and zips `DigiScreen.sh` + `DigiScreen/` into `release/DigiScreen.zip`.

Known build quirks:

- `/userdata` is exFAT — no symlinks; the build never creates any.
- `vaixterm -e` execs a **single path**, no shell → `pair.sh` is that path.
- gptokeyb v1 rejects a `[controls]` header → flat `.gptk` format.
- The `python-rtmidi` wheel dlopens its **bundled `libjack`** from
  `py/python_rtmidi/` — the launcher adds that dir to `LD_LIBRARY_PATH`.

## Repository layout

```
digiscreen-handhelds/
├── README.md               (this file)
├── LICENSE                 (MIT — screendump tool + port packaging)
├── screendump              the screendump tool (single file, from upstream)
├── portmaster/             small versioned source files used by build-port.sh
│   ├── DigiScreen.sh       PortMaster launcher (PORTMASTER header)
│   ├── pair.sh             the pairing loop (vaixterm -e target)
│   ├── DigiScreen.gptk     gamepad → keys
│   ├── port.json           PortMaster metadata
│   └── gameinfo.xml        EmulationStation metadata
├── scripts/
│   ├── build-port.sh       full build → release/DigiScreen.zip
│   ├── install-ssh.sh      SSH install helper
│   └── uninstall-ssh.sh    SSH remove helper
└── release/                built DigiScreen.zip (gitignored)
```

> `python-rtmidi` is several MB — it is **not tracked in git**. Publish the
> built zip as a GitHub Release; `scripts/build-port.sh` reproduces it.

## Acknowledgements

- **screendump** — the screen-mirroring tool — by **Jakob Bak** (MIT). This
  port forks it and packages it for handhelds; the tool is a single
  dependency-free Python file that talks the instrument's stock screenshot RPC.
- The PortMaster control layer, gptokeyb, and the launcher conventions follow
  the Knulli port-launcher spec and the PortMaster project's own tooling.
- The vaixterm terminal emulator ships with Knulli.

## Troubleshooting

- **Port doesn't appear in the menu**: EmulationStation rescans at startup —
  restart ES (or reboot). Check the layout matches the tree above.
- **Blank screen on launch**: check `DigiScreen/log.txt` on the device;
  over SSH run `python3 -c "import rtmidi"` from `DigiScreen/` to confirm the
  bundled wheel loads.
- **Keeps saying "no machine found"**: confirm the Elektron box is in
  `GLOBAL → USB CFG → USB MIDI` (not Overbridge), and that it enumerates:
  `python3 screendump --list-midi`.
- **Gamepad does nothing**: confirm gptokeyb started (`[GPTK]` in `log.txt`);
  Knulli's hotkey should still exit the port.