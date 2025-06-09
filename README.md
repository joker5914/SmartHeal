# SmartHeal 🔮

**SmartHeal** is a lightweight healing addon for [TurtleWoW](https://turtle-wow.org/) that automatically targets the **lowest HP friendly player** in your party or raid and casts a healing spell of your choice.

---

## ⚙️ Features

- ✅ Auto-targets the lowest HP friendly (yourself, party, or raid)
- 🔄 Supports any healing spell — configurable via chat
- ❌ Skips dead or disconnected players
- 🐢 100% TurtleWoW-compatible (1.12.1)
- 💬 Slash command and macro-friendly

---

## 📦 Installation (via TurtleWoW Launcher)

1. Open the **TurtleWoW Launcher**.
2. Click the **AddOns** tab.
3. Click **“Install from GitHub”**.
4. Paste this repo URL:
   ```
   https://github.com/joker5914/SmartHeal
   ```
5. Start the game and enable `SmartHeal` in the AddOns list.

---

## 🕹️ How to Use SmartHeal In-Game

### 🧠 What it does:
- Scans your raid or party (includes self)
- Finds the **lowest-health friendly player**
- Targets that player
- Casts the healing spell you've chosen

### 🔘 Set a Spell and Heal

Use this command in chat:
```
/smartheal Spell Name(Rank X)
```

Example:
```
/smartheal Flash Heal(Rank 2)
/smartheal Greater Heal(Rank 1)
/smartheal Heal(Rank 4)
```

This will:
- Set the healing spell
- Target the lowest HP friendly unit
- Cast that spell

Once set, you can just use:
```
/smartheal
```
To cast the last spell again on the lowest HP unit.

### 🛠 Create a Macro

Add this to a macro for your action bar:

#### Macro Example – Set and Cast
```
#showtooltip
/smartheal Flash Heal(Rank 2)
```

#### Macro Example – Use last-used spell
```
#showtooltip
/smartheal
```

---

## 💬 Slash Command Summary

| Command | Description |
|---------|-------------|
| `/smartheal` | Casts current saved spell on lowest-HP target |
| `/smartheal [Spell(Rank X)]` | Sets a new spell and casts it |

---

## 🚧 Planned Features

- [ ] Don’t change current target after casting
- [ ] Mouseover healing support
- [ ] HP threshold to avoid wasting heals
- [ ] Save chosen spell between sessions

---

## 🔒 License

MIT — free to use, modify, or share. No credit needed.
