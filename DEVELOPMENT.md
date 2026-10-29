# Catavan — development notes

How each feature works, the decisions behind it and how it was tested. For users, see `README.md`.

## Conventions

- **Every feature is behind an option** in `kdenlivesettings.kcfg`, shown in Configure → Timeline under
  "Catavan:". The fork options are **on by default**: `pitchMethodPerClip`, `trimEdgePreview`, `actionCursor`,
  `splitShortcut`, `deleteMarkerMenu`, `clickOnClipSeeks`, `markersKeepPlayhead`, `autoRippleTool`,
  `dropPushesClips`, `monitorSpeedSlider`, `wheelZoomsTimeline`, `groupTrimPush`, `overlapCrossfade`,
  `scrollReleasesPlayhead`, `ungroupSelectedOnly`, `removeMixClips`, `vegasShortcuts`, `clipHighlight`, `transformMirror`, `groupTracksIndependent`, `shareSpeedProducers`; the original
  `timelinemousezoomonplayhead` and `parallelrender` are now on too. Off on purpose:
  `rippleTrimLive`, the original `pauseonseek` and the initial state of the `autoRipple` toggle. New options
  follow the same rule.
- **Minimal patches:** `patches/<feature>.files` lists the files of a feature, `tools/make-patch.sh <feature>`
  writes `patches/<feature>.diff` against `upstream/`. The diffs are cumulative: when two features change the same
  file, both diffs carry the whole changed file. `tools/make-patch.sh` without arguments lists changed files that
  belong to no feature (the icons and splash pictures of the branding are binary and listed there on purpose).
- **The repository has no sources:** `src/` and `upstream/` are not in Git. `patches/catavan.patch` (`git diff
  --binary`, every change including the icons) is what `setup.sh` applies to the downloaded tarballs to create `src/`.
  `tools/make-patch.sh` rewrites it after each feature diff; `tools/make-patch.sh --all` rewrites only it. **Run it
  before every commit** that changes `src/`. `setup.sh` never touches an existing `src/`.
- **Code comments** of the fork start with `Catavan:`; option labels and translation contexts too.
- **Translations:** new strings get a pt-BR translation at the end of `po/pt_BR/kdenlive.po`, with a `#. Catavan`
  comment.

## Features

### Identity (patch `branding`)

- Internal name `catavan`: `~/.config/catavanrc` (`catavan-appimagerc` / `catavan-flatpakrc` in the packages), data in `share/catavan` and `~/.local/share/catavan`, kxmlgui
  `kxmlgui5/catavan/catavanui.rc` (an alias of `kdenliveui.rc` in the qrc), lock file `catavanlock`,
  `catavan.notifyrc`, `catavan_*.knsrc` (downloads in `catavan/...`), executables `catavan`/`catavan_render` (the
  CMake targets stay `kdenlive`/`kdenlive_render`, through OUTPUT_NAME), D-Bus `com.hexoby.catavan`.
- App ID: `CATAVAN_APP_ID` in `CMakeLists.txt`, also written in `data/kdenlive.notifyrc`,
  `data/org.kde.kdenlive.desktop` (X-DBUS) and `data/org.kde.kdenlive.appdata.xml` (own metainfo).
- Translations: domain `catavan`. The sources stay `po/<lang>/kdenlive.po`; CMake copies them to
  `build/po-catavan/<lang>/catavan.po` before `ki18n_install`. `kdenliveui.rc` declares `translationDomain="catavan"`
  (version 252): with upstream's `kdenlive` the menus it defines (Edit, View, Sequence, Markers...) were translated only
  where Kdenlive itself was installed. Interface strings naming the application say Catavan in
  all languages (`tools/rebrand/`). "Kdenlive" stays in format names (project, document, title, layout, JSON, effect
  definitions), the online docs, the funding / get involved texts and the update reminder.
- Version: `CATAVAN_VERSION` (About, `--version`, splash, wizard). `KDENLIVE_VERSION` is still written in saved
  projects, OTIO and subtitles, and used by the update reminder (`checkForUpdate`, now off by default).
- Wizard subtitle: "Based on Kdenlive %1, using MLT %2". Help → Donate (KHelpMenu, which would open
  `kde.org/donate?app=catavan`) becomes "Donate to Kdenlive…" and opens `https://kdenlive.org/fund/`; it is rewired in
  the same place as the help contents action, so it survives a UI rebuild.
