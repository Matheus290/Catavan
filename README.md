# Catavan

**An open source video editor based on [Kdenlive](https://kdenlive.org), with an editing workflow inspired by VEGAS Pro.**

> **Version 0.1.0**, the first release. As with any new editor, keep backups of your projects.

## Why

I edited in VEGAS Pro for years and got tired of it. It's closed, paid and runs only on Windows. Open source editors
are great, but none of them felt like VEGAS when editing: the playhead jumps when you click, there's no real auto
ripple, overlapping two clips doesn't make a crossfade, and so on.

Catavan is my attempt at an open source editor that comes as close as possible to the VEGAS editing experience.
It doesn't start from scratch. It's **Kdenlive 26.08.2 and MLT 7.42.0** with changes to how the timeline and the
monitors behave.

## What to expect

- **Same interface as Kdenlive.** Panels, menus, effects, compositions, titles and rendering all work as in Kdenlive.
  What changes is mostly *behaviour*: clicks, drags, trims, shortcuts and playback. The only visible difference is the
  default arrangement of the panels: two areas on top instead of three, media on the left and the monitors on the
  right, as in VEGAS. All the panels are still there.
- **Changes can be switched off.** Almost every feature is an option in *Settings → Configure Catavan… → Timeline*,
  under **Catavan:**, and they are **on by default**. Turning one off brings back the original Kdenlive behaviour.
  The playback that keeps going after a click on the ruler uses Kdenlive's own *Pause playback when seeking* option,
  which Catavan turns off by default. The panel layout is just the default one, so you can switch layouts as usual.
- **Projects are Kdenlive projects.** Catavan saves regular `.kdenlive` files, which open in the official Kdenlive.
  One exception: clips set to WSOLA play with Rubberband there.
- **Separate from an installed Kdenlive.** Catavan has its own settings (`~/.config/catavanrc`), data folder
  (`~/.local/share/catavan`), translations, executables (`catavan`, `catavan_render`) and application ID, so the
  two can be used side by side without touching each other's settings.

## Features

### Playhead and clicking

- **Separate action cursor during playback.** As in VEGAS, clicking the timeline while playing doesn't stop or move
  the playback. It places an *action cursor*, and split, markers, paste and the other position-based actions use it.
  When playback stops, the playhead stays where it stopped.
- **Clicking a clip moves the playhead there.** Dragging still moves the clip without touching the playhead.
- **Clicking the ruler doesn't pause playback.** Playback continues from the clicked point.
- **The view lets go of the playhead when you look elsewhere.** During playback, the timeline follows the playhead
  until you scroll it or place the action cursor. It follows again after playback stops and restarts.
- **Right-clicking the ruler doesn't move the playhead.** The menu opens and playback goes on. Adding a marker
  (G) no longer makes the playhead jump to it a moment later.

### Editing

- **Auto Ripple.** The Spacer tool button becomes an **Auto Ripple** toggle (shortcut **Ctrl+L**) with a
  *Clips Only / Clips and Markers* menu. You stay in the Selection tool, and while it is on:
  - moving a clip moves everything after it, on all tracks;
  - deleting a clip closes the gap on all tracks;
  - trimming a clip edge ripples what comes after it;
  - in the *Clips and Markers* mode, markers move too, and regions (markers with a duration) follow what they mark:
    a region around the edit grows or shrinks with it.
- **Dropping a clip pushes the following clips.** Drop a clip from the bin between two clips and the next ones move
  forward by the full length of the new clip. With Auto Ripple, this applies to all tracks and markers.
- **Automatic crossfade when clips overlap.** Drag a clip over the start or end of another clip on the same track
  and the overlap becomes a crossfade: dissolve on video, mix on audio. A live preview with the fade curves is shown
  while dragging. Works with Auto Ripple, and undo/redo works in one step. Dragging the edge of a clip over the next
  (or previous) clip does the same: the clip grows over it as a crossfade, and so do the grouped clips that follow that
  edge (with its audio, for instance). As in VEGAS, the crossfade is just the overlap: trimming either edge back
  shortens it, and moving the edge off the other clip removes it.
- **Split with S, at the action cursor.** S splits the selected clips, or the active tracks when nothing is
  selected. X selects the Selection tool, and the Razor tool keeps its button without a shortcut.
- **Grouped clips while trimming.** Trimming one clip of a group pushes the edges of the other members when it
  reaches them, and each clip stops at the end of its own media.
- **Ungroup takes out only the clicked clip.** Click a clip of a group and choose Ungroup: that clip (with its audio
  or video) leaves the group and the others stay grouped. Ctrl+click picks more clips; a group left with one clip
  is removed, and the clip that left stays selected. **U** ungroups and **G** groups, as in VEGAS.
- **Selecting as in VEGAS.** Ctrl+click adds a clip to the selection or removes it. Shift+click selects every clip
  between the last clicked clip and the clicked one: on both tracks and the tracks in between, from the start of the
  first clip to the end of the last. Ctrl+Shift+click adds that range to the selection. Ctrl+drag still scrolls the
  timeline and Shift+drag still draws a selection rectangle.
- **Zone by dragging, as in VEGAS.** Press in an empty part of the timeline (not on a clip) and drag: the zone goes
  from where the drag started to where it ends, ready for a marker from the zone or anything else that uses it. A click
  without dragging still moves the playhead, and the drag snaps like the other edits (Shift turns snapping off).
- **Hover and clicked clip.** The clip under the mouse turns slightly lighter (video, audio, compositions and
  subtitles). In a selected group, the clip you clicked keeps the bright selection border and the others get a darker
  one, so you can tell which one it is.
- **No Mix Clips.** Since overlapping clips makes the crossfades, the Mix Clips action is hidden and a double click
  on a clip edge no longer creates a mix. Dropping a transition from the list on a cut still does.
- **Edge frame preview while trimming.** While you drag a clip edge, the project monitor shows the frame at that
  edge instead of the playhead frame. The audio keeps playing.

### Markers

- **M adds a marker** at the action cursor or playhead, as in VEGAS (G in Kdenlive).
- **Right-clicking the ruler** offers **Add Marker**. It only adds a marker, and never removes one the way the
  Add/Remove toggle does.
- **Right-clicking a marker** offers **Edit Marker** and **Remove Marker** for that marker, and no Add entry.

### Playback and audio

- **Adjustable playback speed in the monitors.** A speed slider in the status bar goes from 0x to 4x in 0.01 steps.
  J/L change the speed in 0.25x steps, reverse goes down to −4x, and K goes back to 1x. A **Pitch** box keeps the
  voice pitch at other speeds.
- **WSOLA time stretching.** This is a port of Chromium's WSOLA algorithm (the one Chrome uses for 1.5x/2x
  playback), added as a new MLT filter. In the **Clip Speed** dialog, the pitch compensation is chosen per clip:
  *None / Rubberband / WSOLA*. It also keeps the pitch on the monitor speed slider.

