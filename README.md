# SmartHeal 🔮

**SmartHeal** is a lightweight healing addon for [TurtleWoW](https://turtle-wow.org/) that automatically targets the **lowest HP friendly player** in your party or raid and casts a healing spell — with an optional **Renew** toggle.

---

## ⚙️ Features

- ✅ Auto-targets the lowest HP friendly unit (self, party, raid)
- ✅ Skips dead or disconnected units
- ✅ Optional **Renew(Rank 1)** toggle in the UI
- ✅ Healing spell is hardcoded (default: `Flash Heal(Rank 2)`)
- ✅ Simple, draggable in-game config window
- ✅ Close button on UI window
- ✅ 100% TurtleWoW-compatible (1.12.1)

---

## 🧱 Installation (via TurtleWoW Launcher)

1. Open the **TurtleWoW Launcher**
2. Go to the **AddOns** tab
3. Click **“Install from GitHub”**
4. Paste this repo URL:

   ```
   https://github.com/joker5914/SmartHeal
   ```

5. Start the game and enable `SmartHeal` in the AddOns list

---

## 🕹️ How to Use SmartHeal In-Game

### Basic Usage
Cast the current spell (defaults to `Flash Heal(Rank 2)`) on the lowest-HP friendly player:
```
/smartheal
```

### Toggle Renew Option
Open the in-game UI to toggle Renew logic:
```
/smartheal ui
```

In the window:
- ✅ Check "Use Renew(Rank 1) if not active" to apply Renew before your main heal
- ❌ Uncheck to skip Renew entirely

---

## 🔁 Macro Example

```
#showtooltip
/smartheal
```

Use this macro to cast heals on the lowest HP friendly without switching spells manually.

---

## 📜 Slash Command Summary

| Command         | Description                                         |
|------------------|-----------------------------------------------------|
| `/smartheal`     | Heals the lowest HP friendly with your chosen spell |
| `/smartheal ui`  | Opens the settings window to toggle Renew           |

---

## 🚧 Known Limitations / Future Plans

- [ ] Save Renew toggle between sessions
- [ ] Change primary heal spell in UI
- [ ] Allow fallback to player if no one is missing health
- [ ] Add support for mouseover healing

---

## 🔒 License

MIT — free to use, modify, or share. Credit optional but appreciated.