- Repository `CATAVAN_REPOSITORY` (CMake, https://github.com/Matheus290/Catavan): About homepage and "Source code" line,
  bug address (Report Bug and the crash dialog would otherwise go to bugs.kde.org; Help → Report Bug is rewired to open
  `<repository>/issues`), splash "What's New" (`<repository>/releases`). The metainfo carries the same URLs and
  developer id `io.github.matheus290`.
- About: the Kdenlive component shows `KDENLIVE_VERSION` (`KDENLIVE_FULL_VERSION_STRING` is empty outside a Kdenlive
  git checkout) and links to kdenlive.org; the roles of the Kdenlive authors are wrapped in "Kdenlive: %1", which keeps
  their existing translations.
- Splash: upgrade and donate bars say Catavan is based on Kdenlive and link to kdenlive.org without the Kdenlive campaign
  parameters. Upgrade detection compares `CATAVAN_VERSION`, the version the splash stores as last seen.
- Art: own icons (theme name `catavan`, `.desktop` `Icon=catavan`; file type icons `application-x-catavan` and
  `application-x-catavantitle`, set with `<icon>` in `data/org.kde.kdenlive.xml`), `data/pics/catavan-logo.png` and
  splash background. "Made by KDE" and `kde-logo.png` removed from the splash. Credits in `REUSE.toml`: Catavan art
  CC-BY-4.0, title icon LGPL-3.0-or-later (derived from the Kdenlive one). The images are binary and stay out of
  `branding.diff`: they live only in `src/` (originals in `../Arte`).
- Kept from Kdenlive: the `.kdenlive` format, the QML module names
  (`org.kde.kdenlive`), the log categories `org.kde.kdenlive*`, the mime type `application/x-kdenlive` (installed
  under a Catavan file name).
- Tested: builds; starts with `catavanrc`/`catavanlock` in a temporary profile; `catavan --render` of
  `tests/dataset/test-mix.kdenlive` writes the MP4 through `catavan_render`.

### WSOLA pitch compensation per clip (patch `wsola`)

- MLT: new module `src/modules/wsola` (`MOD_WSOLA`, on by default) with the `wsola` filter. It receives the audio
  that `timewarp` relabeled with the frequency f×speed, runs WSOLA at rate (f×speed)/f and returns ≈N/speed samples
  at f (the same duration the rubberband path gives the resampler). It starts over when the frame position is not
  continuous (seek).
- `producer_timewarp.c`: new property `warp_pitch_method` ("wsola" → the new filter, falling back to rbpitch if the
  module is missing; any other value → rbpitch, as upstream).
- Kdenlive: option `pitchMethodPerClip`. Off: the original speed dialog (checkbox). On: "Pitch compensation: None /
  Rubberband / WSOLA" per clip.
  - The compensation became an int (0 none, 1 rubberband, 2 wsola) along the whole Change Speed path (dialog →
    requestClipTimeWarp → useTimewarpProducer → refreshProducerFromBin, undo/redo, cloneClip, copy/paste, reload).
    `ClipModel::{get,set}PitchCompensation` read and write `warp_pitch` + `warp_pitch_method` on the producer.
  - Saved in the project. `warp_pitch_method` is only written on clips that used WSOLA. Upstream Kdenlive/MLT ignore
    the property (they play those clips with rubberband). A WSOLA clip keeps WSOLA with the option off (project data).
- The port (`wsola_algorithm.{h,cpp}`) keeps Chromium's constants, index arithmetic, SIMD (SSE/AVX2/NEON) and even its
  quirks (a wrapping size_t exclusion interval; `FullSearch` starting at `numeric_limits<float>::min()`). Only
  `AudioBus`/`AudioBufferQueue`/`base::` were replaced. Left out: the resampling path (preserves_pitch=false) and the
  renderer's capacity/latency management. The CLI (`tools/wsola-cli`) builds the same file.
- Tested: the CLI was compared by ear with Chrome; the MLT filter output is identical to the CLI (correlation 1.0000)
  at 1.1x and 2x, with the right duration and pitch; seeking gives the same output as a new producer; two clips with
  different methods in one playlist survive a round trip through the XML. WSOLA latency in timewarp: ~10 ms (2x) to
  ~40 ms (1.1x), close to rubberband (~37 ms).
- History: the first version used a global environment variable (`MLT_WARP_PITCH_METHOD`), replaced by the choice per
  clip.

### Edge frame preview while trimming (patch `trim-edge-preview`)

- Option `trimEdgePreview`. Selection tool only; the Ripple tool has its own trimming mode.
- `Clip.qml` (trimIn/trimOut handles): on press and on each duration change it calls
  `TimelineController::showTrimEdgeFrame(clipId, right, size)`; on release/cancel, `hideTrimEdgeFrame()`. `size` is
  the drawn duration when the Auto Ripple trim only draws the clip longer.
- The controller computes the source frame of the edge (in/out × speed, as for the timeline thumbnails) and calls
  `Monitor::showEdgeFrame(binId, frame)` → `VideoWidget::showEdgeFrame`.
- `VideoWidget`: while active, `onFrameDisplayed` ignores the consumer frames (the picture stops, the audio goes on
  since the consumer keeps running) and `m_sharedFrame` gets the edge frame, rendered in yuv420p at the monitor size by
  a clone of the bin producer (no effects) in a thread (QtConcurrent). One render at a time; requests in between are
  merged into the last one. On release, the last consumer frame comes back.
- Limits: the frame of the source clip (no clip effects, no tracks above); not in GPU mode (movit) nor on the mirror
  monitor.
- History: the first version drew a QML `Image` over the video; replaced by swapping the monitor picture itself.

### Action cursor (patch `action-cursor`)

- Option `actionCursor`.
- `MonitorProxy::actionPosition` (project monitor): -1 = joined to the playhead. `Core::getMonitorPosition` returns
  the action cursor when there is one, so split, markers, guides, paste and the other position-based actions use it
  without changes to each action.
- `Timeline.qml`: a click (or drag) in the tracks area calls `TimelineController::requestActionPosition(frame)`;
  during playback it only places the action cursor and returns true (no seek). When paused, the original seek
  happens. Drawn as a 2 px line in the accent color.
- It joins the playhead again when the playback stops (the playhead stays where it stopped) and on any seek
  (`Monitor::processSeek`: ruler, keyboard, etc.). A click on the ruler still moves the playback.

### Clicks, ruler and markers (patches `click-on-clip`, `markers-keep-playhead`, `delete-marker`, `seek-keeps-playing`)

- `clickOnClipSeeks`: `onClicked` of the `dragProxyArea` in `Timeline.qml` moves the playhead (or only the action
  cursor during playback) to the clicked point. Ctrl/Shift clicks (multiple selection) don't.
- `markersKeepPlayhead`: no seek on right click in `Ruler.qml`/`Timeline.qml`. `GuidesList::selectionChanged` only
  seeks on a key press (event filter) or a click (`pressed` signal): the Markers panel selects a new marker by itself,
  which used to bring the playhead to it a moment after G.
- `deleteMarkerMenu` (ruler context menu): `Ruler.qml` stores `rightClickedGuide`; `TimelineWidget::showRulerMenu`
  shows "Add Marker" away from a marker (`m_addGuideAction`: only adds at the action cursor/playhead, with a message
  if a marker is already there) and "Edit Marker…"/"Remove Marker" on a marker (they act on that marker). The original
  Add/Remove toggle (`add_sequence_marker`, M with `vegasShortcuts`, G upstream) is only removed from this menu (`removeAction`: `setVisible(false)`
  would also disable its shortcut).
- `pauseonseek` (original Kdenlive option) is now off by default: seeking does not pause.

### Split at the cursor (patch `split`)

- `TimelineController::splitClipsAtCursor`: the selected clips under the cursor; without selection,
  `requestClipCutAll(..., allTracksIfNoneActive=true)` (the tracks active for timeline operations, or all tracks).
- Option `splitShortcut` changes the default shortcuts (S = Split, X = Selection tool, Razor without shortcut; needs a
  restart). pt-BR "Cortar" has its own msgctxt.

### Auto Ripple and the pushing drop (patch `auto-ripple`)

- The "Auto Ripple" toggle (action `auto_ripple`, shortcut Ctrl+L with `vegasShortcuts`, M without; button `auto_ripple_button` with a Clips Only / Clips
  and Markers menu) replaces the Spacer tool button, which is hidden (option `autoRippleTool`; state `autoRipple`, mode
  `autoRippleMarkers`). `kdenliveui.rc` went to version 251.
- Only with the Selection tool in the Normal edit mode (`TimelineController::autoRippleActive`).
- Dragging a clip: the `dragProxyArea` refuses the press and the `tracksArea` starts a spacer operation at the clip
  start (all tracks, horizontal only, `rippleDragItem`). No move = a click on the clip (it also calls `showAsset`, as
  the plain click does: a grouped clip is a multiple selection, which shows no effect stack by itself). Only what starts at the clip
  start or later follows (`requestSpacerStartOperation(..., startingAfterOnly)`); a clip starting before and crossing
  that point stays.
- To another track (same kind, audio or video): `rippleDragToMove` ends the spacer operation without moving (markers
  back too) and the drag goes on as a plain move of the clip (`rippleMoveItem`: `suggestCrossfadeMove`, or
  `suggestClipMove` without `overlapCrossfade`; on release `endFakeMove` / `requestClipMove`, as the `dragProxyArea`).
  Nothing is pushed or closed. Back on the clip's track, `rippleMoveToDrag` puts the clip back and starts the ripple
  drag again (`startRippleDrag`, also used by the press).
- Deleting: `TimelineFunctions::rippleDelete` → everything starting at the deleted start or later moves back by
  min(duration, start of the first following item − deleted start), never before that start (`floor` in
  `rippleShift`), each track as far as its free space allows.
- Trimming (`TimelineFunctions::rippleResize`): the clip never moves (its end changes; on the left edge the content
  slips with `requestClipSlip`, the slip coming before the resize when growing). Group members sharing the edge follow
  (each up to the end/start of its material); members whose edge is reached when shrinking are trimmed along
  (`groupTrimPush`). Then the ripple on all tracks, group members included, each item moved alone
  (`rippleMoveItems`, shift per track): left edge → what starts at the clip start or later, never before that start
  (it aligns there); right edge → what ends after the old end, by the same amount. Deleting uses `rippleMoveItems` too.
- Crossfades in a ripple: resizing or moving one clip of a mix alone leaves the mix where it was (an inconsistent
  track: "Mix not aligned"). `rippleResize` (for the parts, pushed and following items) and `rippleMoveItems` (for the
  moved items) take the mixes out first (`removeRippleMixes`: the two clips are cut at the mix cut) and put them back at
  the end (`restoreRippleMixes`) between the same clips, with the same cut and transition, when the two clips still
  meet; each side is limited to what is left of the other clip (one frame kept). A crossfade on the trimmed edge so
  moves with it. A ripple trim never makes a clip shorter than its crossfades plus one frame (`rippleMinPlaytime`).
- Slips and moves: `ClipModel::requestSlip` (used by the left edge) changed only the producer in/out, not the copy
  kept by the MLT playlist entry; `mlt_playlist_replace_with_blank` (every move) puts the entry's in/out back on the
  producer, so a moved clip got its old in point back, on one track and not on another (the entry is refreshed by any
  later change of that playlist): audio and video out of sync. The slip and its undo now also call
  `TrackModel::syncClipEntry` (`resize_clip` with the same in/out, which refreshes the entry). Upstream Slip tool too.
- Not live (default, `rippleTrimLive` off): shrinking and the left edge use the normal live trim (the group is pushed
  live); growing the right edge also uses the normal live trim while it fits, and only draws the clip longer once a
  clip is in the way (`requestItemResize` stops at its start: when the result falls short of the request beyond the
  snap distance, the clip is drawn longer). On release, `restoreItemsData` (data from `getGroupData` at the press)
  undoes the preview exactly and `rippleTrimApply` applies everything in one undo step.
- Pushing drop (option `dropPushesClips`, one clip only): the drag uses the fake move (as the Insert mode); on
  release, `TimelineFunctions::insertClipPushing`: a drop inside a clip goes after it; without room, the following
  items move by the whole clip duration on the clip's tracks (all tracks with Auto Ripple; markers too in the Clips and
  Markers mode).