### Mouse

- **The mouse wheel zooms the timeline** and Ctrl+wheel scrolls it, the other way round from Kdenlive.
- **Zoom centers on the action cursor**, or on the playhead when there is no action cursor, not on the mouse.

### Layout

- **Two areas on top by default.** On the left are the project bin, effects, compositions and the library. On the
  right are the project monitor and the clip monitor, as tabs of the same area.

## System requirements

- **RAM: 8 GB minimum, 16 GB recommended.** Rendering is tuned for speed: it processes several frames at once and
  keeps whole frames in memory. A 5-minute project with 3840x1080 recordings, rendered to 1080p, peaked at 2.6 GB
  with one thread and 3.5 GB with four, on top of the ~2 GB used by the editor itself. Higher resolution sources
  need more.
- **GPU (optional):** an NVIDIA card makes rendering much faster, with hardware decoding (needs about 1.5 GB of free
  video memory) and the NVENC encoders.
- **Low on memory?** Lower the thread count in *Parallel Processing* in the render window (two threads give most of
  the speed), or turn hardware decoding off (*Settings → Run Config Wizard…*).

### Faster rendering

With an NVIDIA card, Catavan turns on hardware decoding by itself the first time it finds the card (the configuration
wizard checks the hardware on the first start). It can be turned off, and stays off, in *Settings → Run Config
Wizard…* → **Enable hardware decoding**. Two more settings in the render window give the fastest render (the
5-minute project above rendered in 4 min 43 s):

