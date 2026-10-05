# Forever Roles

Mark players as **tank**, **healer** or **DPS** in **WoW Forever**, and see their role icon above target frames, on nameplates, on party and raid frames, and in tooltips.

## Features

- **Right-click any player** → **Mark as** → Tank, Healer or DPS. Also **No icon**, to hide a player's icon, and **Use group role**, to go back to the role the group assigned.
- **Auto-marks from group roles.** Players get the icon for the role the Group Finder or a role check gave them. Tanks, healers and DPS each have their own on/off switch, and your own marks always win.
- **Shared with your group.** Groupmates who also run Forever Roles see your marks and you see theirs, through the hidden addon channel, so nothing appears in chat.
- **Shows where you look:**
  - above the target and focus portraits
  - next to names on nameplates
  - on party and raid frames
  - as a line in the tooltip

  Each one can be turned off.
- Uses Forever's own round role icons.

## Install

Copy the `ForeverRoles` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`, or clone this repository there, then restart the game.

## Commands

| Command | |
|---|---|
| `/froles` | open the settings |
| `/froles mark tank\|healer\|dps\|none\|clear` | mark your current target |
| `/froles list` | show your group's roles |
| `/froles clear` | remove all your marks |
| `/froles sync` | re-send your marks and ask the group for theirs |

Settings are also under **Options → AddOns → Forever Roles**.

## Notes

- Only players running Forever Roles see the marks; they are not the game's built-in raid markers.
- Inside dungeons, friendly players' nameplates are off-limits to addons, so the nameplate icon doesn't show there. Party and raid frames, target, focus and tooltips still work.
- The game may hold back addon messages during combat and boss fights, so new marks reach groupmates between pulls.