- Markers in a ripple (Clips and Markers mode, and the spacer with markers): every path goes through
  `MarkerListModel::rippleMarkers(position, delta)` (spacer end, ripple shift/delete, closing a gap, ripple trim,
  `moveGuidesInRange` without an end). Markers starting at or after the position move. Range markers (regions) follow
  their content: one crossing the position grows or shrinks with the inserted or removed span, one starting in a
  removed span starts at the cut, one whose whole span is removed becomes a point marker at the cut. Point markers
  inside a removed span stay (as before). The markers move from the last one when moving right, so a moved marker no
  longer replaces one that has not moved yet (`moveMarkers` lost it). Two regions landing on the same frame become one
  (one marker per frame). The drag preview moves the markers after the position (`spacerMoveGuides`); in the Auto
  Ripple drag the regions crossing it also grow or shrink with the drag (`TimelineController::rippleGuidesStart`,
  `rippleResizeGuides`, `rippleRestoreGuides` over `MarkerListModel::setDurationsWithoutUndo`): their durations are
  given back before the undoable ripple on release, which then computes the final shape.
  In the Auto Ripple drag the position is the start of the dragged clip (`rippleGuidesFrame` in `Timeline.qml`), not
  the spacer item (`requestSpacerStartOperation` may return a later clip on another track) nor the click frame (inside
  the clip): with either, a region starting between the clip start and that frame only had its end moved.
- Tests: `tests/vegasrippletest.cpp` (includes crossfades in a ripple trim and slipped clips that move). A random test
  of cuts, ripple trims (with the Track.qml preview), ripple drags with crossfades and ripple deletes on grouped
  audio/video clips, checking sync and `checkConsistency` after each step, found these (600 sequences pass); it is not
  kept in the repository. Cutting inside a crossfade (upstream `requestClipCut`) still leaves an inconsistent track.

### Grouped clips while trimming (patch `group-trim`)

- Option `groupTrimPush`. `TimelineModel::requestItemResize` (normal trim): besides the members with an aligned edge,
  it pushes the members whose edge is crossed when shrinking and, on the right, also when growing (the member then
  follows up to the end of its own material; `rippleResize` does the same and doesn't move that member in the ripple).
  Growing, each member stops at the end of its own material (upstream the whole resize failed) and a member without
  room is skipped. No ripple between group members.

### Ungroup only the clicked clips (patch `ungroup-selected`)

- Option `ungroupSelectedOnly`. A plain click on a grouped clip selects the whole group, so the selection alone
  doesn't say which clip to take out: `TimelineController` keeps the clicked items (`setClickedItem`, called by the
  `dragProxyArea` press, the Auto Ripple click on release and the Shift+click on release in `Timeline.qml`, and the
  right click in `Clip.qml`) with the selection they made (`m_clickedSelection`). They only count while the current
  selection is the same set, so any other selection change (rubber band, keyboard, grouping, the spacer group of an
  Auto Ripple drag) makes Ungroup fall back to the original. A Shift+click adds to the previous clicks when the
  selection only grew by the clicked item's group. (A first version cleared them on `selectionChanged`; the Auto
  Ripple path left a stale click that still matched a later selection.)
- `unGroupSelection` picks, in order: the clip given by the caller, the selection in single selection mode
  (Alt+click), or the clicked items still in the selection. With none of them (or none in a group), the original
  Ungroup runs. The clips taken out stay selected (and stay the clicked items; Alt+click keeps the single selection).
- `TimelineModel::requestRemoveItemsFromGroups`: the unit that leaves is the item, or its audio/video pair (AVSplit
  group) when the pair is inside a larger group; a pair alone is split as upstream. Each group on the way from the
  root to a unit is destructed (`ungroupItem`, top down) and grouped again with what remains (bottom up, same type),
  so a group left with one member disappears and nested groups lose the unit too. Undo/redo in one step
  ("Remove from group").
- Tested: `tests/vegasgrouptest.cpp` (group of three pairs, the audio part picking the pair, two at once, nested
  groups, a pair alone, undo/redo).

### Selection as in Vegas (patch `vegas-selection`)

- Option `vegasSelection` (on by default). `Timeline.qml`: `root.selectionAnchor` is the last item clicked (plain
  click, the Auto Ripple click, Ctrl+click). A Ctrl+press on an item (`tracksArea.ctrlClickItem`) does not hide the
  cursor: the pan only starts after 5 px of movement; a release without it adds the item to the selection or removes
  it (`setClickedItem(item, true)`, so Ungroup still takes out the clicked items). The Shift+click release (no rubber
  band) calls `TimelineController::selectItemsBetween(anchor, item, ctrl)`, which sets the selection to
  `TimelineModel::getItemsBetween` (plus the current selection with Ctrl). Without a selected anchor, only the clicked
  item. `SubTitle.qml` handles both clicks itself (`selectionClick` keeps the subtitle from moving).
- `getItemsBetween`: the tracks between the two items by position (the subtitle track counts as above the top one),
  the range from the first start to the last end (`getItemsInRange`: items crossing it, end exclusive, compositions
  included), locked tracks skipped, both items always in.
- Unchecked: Shift+click toggles an item and Ctrl+drag pans, as upstream.
- Tests: `tests/vegasselectiontest.cpp` (one track in either order, adjacent clip left out, across three tracks,
  locked track, no anchor). The interface was not driven by the tests.

### Zone by dragging (patch `drag-zone`)

- Option `dragSetsZone` (on by default). `Timeline.qml`: a left press in an empty part of the tracks (the branch that
  clears the selection and moves the playhead) keeps `root.zoneDragFrame`, the press x and the zone before it
  (`zoneDragOld`). Past the start drag distance, the drag sets the zone from the press frame to the mouse frame (both
  through `suggestSnapPoint`, Shift turns snapping off) with `updateZone(old, zone, false)` instead of moving the
  playhead. On release the zone goes back to `zoneDragOld` without undo and is set again with undo ("Set Zone"), so the
  snap points of the zone are those of `setZone`; `onCanceled` only goes back. A press on a clip, Shift+drag (rubber
  band) and Ctrl+drag (pan) are unchanged.
