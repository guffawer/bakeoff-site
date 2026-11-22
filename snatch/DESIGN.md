# Snatch Block design lock

Status: look approved on 22 Nov 2026. The game is not built and no build is approved.

Reference: [Look B, Red Earth](https://guffawer.github.io/bakeoff-site/looks/snatch/b/)

| Element | Locked value |
|---|---|
| Feel | Gritty recovery site at warm dusk; tense |
| Sky | #AB9E9D upper, #E1B782 horizon (replaces #C9D3D6) |
| Wet mud | #4F2215 (replaces #3A2B1C), red laterite banks |
| Machines | #E9A800, worn, no brand marks, plates or stencils |
| Rope | #E8601C, 4.5 px, three layers: dark edging shadow, base, scrolling lay; up to 12 segments |
| Limit | #E5322D for the bar and border; warning text is white on #B3201C |
| Text | #FFFFFF on #100E0C panels at 84% |
| Action colour | Dark #16120C text on #E9A800 |
| Fonts | Barlow Condensed 700 (18-22 px), Barlow 500/700 (12-14 px) |
| Layout | Gauge on top; Block, Slack and Winch buttons at 56 px, above the bottom 25% and left of the right 72 px; 10 px radii |
| Effects | Snap whip 0.4 s, up to 24 mud particles, no runtime blur or light shadows |
| Sound | Diesel rumble, creak rising with tension, snap crack, mud hit |
| Clip Mode | No UI; CC-BY model credit goes in the video description |

## Rigging rules the build must respect

1. Show the rig ratio and the effective advantage. A 2:1 rig gives 2:1 only with parallel legs; at the 78 degree angle in the look it gives 1.56:1.
2. The strop follows the resultant of the two rope legs.
3. The block and strop carry up to twice the line tension, so rate them separately from the rope.
4. A working load limit is not a breaking strength. The brief snaps the rope just above the limit, so label that threshold "Limit" and never "WLL".

## To resolve when a build is approved

1. Test rope readability on a budget Android at half brightness, as orange on red earth is the known weakness of this look.
2. Prove 60 fps in the Godot single-threaded web export with 3 machines and 4 ropes.
3. Get legal clearance on machine liveries and model provenance before any store release.
