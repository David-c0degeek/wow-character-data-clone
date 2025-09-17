### `README.md`

# WoW Character Data Clone (`charclone.ps1`)

Easily clone **World of Warcraft** character settings (Classic Era / Classic / Retail) from one toon to another.  
Copies per-character UI layout, keybinds, macros, chat settings, addon SavedVariables, and more — with optional backups and account-wide sync.

> ✅ Supports **interactive account/realm/character pickers**  
> ✅ Works across multiple WoW licenses (#1, #2, …)  
> ✅ Optional backup of the target before cloning  
> ✅ Auto-detects `_classic_era_`, `_classic_`, or `_retail_` branches  

---

## Usage

1. Clone this repo:
   ```powershell
   git clone https://github.com/David-c0degeek/wow-character-data-clone.git
   cd wow-character-data-clone
   ````

2. Run the script in PowerShell:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\charclone.ps1
   ```

3. Follow the interactive prompts to pick:

   * Source **Account → Realm → Character**
   * Target **Account → Realm → Character** (or create new)

---

## Options

| Parameter              | Description                                                                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `-WowRoot`             | Path to WoW installation. Default: `C:\Program Files (x86)\World of Warcraft`                                                             |
| `-BackupTarget`        | Create a timestamped ZIP backup of the target character before cloning.                                                                   |
| `-AlsoCopyAccountWide` | Clone account-wide settings too (`bindings-cache.wtf`, `macros-cache.txt`, global SavedVariables). **Affects all toons on that account!** |
| `-DryRun`              | Show what would be done without copying anything.                                                                                         |
| `-VerboseAccounts`     | Print full account/realm/character tree before picking.                                                                                   |

---

## Example

Clone settings from Mage on Account #1 → Priest on Account #2, with backup:

```powershell
.\charclone.ps1 -BackupTarget
```

Dry-run to preview actions:

```powershell
.\charclone.ps1 -DryRun -VerboseAccounts
```

---

## Notes

* Source and target must exist under `WTF\Account\<Account>\<Realm>\<Character>`.
* WoW only creates character folders after logging into the toon **at least once**.
* Works with Classic Era, Classic Hardcore/SoD, and Retail automatically.

---

## Author

* **David** — [C0deGeek.dev](mailto:David@C0deGeek.dev)
* Script: [`charclone.ps1`](./charclone.ps1)

## Credits

* Script and documentation support by **ChatGPT (OpenAI)** 💙

---

## License

This project is licensed under the [MIT License](./LICENSE).

````

---

### `LICENSE`
```text
MIT License

Copyright (c) 2025 David (C0deGeek.dev)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
````