- Unchecked: the drag moves the playhead, as upstream.

### No Mix Clips, U ungroups (patch `remove-mix-clips`)

- Option `removeMixClips` (needs restart, read in `MainWindow::setupActions`). The `mix_clip` action is hidden
  (`setVisible(false)`: out of the menus and toolbars, no shortcut) and loses U; `ungroup_clip` gets U besides
  Ctrl+Shift+G (`setDefaultShortcuts`, before `setupGUI`, so shortcuts changed by the user still win).
- `Clip.qml`: the double click on the in/out trim handles no longer calls `mixClip` (read live).
- Kept: dropping a transition from the list on a cut (`insertNewMix`), an explicit choice of transition.

### Hover and clicked clip highlight (patch `clip-highlight`)

- Option `clipHighlight` (read live by the QML). `Clip.qml`: `hovered` = option and `mouseArea.containsMouse` (the
  right-button area that already drives the hover handles); `hoverColor()` raises the HSL lightness by 0.08 and takes
  20% of the saturation, on top of the normal (darker) or selected (full) clip color. Audio clips: the waveform
  (`ClipAudioThumbs.qml`) paints its own background over the clip color, so its `bgColorEven/Odd` go through the
  clip's `hoverColor()` too. Compositions (`Composition.qml`, its own `hovered`/`hoverColor`) and subtitles
  (`SubTitle.qml`, background of the text field under `subtitleClipArea`) get the same hover.
- Border of a selected clip: `root.mainItemId` (the clicked item, already used for the bright red title) keeps
  `selectionColor`; the other selected clips get `Qt.darker(selectionColor, 1.6)`. Only the clicked item itself, as
  the title (its audio/video partner gets the darker border). Selected compositions follow the same rule
  (`Composition.qml` sets `mainItemId` when clicked).
- The Auto Ripple click (its own press path in `Timeline.qml`) did not set `mainItemId`, so the title of the clicked
  clip stayed dark red in that mode: it is set at the ripple press now.

### Vegas shortcuts (patch `vegas-shortcuts`)

- Option `vegasShortcuts` (needs restart, read in `MainWindow::setupActions`): `add_sequence_marker` M (upstream G),
  `group_clip` G besides Ctrl+G (`setDefaultShortcuts`), `auto_ripple` Ctrl+L (M without the option). The Spacer tool
  loses M when Auto Ripple is off (M is the marker). Ctrl+L was free (L seeks forward, Shift+L / Ctrl+Shift+L lock
  tracks).

### Automatic crossfade (patch `crossfade`)

- Option `overlapCrossfade`. Works in the plain drag (Selection tool, Normal mode) and in the Auto Ripple drag.
- Plain drag: fake move (as the Overwrite mode). Auto Ripple: the spacer group (the clip and everything after it on all
  tracks) may pass the free space limit (`spacerMinPos` ignored) and the end goes through
  `TimelineFunctions::requestSpacerEndOperation(..., crossfade)` (only when `autoRippleActive()`; the Spacer tool is
  unchanged).
- `TimelineModel::planCrossfadeMove`: each moved clip may cover the end of a clip and/or the start of another one on
  its track; covering a clip, overlapping two mixes or entering an existing mix is invalid, and
  `suggestCrossfadeMove` stops at the last valid position on the way. Compositions and subtitles of the group just
  move along.
- An overlap of one frame is invalid (the mix is cut in the middle, one side would be empty: wrong snaps and track
  duration); the drag stops before it.
- `requestCrossfadeMove` (on release): removes the mixes of the moved clips with clips that stay; computes the final
  edge of each affected clip from its full length (removing a mix cuts at the cut point; each overlap is cut in the
  middle); shrinks what needs it → moves with the native move (`requestGroupMove` / `requestClipMove`, which carry the
  internal mixes of the group) → grows what needs it → `requestClipMix` (half/half; dissolve on video, mix on audio).
  One undo step. The VEGAS-style overlap is the native Kdenlive mix geometry, so the project opens in upstream Kdenlive.
- Edge drag (Selection tool, Normal mode, no Auto Ripple, no Ctrl): `crossfadeTrimBegin` on the press keeps the clip
  and its group (the same items as the group resize of `requestItemResize`) as they are. The drag uses the normal trim,
  which stops at the clip in the way; on each step `crossfadeTrimPreview(size, snap)` plans, from the press state, the
  edge of every clip that follows it (aligned edge; on the right also the crossed ones with `groupTrimPush`): up to its
  material, then over the nearest clip as a crossfade (not a grouped clip, no mix on the dragged edge, not into the mix
  at the other end of that clip, never covering it, at least 2 frames). The overlaps go to `root.crossfadePreviews`.
  On release `Track.qml` undoes the preview (`restoreTrimPreview`) and `requestCrossfadeTrim` applies it in one undo
  step: per clip, the clip in the way gives up its half of the overlap, the clip grows to the cut and `requestClipMix`
  extends both back (as `requestCrossfadeMove`). A grouped clip that cannot follow is left as it is; the dragged one
  failing reverts everything. Without overlaps the normal trim is untouched.
- An edge that already has a crossfade (with a clip outside the group) goes the same way, shrinking too: the crossfade
  is the overlap. `requestCrossfadeTrim` removes the mix (the two clips are cut at its cut) and rebuilds it from the
  new overlap with the same transition, cut in the middle; past the other clip there is no crossfade, the clip ends
  where the edge is and the other clip gets its full length back. While `m_crossfadeTrim` is set, the live trim
  (`requestItemResize` without undo) keeps the mix instead of removing it (that removal could not be undone by the
  preview). The QML clamp of the second clip's left edge at the mix cut is skipped, and the right handle of the mix
  (`trimInMixArea`) trims the end of the first clip (`crossfadeTrimBeginMix`) instead of `resizeStartMix`.
  That handle does not trim live: the right edge preview also returns `items` (per clip that follows the edge: its
  drawn end and the overlap left with the clip it crossfaded with), and the handle draws those clips (found with
  `getClipItemById`) and the mixes of their partners (`Clip.previewMix`), so the first clip and its grouped clips
  follow the handle; everything gets its model width back on release.
- Live preview: `crossfadePreview(clipId)` → `root.crossfadePreviews`; `Timeline.qml` draws the overlap with both
  ramps (the clip before fades out, the dragged one fades in) and the duration.
- The transition type and parameters of a mix removed by the drag go to the mix rebuilt between the same clips (or on
  the same side of the moved clip): `TrackModel::setMixAsset` (like `switchMix`, with the parameters; keeps position,
  cut and A/B direction). Audio only has `mix`.
- Fake moves in the Normal mode: `Clip.qml` / `Composition.qml` move the item into `dragContainer` when it gets a fake
  track. Upstream only took it out when the item changed tracks for real (the delegate is recreated); a fake move
  ending on the item's own track (dragged away and back, a refused move) left it there: drawn where the drag left it,
  out of reach of clicks, and on another track after a track insertion. When the fake track goes back to -1 the item
  returns to its track (`trackHolder`).
- A plain drag to another track with nothing to crossfade ends with `endFakeMoveUsual(..., trackId)` given the fake
  track: `getItemMovingTrack` ignores it in the Normal mode, so the clip used to stay on its track in the model while
  the view showed it on the other one. `suggestClipMove` takes the real track as the source of the first crossfade
  step (no fake track yet; -1 sent the group fallback to `requestClipMove` on track -1).
- Tests: `tests/vegascrossfadetest.cpp` (includes Auto Ripple, internal group mixes, drags to another track and edge drags). Upstream `mixtest` fails at
  one point only with `groupTrimPush` on (it passes with it off); `spacertest` and the others pass.

