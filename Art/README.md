# Pet artwork

## Source

`sloth-sprite-source.png` is the sheet the five moods were cut from: a 1536×1024
PNG holding five pixel-art sloths, three above two, already on a transparent
background.

**Provenance: generated with an AI image tool**, supplied by the project owner
on 2026-09-07. This closes PRD §11 row 9.

For personal use there is nothing to clear. Before the app is ever distributed,
check the terms of the tool that produced it, since some grant fewer rights for
commercial redistribution than for personal use. Tracked as the legal row of
PRD §10.

## How the moods were cut

The sheet already carried an alpha channel, so no background removal was needed.
The five sprites were found by their alpha coverage, cropped to their bounding
boxes, and drawn onto one shared 534×504 canvas, centred horizontally and
aligned on a common baseline. Sharing a canvas keeps the body the same size in
every mood, and sharing a baseline keeps a sitting animal's feet from moving
when its expression changes.

Regenerating them is a matter of re-running that slice against this file; the
step is described in the archived change `add-pet-mood-and-reminders`.

## Mood mapping

| Mood | Drawing |
|---|---|
| Happy | Sitting, smiling |
| Neutral | Dozing, with `zzz` |
| Celebrating | Arms up, sparkles |
| Sad | Downcast, with a tear |
| Worried | Arms folded, cross above |

The two negative moods escalate: arms folded for one or two overdue tasks, the
tear for three or more.
