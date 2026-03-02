# LangOver

**Convert text typed in the wrong keyboard layout — Hebrew ↔ English.**

A tiny, portable Windows app (single `.exe`, no dependencies) that converts selected text between Hebrew and English keyboard layouts. Also available as **MSIX** for Microsoft Store and sideloading.

**Example:** `asdf` → `שדגכ` &nbsp;|&nbsp; `שדגכ` → `asdf`

---

## Download

| Format | x64 | x86 |
|--------|-----|-----|
| **Microsoft Store** | [![Get it from Microsoft](https://img.shields.io/badge/Microsoft%20Store-Install-blue?logo=microsoft)](https://apps.microsoft.com/detail/9NBLGHHP9JLQ) | |
| **Standalone EXE** (no install) | [`langover-x64.exe`](../../releases/latest) | [`langover-x86.exe`](../../releases/latest) |
| **MSIX** (Store / sideload) | [`langover-x64.msix`](../../releases/latest) | [`langover-x86.msix`](../../releases/latest) |

> All release binaries are signed with [Sigstore](https://www.sigstore.dev/) and include [GitHub artifact attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations).
> SignPath.io code signing is pending approval.

## Usage

1. **Run** `langover.exe` — it sits quietly in your system tray
2. **Select** the text that was typed in the wrong layout
3. **Middle-click** (press the mouse wheel) — the text is converted instantly

That's it. No installation, no setup, no admin rights needed.

### How the middle-click works

LangOver is careful **not to interfere** with normal middle-click behavior:

| Scenario | What happens |
|----------|-------------|
| Text is selected + quick middle-click | ✅ Text is converted |
| No text selected + middle-click | ↪ Normal behavior (paste in terminal, auto-scroll, etc.) |
| Middle-click + drag | ↪ Normal behavior (auto-scroll) |
| Middle-click held > 400ms | ↪ Normal behavior (auto-scroll) |

### Auto-start with Windows (optional)

1. Press `Win+R`, type `shell:startup`, press Enter
2. Create a shortcut to `langover.exe` in the folder that opens

### Exit

Right-click the tray icon → **Exit**

---

## Building from Source

### Requirements
- CMake 3.15+
- MSVC (Visual Studio 2019+) **or** MinGW-w64

### Build

```bash
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

The output is `build/Release/langover.exe` — a single, self-contained executable with no runtime dependencies.

---

## Project Structure

```
├── src/
│   ├── langover.c              # Main source (Win32 C)
│   ├── langover.rc             # Resources (icon, version info)
│   ├── langover.exe.manifest   # App manifest (DPI, UAC, compat)
│   ├── langover.ico            # Application icon
│   └── resource.h              # Resource IDs
├── msix/
│   ├── AppxManifest.xml        # MSIX package manifest (Desktop Bridge)
│   └── Assets/                 # Store tile logos (various sizes)
├── store/
│   ├── screenshots/            # Store screenshots (1920×1080)
│   ├── en-us/                  # English store listing text
│   ├── he/                     # Hebrew store listing text
│   └── listing.json            # Store submission metadata
├── autohotkey/                 # Alternative lightweight AHK version
│   ├── langover.ahk
│   └── README.md
├── scripts/
│   └── generate-store-assets.ps1  # Regenerate logos & screenshots
├── docs/                       # GitHub Pages site (Hebrew)
├── .github/workflows/build.yml # CI: build EXE+MSIX, sign, release
├── .signpath/                  # SignPath code signing config
├── CMakeLists.txt              # Build system
├── LICENSE                     # MIT License
└── SECURITY.md                 # Security policy
```

## How It Works

1. A **low-level mouse hook** detects middle-click events
2. On a quick middle-click, the app copies the selected text via `Ctrl+C`
3. Each character is mapped to its counterpart based on the physical keyboard position
4. The converted text replaces the selection via `Ctrl+V`
5. The original clipboard content is preserved throughout

The app auto-detects the text direction: if Hebrew characters are found, it converts to English; otherwise, it converts to Hebrew.

## License

[MIT](LICENSE)

## Verification

Every release binary can be independently verified:

### Sigstore (cosign)

```bash
# Install cosign: https://docs.sigstore.dev/cosign/system_config/installation/
cosign verify-blob \
  --signature langover-x64.exe.sig \
  --certificate langover-x64.exe.pem \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp "github.com/nachlib/LangOver" \
  langover-x64.exe
```

### GitHub CLI attestation

```bash
gh attestation verify langover-x64.exe -o nachlib
```

### SHA256 checksums

Each release includes `.sha256` files for manual hash verification.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