### Monitor playback speed (patch `monitor-speed`)

- MLT `mlt_producer_prepare_next` keeps the fractional part of the position (`_fraction`); otherwise 1.5x played at
  1x and 0.5x never moved (positions are integers). Integer speeds and rendering are unchanged.
- MLT filter `monitorspeed` (wsola module), attached to the monitor's FilteredConsumer: with `_speed` between 0 and
  `max_speed` (4) and ≠ 1, it fetches the audio of the source frames the video went through and squeezes it into one
  frame: linear resampling (the pitch follows) or WSOLA (`preserve_pitch`). For avformat to deliver the audio of k
  frames at once it sets `producer_consumer_fps` = fps/k on the frame; the tractor passes it on, `transition_mix.c`
  passes it to the b frame and `producer_timewarp.c` scales it by the clip speed.
- The sdl2/rtaudio consumers mute speeds ≠ 1 unless `scrub_audio`: the VideoWidget turns `scrub_audio` on when the
  filter handles the speed, and the consumers play audio marked `monitorspeed_audio` with the normal timing.
- `mlt_consumer.c` read `_speed` as an int (0.5 = pause) and took every step ≠ 1 frame for a seek (a preroll that
  stalled at every frame) → `frame_speed_class`/`position_continues`. The filter empties the audio stack of repeated
  frames (otherwise the consumer played the original audio too). `filter_wsola` (per clip) doesn't start over on the
  position jumps when `producer_consumer_fps` is set.
- Reverse: negative speeds down to −4x (the filter fetches the frames between the position and where it stopped,
  reverses and squeezes them).
- Speed changes: the slider applies its value 120 ms after it stops moving (each change purges and seeks the
  consumer), the seek goes to the next frame in the play direction, and WSOLA is primed with 3 frames when it starts
  over (each change with Pitch used to start with 30–70 ms of silence).
- `producer_avformat.c`: with `producer_consumer_fps` on the frame, the audio seek goes 0.25 s earlier and decodes up
  to the frame (as for the first seek): backwards, audio-only MP3/AAC (M4A) seeks landed up to ~70 ms off and the
  decoder started with garbage.
- `link_swresample.c`: timeline clips are `chain`s with `link_swresample`, which converted frame by frame. With
  `producer_consumer_fps` each fetch brings k frames and the position jumps by k, so it restarted the converter at every
  frame and filled the gap with audio of the next (already fetched) frame → repeated/skipped bits from ~1.5x on, with
  44.1 kHz audio in a 48 kHz project (e.g. OBS recordings). Now it converts everything at once, keeps the converter
  between continuous fetches and returns what comes out; backwards it flushes the converter at each fetch.
- `FilteredConsumer::attach` only works once a producer is connected (before, it fails silently with −1): the
  VideoWidget attaches the filter right after the first `connect` (`m_speedFilterAttached`).
- Kdenlive side: status bar slider (left of the messages), 0–4x in 0.01 steps, "Pitch" box (off by default,
  `monitorSpeedPreservePitch`); option `monitorSpeedSlider` (needs a restart). Play/Space uses `monitorPlaybackSpeed`
  (`Monitor::normalPlaySpeed`); the slider follows `MonitorProxy::speedChanged` (J/L/play); double click = 1x.
  J/L: `Monitor::stepPlaybackSpeed` ±0.25x (±1x beyond ±4x); K (`MonitorManager::slotPause`) goes back to 1x without
  pausing. Negative speeds only show in the label, the slider stays at 0.
- Reverse speed depends on the keyframe interval of the media (upstream MLT too, not Windows-specific): each frame
  backwards is decoded again from its keyframe. 1080p H.264 through a chain at −1x (2026-10-24, Windows): all intra
  25 fps, GOP 50 ~9 fps, GOP 250 ~3.5 fps; a plain producer (no chain) is about twice as fast. Proxies with short GOPs
  avoid it. Test: a scratch program playing a `Mlt::Chain` through `sdl2_audio` + `monitorspeed` and rendering each
  shown frame (as the VideoWidget), printing the consumer position every 0.5 s.
- Known limits: at a cut between clips up to ~speed frames of audio may come from the previous clip. Above 4x (L goes
  to 5.5x and 10x) the audio is muted, as upstream.
- Diagnostics: `MONITORSPEED_LOG=<file>` makes the filter write one line per frame (position, speed, seek, fetched
  frames, requested/received samples, queue).
- Tests: `tools/monitor-speed-test/run.sh` (outside Catavan: frequency steps; one clip, two-track mix, timewarp);
  `consumer.cpp` (the real sdl2 consumer with the SDL "disk" driver); `kdenlive-headless.sh` (Catavan itself: Qt
  offscreen + SDL disk + D-Bus, copied config, own TMPDIR because of the lock file); `continuity.py` (noise source:
  each 20 ms output block is located in the sped-up source, jumps = repeated/skipped audio, which test tones hide);
  `seekacc.cpp` + `seekan.py` (avformat seek accuracy); `record-session.sh` (records a real session). Results:
  continuous in WAV/MP3/M4A/OGG/Opus/FLAC at 1x/1.25x/1.5x/1.75x/2x/3x/4x and −0.5x/−1x/−1.5x/−2x. Gotchas: Catavan
  saves the speed on exit (the next run starts with it), and the clip checker opens an invisible dialog if the media
  doesn't match `kdenlive:file_hash`.

### Timeline mouse wheel and zoom (patches `wheel-zoom`, `zoom-on-cursor`)

- `wheelZoomsTimeline`: wheel = zoom, Ctrl+wheel = scroll (Shift and Alt unchanged). `Timeline.qml::wheelZooms(wheel)`
  decides; used in `zoomByWheel`, in the tracks area and on the ruler.
- Zoom on the cursor: the original `timelinemousezoomonplayhead` is on by default and shown in the settings;
  `Timeline.qml::onTimeScaleChanged` centers on the action cursor (`root.proxy.actionPosition`) when there is one.

### Following the playhead (patch `playhead-follow`)

- Option `scrollReleasesPlayhead`. `Timeline.qml` has `playheadFollowReleased`; `releasePlayheadFollow()` (only while
  playing, `proxy.speed != 0`) is called by `horizontalScroll`, the middle button drag, `onProposeContentPos` of the
  zoom bar, and when `proxy.actionPosition` becomes > -1. `onConsumerPositionChanged` doesn't scroll while released;
  following resumes when `proxy.speed` goes back to 0 (every pause goes through `VideoWidget::setProducerSpeed(0)`).

### Clips with the same speed share a producer (patch `share-speed-producers`)

- Option `shareSpeedProducers`. Upstream opens a `timewarp` producer (an avformat decoder with its frame threads) for
  each clip whose speed is not 1, while 1x clips share one producer per track. A 6 min OBS recording (3840x1080,
  108 Mbps) cut in 109 pieces at 1.1x used up to 20 GB in the application and as much again in the render process,
  and took 34 s to load in melt.
- `ProjectClip::getTimelineProducer(..., pitchMode)`: the clips with the same key (`sharedTimewarpKey`: track,
  playlist A/B, state, audio stream, speed, pitch compensation) get a `cut()` of one producer
  (`m_sharedTimewarpProducers`); `m_timewarpProducers` still maps each clip id to its producer, now possibly the same.
  The pitch compensation is written on the producer by `ClipModel` (`setPitchCompensation`), so it is part of the key:
  `ClipModel::construct` and `refreshProducerFromBin` pass it. A change of speed, pitch or track goes through
  `refreshProducerFromBin`, which moves the clip to the producer of its new key.