1. The **Hardware Accelerated (experimental) → NVENC H264 VBR** preset.
2. **Parallel Processing**, with 4 threads. Catavan turns it on by default.

Without an NVIDIA card, parallel processing still helps, and *Enable hardware decoding* in the configuration wizard
can be tried with other cards (VA-API, D3D11).

## Building

There are no packages yet (AppImage/Flatpak are planned). Catavan is built from source on Linux or on Windows
(see below).

```bash
./setup.sh      # installs the build dependencies (asks for your sudo password)
./build.sh      # builds MLT and Catavan into ~/.cache/catavan-build and starts Catavan
```

- `./build.sh run` starts the already built Catavan.
- `./build.sh --help` lists the other options.
- MLT is built with its optional modules: Glaxnimate (animation clips), OpenCV (motion tracker) and RNNoise (noise
  reduction). `EXTRA_MODULES=0 ./build.sh` leaves them out for faster builds. On Debian/Ubuntu, where RNNoise has no
  package, `build.sh` builds it from source.
- After a build, `source ~/.cache/catavan-build/env.sh` puts `catavan` and `melt` in your `PATH`.

The build has been tried on **Ubuntu 26.04** and **Windows 11**. `setup.sh` also has Fedora, openSUSE and Arch paths, not tried yet. Kdenlive 26.08 needs Qt ≥ 6.10, KDE Frameworks ≥ 6.21 and KDDockWidgets ≥ 2.4.

### Windows

Install [MSYS2](https://www.msys2.org/) (`winget install MSYS2.MSYS2`), open the **MSYS2 UCRT64** shell and run the
same `./setup.sh` and `./build.sh` from the repository folder. The build goes to
`C:\msys64\home\<user>\.cache\catavan-build`; after a build, `catavan.cmd` in that folder starts Catavan without the
MSYS2 shell.

### Repository layout

```
setup.sh        build dependencies and sources
build.sh        builds MLT, the WSOLA command line tool and Catavan
versions.env    Kdenlive and MLT versions the fork is based on
patches/        catavan.patch: every change against the original Kdenlive and MLT sources (setup.sh applies it);
                one diff per feature for reading (<feature>.diff, with its file list in <feature>.files)
src/            Kdenlive and MLT sources with the Catavan changes (not in the repository: setup.sh downloads the
                original tarballs and applies patches/catavan.patch)
upstream/       untouched Kdenlive and MLT sources, used to produce the patches (not in the repository: setup.sh
                downloads and extracts them)
tools/          make-patch.sh, the WSOLA command line tool and the playback speed test tools
DEVELOPMENT.md  how each feature works, decisions, tests
```

## Reporting bugs

Please open an issue **on this repository**. Catavan is not Kdenlive: **don't report Catavan bugs to KDE**. Feedback
from VEGAS users is especially welcome, for example behaviour you miss or something that works differently from
VEGAS.

## Credits and license

- Catavan is an **unofficial fork of [Kdenlive](https://kdenlive.org)**. Almost everything in it (the editor, the
  effects, rendering, the whole interface) is the work of the Kdenlive authors and the KDE community. Huge thanks to
  them.
- It includes a modified **[MLT](https://www.mltframework.org)**. The WSOLA code is ported from **Chromium**
  (`media/filters/audio_renderer_algorithm.cc`, BSD-3-Clause), and its original copyright notice is kept.
- License: **GPL-3.0** (see [LICENSE](LICENSE)), the same as Kdenlive. Each source file keeps its own license header.
  The MLT parts keep MLT's licenses (LGPL-2.1, with some GPL modules).

Catavan is not affiliated with or endorsed by KDE, the Kdenlive project or VEGAS Creative Software. "VEGAS Pro" is
mentioned only to describe the workflow that inspired it.

If some of these features turn out to be useful, I'd be glad to propose them to Kdenlive upstream.
