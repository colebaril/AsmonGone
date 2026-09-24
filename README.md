# AsmonGone

**A lightweight World of Warcraft chat filter for when you've heard enough about Asmongold.**

You're questing. You're vibing. You open General Chat.

**ASMON. OLYMPUS. ASMON. OLYMPUS. ASMON.**

Not anymore.

**AsmonGone** automatically hides public chat messages containing Asmongold-related keywords — plus anything else you'd rather never hear about again.

> **The timeline is healing.**

---

## Features

- Automatically filters messages containing **Asmon**, **Asmongold**, **OLYMPUS**, and related terms
- Add your own custom blocked keywords or phrases
- Remove blocked keywords whenever you want
- Case-insensitive filtering
- Custom filters persist between sessions
- Enable or disable filtering without uninstalling the addon
- Track how many messages AsmonGone has mercifully removed from your chat
- Test messages against your filter without actually sending them
- Leaves private/social channels such as Party, Guild, Raid, and Whispers alone
- Lightweight
- No external libraries
- No dependencies
- No Asmon

---

## Installation

### Manual Installation

1. Download the latest `AsmonGone.zip` release.
2. Extract the ZIP.
3. Place the **AsmonGone** folder into your WoW AddOns directory.

For WoW Classic Era, this will typically be:

```text
World of Warcraft/
└── _classic_era_/
    └── Interface/
        └── AddOns/
            └── AsmonGone/
                ├── AsmonGone.toc
                └── AsmonGone.lua
```

4. Launch or restart World of Warcraft.
5. Make sure **AsmonGone** is enabled under **AddOns** on the character-selection screen.
6. Enter Azeroth.
7. Experience peace.

---

## Commands

AsmonGone uses either `/ag` or `/asmongone`.

### Add a keyword
```text
/ag add <keyword>
```

### Remove a keyword
```text
/ag remove <keyword>
```

### View your blacklist
```text
/ag list
```

### Test a message
```text
/ag test <message>
```

Example:
```text
/ag test Anyone watching ASMON?
```

### View statistics
```text
/ag stats
```

### Disable filtering
```text
/ag off
```

### Enable filtering
```text
/ag on
```

### Restore the default blacklist
```text
/ag defaults
```

### Help
```text
/ag help
```

---

## How Filtering Works

Matching is **case-insensitive**. `asmon`, `Asmon`, `ASMON`, and `aSmOn` are treated identically.

The filter also supports longer keywords and phrases. AsmonGone focuses on public chat channels so normal communication with friends, guildmates, party members, and raid members isn't unnecessarily hidden.

Your custom blacklist is saved between sessions using WoW's SavedVariables system.

---

## Default Filters

AsmonGone ships with a small set of Asmongold/Olympus-related terms, including:

```text
asmon
asmongold
olympus
olympuswow
olympus wow
```

The default list is intentionally kept relatively small to reduce accidental filtering of unrelated conversations.

Add whatever else you want with:

```text
/ag add <keyword>
```

AsmonGone does not judge your blacklist.

---

## Issues & Suggestions

Found a bug? Have an idea? Did Asmon somehow breach containment?

Open an **Issue** on this GitHub repository with:

- What happened
- What you expected to happen
- Your WoW version
- Any Lua error you received
- Steps to reproduce the problem, if possible

Feature suggestions are welcome too.

---

## Contributing

Pull requests are welcome.

If you want to improve filtering, compatibility, commands, or other features, feel free to fork the project and submit a PR.

Please keep the addon lightweight and focused on chat filtering.

---

## Disclaimer

**AsmonGone is an unofficial community addon.**

It is not affiliated with, endorsed by, or associated with Blizzard Entertainment, World of Warcraft, Asmongold, OTK, OLYMPUS, or their respective owners.

AsmonGone filters messages **locally on your own client**. It does not prevent other players from sending messages and does not modify what other players see.

World of Warcraft and related names are trademarks of Blizzard Entertainment.

---

## License

AsmonGone is released under the **MIT License**.

See `LICENSE` for details.

---

## AsmonGone

**Less streamer discourse. More boars.**

The timeline is healing.