- `releaseTimewarpProducer`: a clip leaving a producer removes the bin effects from it (`removeService`) only when no
  other clip uses it; `registerService` (undo) does not plant them again on a producer already in use
  (`EffectStackModel::addService` would duplicate them).
- Loading (`giveMasterAndGetTimelineProducer`): the first clip of a key adopts its master from the project, the next
  ones get a cut of it (their own masters are dropped), so an old project shares after opening and is saved with one
  producer per key. The render file is written from the timeline, so the render shares too.
- Not shared: sequences and playlists (resources handled per producer), time remapping, missing clips.
- Tests: `tests/vegasspeedtest.cpp` (sharing, pitch, track move, deletion with undo, without the option).

### Faster render (patch `render-speed`)

- MLT `filter_avcolour_space.c`: `av_convert_image` converts with the slice threads of libswscale
  (`av_convert_image_threaded`, through `mlt_sws_scale_planes`); the old `sws_scale` path stays as fallback and for
  `yuv422p16`. The output is identical (compared bit by bit on project frames).
- MLT avformat `common.c`: `mlt_sws_cached_context` keeps the initialized swscale contexts per thread (8 per thread,
  most recently used first, freed with the thread). **Windows:** the pthread key destructor runs while the exiting
  thread holds the loader lock, and freeing a context waits for its slice threads, whose exit needs that lock. The
  first pooled thread to expire froze Catavan (closing waited for the pool forever; any later DLL load hung too).
  There the destructor hands the cache to a detached thread, which starts once the lock is released; if it cannot
  be created, the contexts leak. Creating a context and its slice threads for every frame, and for
  every slice of the sliced producer conversion, took a good part of the render time; render workers and
  `mlt_slices` threads live as long as the consumer. `mlt_sws_scale_planes` runs `sws_scale_frame` on AVFrames that
  wrap the caller's planes with a non owning `AVBufferRef`, so the input is not copied and the output is written in
  place. Users: `filter_avcolour_space`, `filter_swscale` (packed progressive images skip the copy of the input and of
  the output lines; the other cases keep the old path) and the producer (`sliced_h_pix_fmt_conv_proc`, and
  `convert_image_rgb` for progressive frames, now threaded).
- MLT `filter_avdeinterlace.c`: a progressive source (`meta.media.progressive` or `progressive` on the original
  producer, as `link_deinterlace` of the xine module checks) keeps the requested format. It used to force `yuv422`,
  so every frame went yuv420p → yuv422 → rgba on the way to qtblend. The direct conversion is not bit identical (no
  intermediate 4:2:2 chroma) but equal to the eye (PSNR 48–52 dB against the old output).
- MLT `producer_avformat.c`: the decoded picture is referenced (`av_frame_clone`) under the locks and converted after
  they are released, so the parallel render workers sharing a producer decode the next frame meanwhile; the image
  cache put stays under `video_mutex` (`cache_image`) because a reset may close the cache. Error concealment keeps a
  reference to the last good decoded picture (`last_good_picture`) and converts it on a decoding failure, instead of a
  deep copy of every converted image (16 MB per 3840x1080 rgba frame).
- Hardware decoding on by default with an NVIDIA card: `Wizard::autoEnableHwDecoding` sets `hwDecoding=nvdec` once,
  when `supportedHWCodecs` (the hardware check of the configuration wizard, run on the first start) has an `_nvenc`
  codec and `hwDecoding` is empty; the hidden flag `hwDecodingAutoChecked` keeps it from coming back after the user
  turns it off in the wizard. Called by `MltConnection` (startup, before `MLT_AVFORMAT_HWACCEL` is set) and after
  `testHwEncoders`. It applies to the editing too (upstream behaviour of the option): every open clip holds an NVDEC
  context; MLT falls back to software decoding when the card cannot decode. VA-API, D3D11 and VideoToolbox are not
  turned on by themselves (not measured).
- `parallelrender` on by default (4 threads, the upstream default count; 8 and 12 were slower). The parallel render file
  was identical to the serial one.
- Measured on the project above (`melt`, 60 s of timeline, NVENC, 4 workers): 110 s → 68 s with these MLT changes
  and hardware decoding (`MLT_AVFORMAT_HWACCEL=cuda`, the `hwDecoding=nvdec` option of the configuration wizard); the
  whole 5:21 video in 4 min 47 s (Catavan with libx264 and one worker: 14.5 min). Encoding (libx264 or NVENC) is not the
  bottleneck; what is left is the queue on the shared decoder and the qtblend compositing.
- Memory of the whole render (same project, 3840x1080 sources, 1080p output, NVENC); before these changes
  `catavan --render` peaked at 661 MB:

  | Workers | Decoding | Time | Peak RAM (render process) | Peak VRAM |
  |---|---|---|---|---|
  | 1 | NVDEC | 11:02 | 2.6 GB | 1.5 GB |
  | 2 | NVDEC | 5:14 | 3.3 GB | 1.5 GB |
  | 4 | NVDEC | 4:43 | 3.5 GB | 1.5 GB |
  | 4 | CPU | 6:38 | 2.8 GB | 0.2 GB (NVENC only) |

  Catavan itself, with the project open, adds about 2 GB. Memory grows with the worker count and the source
  resolution (a 3840x1080 rgba image is 16 MB): 8 GB of RAM is the minimum and 16 GB is recommended for such sources.
- Testing with `melt` from a shell: set `LC_NUMERIC=C`. With a locale that uses a decimal comma (pt_BR) the `1.1:`
  of a timewarp resource is read as 1, and the clips play at the wrong speed (Catavan sets `LC_NUMERIC=C` itself).

### Grouped clips change tracks by kind (patch `group-tracks`)

- Option `groupTracksIndependent`. Upstream moves the other kind of a group in mirror (video down one track = audio
  up one track, symmetric around the middle), which also blocks a move when the mirrored track does not exist (V2 →
  V1 with the audio on A1). Now the clips of the dragged clip's kind move by the same number of tracks and the
  other kind keeps its tracks (an audio/video pair is independent; a selection of video clips still moves together).
- Where the mirror delta was computed: `requestFakeGroupMove` (drag preview), `requestGroupMove` (its destination
  check and the deltas; the "audio up needs a video track" check is skipped) and `TimelineController::endFakeGroupMove`.
  Upstream's Meta modifier (`moveMirrorTracks` false: only the dragged item changes track) is unchanged.
- Tests: `tests/vegasgrouptest.cpp` (real move with undo, fake move, without the option). Upstream `modeltest` fails
  only in "Creation and movement of AV groups" (it checks the mirror) with the option on; it passes with it off.

### Mirroring in Transform (patch `transform-mirror`)

- Option `transformMirror`: in the Transform effect (`qtblend` filter), Size W / H accept negative values. A negative
  width mirrors the image horizontally, a negative height vertically; the rect keeps its position and absolute size
  (the sign is only a mirror flag). Keyframes between +w and -w pass through 0, so the image folds over.
- MLT `filter_qtblend.cpp`: the sign of `rect.w` / `rect.h` becomes `mirrorX` / `mirrorY` and the rect uses the
  absolute size; the mirror (translate + scale −1 inside the rect) comes after the rotation and before fitting the
  image to the rect, so a mirrored image rotates like any other. A mirror forces the painting path (`hasAlpha`), also
  for a full frame rect. Upstream had no meaning for a negative size (the image went out of the frame), so this is
  always on in MLT; the option only gates the UI. The `qtblend` transition (Composite and transform) is unchanged.
- `GeometryWidget::setMirrorable` (set by `KeyframeContainer` for `qtblend` with the option): the size spin boxes
  allow negative values; alignment, fit, size %, aspect ratio lock and the rotation anchor use the absolute size
  (`boxWidth`/`boxHeight`) and keep the sign (`withMirror`).
- Monitor: `Monitor::setUpEffectGeometry` gives the scene the rect with its absolute size. A rect dragged in the
  monitor comes back without sign: `GeometryWidget::slotUpdateGeometryRect` and
  `KeyframeContainer::slotUpdateKeyframesFromMonitor` (for the `RotatedRectHelper` path) put the current sign back.
- Tested: `melt` with an asymmetric image, `rect` with -w, -h, a full frame -w rect and a rotated -w rect.

### Default layout (patch `default-layout`)

- `data/layouts/editing.json` (the layout loaded when there is no saved layout) has two areas on top: media + Library
  | Project Monitor + Clip Monitor + Speech Editor + Notes. The middle area became an empty KDDockWidgets placeholder
  (no `guestId`) so the indexes of the other items don't change.

## Structure

```
setup.sh            distribution dependencies + sources + .stignore (idempotent)
build.sh            builds MLT, the WSOLA CLI and Catavan; starts Catavan (./build.sh --help)
versions.env        versions/URLs/sha256 of the tarballs
src/                modified sources (kdenlive-26.08.2, mlt-7.42.0) — not in Git, created by setup.sh
upstream/           untouched copies, base of the diffs — never edit; not in Git
patches/            catavan.patch (everything, applied by setup.sh), <feature>.files (file list) and <feature>.diff
packaging/
├── flatpak/        com.hexoby.Catavan.json + build.sh (bundle in ~/.cache/catavan-build/packages)
├── appimage/       build.sh + collect.sh + AppRun (AppImage made from the Flatpak build)
└── windows/        build.sh + catavan.nsi (portable .zip and NSIS installer made from the MSYS2 build)
tools/
├── make-patch.sh   writes patches/<feature>.diff and catavan.patch; without argument, finds orphan files
├── rebrand/        "Kdenlive" → "Catavan" in the interface strings (code and translations)
├── monitor-speed-test/  playback speed test tools (see above)
└── wsola-cli/      CLI + compare.html (A/B against Chrome)
```

Outside the source tree: `~/.cache/catavan-build/{downloads,build,install,env.sh}`.

Build options of `build.sh`:

- `EXTRA_MODULES` (default 1): the optional MLT modules Glaxnimate, OpenCV (tracking) and RNNoise. On Debian/Ubuntu,
  without an rnnoise package, `build_rnnoise` builds the release tarball (`versions.env`, downloaded by `setup.sh`)
  as a static PIC library in the prefix, linked into the module. `EXTRA_MODULES=0` for faster development builds.
- `NO_INSTALL=1`: builds without `cmake --install` (installing replaces the libraries of a running Catavan).
- `cmake_build` reconfigures when the flags change (`.build-flags` in the build directory).
- The cache path is resolved with `realpath`: with `~/.cache/catavan-build` as a symbolic link to another disk, the
  relative include paths that AUTOMOC writes from the link path did not resolve (Glaxnimate).
`source ~/.cache/catavan-build/env.sh` puts the local `melt`, `wsola-cli` and `catavan` in the PATH.

## Packages

- **Flatpak** (`packaging/flatpak/build.sh`): the manifest is the Flathub manifest of Kdenlive 26.08.2 with
  `com.hexoby.Catavan`, MLT and Catavan from `src/` (`dir` sources: run `setup.sh` first) and the optional MLT modules
  (RNNoise added as a module). It writes a single-file bundle (`flatpak build-bundle`, runtime from Flathub). State
  and cache in `~/.cache/catavan-build/flatpak`; the first build takes about an hour, later ones only rebuild what
  changed.
- **NVIDIA headers:** the KDE SDK 6.11 has nv-codec-headers 13.1, whose NVENC needs driver 610 or newer ("Driver does
  not support the required nvenc API version. Required: 13.1"). The manifest builds nv-codec-headers 12.2 (driver 550
  or newer) before FFmpeg, and FFmpeg gets `--extra-cflags=-I/app/include`: without it, the SDK headers in
  `/usr/include` won.
- **AppImage** (`packaging/appimage/build.sh`, after the Flatpak): `flatpak build` runs `collect.sh` inside the
  Flatpak build sandbox (`/app` = the build, `/usr` = the KDE SDK). It copies `/app` (locale links resolved, no
  `lib/debug`), the Qt plugins, QML modules and Qt/KF6 translations of the SDK, writes `qt.conf`, and linuxdeploy
  copies the libraries they need. `AppRun` sets the MLT, frei0r, LADSPA and Qt paths and `PACKAGE_TYPE=appimage`.
  Needs glibc 2.42 (the runtime's) or newer.
- **D-Bus name:** `KDBusService` registers `com.hexoby.catavan.*` (from the organization domain), which differs from
  the app ID `com.hexoby.Catavan` in case. Flatpak only lets an app own names under its app ID, so the manifest has
  `--own-name=com.hexoby.catavan.*`; without it Catavan exited at start ("Failed to register name").
- **Translations in the bundle:** `"separate-locales": false`. flatpak-builder moves `share/locale` into a
  `com.hexoby.Catavan.Locale` extension by default, and `flatpak build-bundle` writes only the app: the installed
  bundle had no Catavan translation at all (only the runtime's, e.g. File/New in pt-BR next to Edit/View in English).
- **Union style (AppImage):** outside Plasma, `KStyleManager` picks the KF6 default widget style, Union, which reads its
  stylesheets from `share/union`. `collect.sh` copies them from the SDK; without them Catavan crashed at start on
  GNOME and other desktops (it worked on Plasma, whose platform theme picks Breeze).
- In both packages, Kdenlive's sandbox detection sets the settings file to `catavan-appimagerc` / `catavan-flatpakrc`
  (upstream: `kdenlive-<package>rc`, shared with the Kdenlive AppImage).
- Interface tests in the Qt `vnc` platform have no OpenGL: playback does not advance, and closing after pressing play
  crashed or hung in the MLT consumer (also with the development build). On the real screen (play and close through
  D-Bus: `org.kde.KMainWindow.activateAction monitor_play`, then `QWidget.close`) both packages closed in about 1 s.
  Judge closing only on a real screen.
- Tested headless: `catavan --version`, a `melt` render with timewarp 1.1 + WSOLA to `h264_nvenc` (duration 4.544 s
  from 5 s), NVDEC decoding, the optional modules in `melt -query`, and an offscreen start of the AppImage with no
  missing QML module or plugin.
- **Windows .zip** (`packaging/windows/build.sh`, MSYS2 UCRT64 shell, after `./build.sh`): copies the install prefix
  (`bin/`, `lib/mlt`, `lib/frei0r-1`, `share/mlt`; executables and MLT modules with `strip --strip-debug`, the
  RelWithDebInfo `catavan.exe` is ~700 MB otherwise), FFmpeg, MediaInfo and `kioworker.exe`, the Qt plugins and QML
  modules of MSYS2 into `lib/plugins` and `lib/qml` (found through `bin/qt.conf`), the KDE data of MSYS2 into
  `bin/data` and `etc/fonts` for fontconfig. Then it walks the imports of every `.exe`/`.dll` (`objdump -p`) and
  copies each DLL found in `$MINGW_PREFIX/bin` until nothing new appears. DLLs loaded at run time are invisible to
  the walk: `libmediainfo-0.dll` is copied by name. `Catavan.cmd` at the top starts `bin\catavan.exe`. Output:
  `packages/Catavan-<version>-windows-x86_64.zip` + `.sha256` (bsdtar).
  - Icon colors (`main.cpp`, patch `branding`): `KIconTheme::initTheme()` runs before the `QApplication` and adds
    `<plugin path>/kiconthemes6` (the KIconEngine, which recolors Breeze icons for the color scheme) only for the
    plugin paths Qt knows at that moment. `bin/qt.conf` is read only once the application exists, so in the package
    Qt's plain SVG engine drew the icons dark on the dark scheme (the development build worked through
    `QT_PLUGIN_PATH` of `catavan.cmd`). On Windows, `main.cpp` adds `<exe dir>/../lib/plugins` (from
    `GetModuleFileNameW`) before `initTheme()`. Checked on screen: `KIconEnginePlugin.dll` loads from the package.
  - Executable icon: `ecm_add_app_icon` needs `icotool` (MSYS2 `icoutils`, in `setup.sh`); without it CMake only
    warns and `catavan.exe` has no icon, so the shortcuts and Installed apps show a blank one.
  - Qt's test QML modules are left out: their build leftovers had 166-character relative paths, and `Expand-Archive`
    failed under the 260-character limit. The longest path is now ~143 characters, fine inside `Downloads`.
  - Tested with `PATH=C:\Windows\system32;C:\Windows`: `melt -query` (opencv.tracker, rnnoise, glaxnimate, wsola,
    frei0r), a timewarp 1.1 + WSOLA render to `h264_nvenc` (4.565 s from 5 s), NVDEC through `-hwaccel cuda`, and
    an offscreen start: all 300 loaded modules come from the package or `C:\Windows`, and every QML import of
    Catavan exists in `lib/qml`. Offscreen it stops at the welcome screen, so the timeline needs a test on screen.
- **Windows installer** (`catavan.nsi`, NSIS 3 from MSYS2, built by the same script from the same folder):
  `…-setup.exe`, LZMA solid (157 MB against 245 MB of the zip, ~720 MB installed). Program Files for all users
  (admin), Start menu and desktop shortcuts, Installed apps entry (`HKLM\…\Uninstall\Catavan`, with
  `QuietUninstallString`), English or Brazilian Portuguese chosen from the Windows language.
  - `.kdenlive`: only `OpenWithProgids` → `Catavan.Project`; the default app (an installed Kdenlive) is kept.
  - Install and uninstall remove `bin`, `lib`, `share`, `etc`, `translations` by name (no stale DLLs after an update,
    nothing else in the folder touched). For that to be safe the directory page always appends `\Catavan` to the
    chosen folder (`EnsureOwnFolder`); a silent install with `/D=` skips that page, so the folder given must be one of
    its own.
  - An open Catavan blocks the install (retry/cancel), checked by opening `catavan.exe` for writing.
  - Uninstalling keeps `%LOCALAPPDATA%\catavanrc` and the user data.
  - Tested: `/S /D=<folder>` install (files, registry, shortcuts, "Open with", modules from the installed folder) and
    `uninstall.exe /S` (everything removed, settings kept). The interactive pages were not tried by me.
  - Not signed: SmartScreen shows "unknown publisher" until it is signed (README tells how to proceed).

## Decisions

- **Versions:** Kdenlive 26.08.2 (KDE Gear, sha256 checked against KDE's) and MLT 7.42.0. Kdenlive needs
  Qt ≥ 6.10, KF ≥ 6.21, KDDockWidgets ≥ 2.4 — Ubuntu 26.04 has them in apt.
- **Distributions:** Debian/Ubuntu with an explicit package list (tested on Ubuntu 26.04); Fedora/openSUSE through
  builddep of `mlt`+`kdenlive`; Arch through the dependencies of the `kdenlive` package. Only Ubuntu was tried.
- **Windows:** MSYS2, UCRT64 environment (MinGW GCC), detected through `MSYSTEM`. MSYS2 packages Kdenlive and MLT with
  the same versions, so every dependency comes from pacman (`MSYS2_PKGS` in `setup.sh`). KDE Craft (MSVC) was not used:
  it builds Qt and KF6 from source. Differences in `build.sh` when `MSYSTEM` is set:
  - MLT with `WINDOWS_DEPLOY=OFF` (bin/ + `lib/mlt` + `share/mlt`; MLT finds them relative to the executable, the
    `MLT_*` variables of `env.sh` are not used) and `MOD_MOVIT=OFF` (no movit package).
  - Kdenlive with `BUILD_RUN_QMLLINT=OFF`: the qmllint of Qt 6.12 rejects upstream QML (`confusing-expression-statement`
    in `ClipThumbs.qml`).
  - KDE data installs to `bin/data` (ECM on Windows), where Qt looks next to the executable. `env.sh` only sets `PATH`,
    `QT_PLUGIN_PATH` and `QML_IMPORT_PATH` (Windows paths separated by `;`); `catavan.cmd` does the same for a double
    click.
  - frei0r: on Windows MLT only looks for the plugins in `lib/frei0r-1` next to the executable (no `FREI0R_PATH`), so
    `build.sh mlt` copies the MSYS2 plugins there (7.7 MB; a junction would be followed by `--clean`).
  - Starting Catavan from a hidden console (`Start-Process -WindowStyle Hidden`) hides its first window too.
- **MLT modules off:** xine, ndi (proprietary SDK) and, on Windows, movit (no MSYS2 package). Glaxnimate, OpenCV and
  RNNoise are on with `EXTRA_MODULES=1` (the default; see "Structure").

## Testing

- In a locale with a decimal comma (pt-BR), `melt timewarp:1.1:file` reads the speed as 1. Use `LC_ALL=C` with melt
  on the command line.
- Kdenlive tests (with the Catavan ones) build separately in `~/.cache/catavan-build/build/kdenlive-tests`
  (BUILD_TESTING=ON); run them with `QT_QPA_PLATFORM=offscreen ./bin/vegasrippletest` (and `vegascrossfadetest`,
  `vegasgrouptest`, `vegasselectiontest`). On Windows MLT looks for its modules next to the executable (`../lib/mlt`): copy the test
  executable to `install/bin` and run it there, otherwise it crashes at start.
- Whole suite: `QT_QPA_PLATFORM=offscreen ctest` in the tests build. Run it with an empty `XDG_CONFIG_HOME`: the tests
  read `~/.config/kdenliverc` of an installed Kdenlive (`mix_duration=30` made `mixtest` and `replacetest` fail at
  their first check). With the Catavan defaults, 2 upstream tests fail on purpose (checked on 2026-10-26, 36 of 38
  pass): `modeltest` (see `group-tracks`) and `mixtest`, where resizing a grouped clip next to a mix is refused
  upstream and pushes the group with `groupTrimPush` (it passes with the option off). The SIGSEGV that follows in
  `mixtest` comes from the test itself: a failed section leaves its document open and the next run destroys the
  timeline after the document.
- Interface without a screen: Qt has a `vnc` platform plugin (`catavan -platform vnc:size=1920x1080:port=5977`); a
  minimal RFB client in Python (RFB 3.3, no password) can click, type and capture the screen. Close the instance at
  the end: a forgotten instance keeps the port and later captures show it.

### WSOLA CLI

```bash
./build.sh cli
~/.cache/catavan-build/install/bin/wsola-cli voice.wav            # writes voice.1.1x.wav and voice.2x.wav
~/.cache/catavan-build/install/bin/wsola-cli voice.wav 0.5 1.5     # other speeds
```

To compare, open `tools/wsola-cli/compare.html` in Chrome and choose the original and the output. Checked with
synthetic signals: exact durations (N/rate), 440 Hz pitch kept at 1.1x and 2x, no gaps or clipping.
