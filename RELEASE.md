# mini-satset v1.0.0 (Initial Release)

> Ultra-lightweight native macOS menu bar utility built for speed, portability, and zero-overhead workflow.

---

### What's New in v1.0.0

#### 1. Temporary Shelf (Files & Clipboard)
- Staging zone for up to 4 temporary files with automatic symmetrical grid layout.
- Full two-way drag-and-drop integration directly with macOS Finder and external apps.
- Store up to 4 quick text snippets with instant copy (`Cmd+C`), paste (`Cmd+V`), and add.
- Lazy 5-minute auto-destruct (zero running countdown timers, 0.0% idle CPU).

#### 2. Native Quick File Converter
- Convert images (**PNG, JPG, HEIC, WEBP, TIFF**) via hardware-accelerated `ImageIO`.
- Strict 1:1 original pixel dimension protection (upscaling prohibited).
- Compression & quality presets (*High, Medium, Compressed*).
- Convert audio (**WAV, MP3, M4A, CAF**) via native CoreAudio (`/usr/bin/afconvert`).
- Single-slot temporary output shelf draggable directly to Finder, locked until cleared.

#### 3. Screen Color Sampler
- Native precision screen loupe via `NSColorSampler`.
- Auto-copies standard **HEX** to clipboard on pick.
- Displays simultaneous **HEX**, **RGB**, and **HSL** values with one-click copy buttons.
- Recent 5 swatches history with auto-dismiss guard during active sampling.

#### 4. Menu Bar & System Integration
- Permanent 68pt standby status item (`bolt.fill` + `satset`).
- Instant hover expansion and active zone boundary tracking.
- Spring-loaded drag expansion preserving current active page tab.
- Native `SMAppService` **Launch at Login** toggle in right-click context menu.
- Pure frame-based manual layout (zero Autolayout constraint solver overhead).

---

### Performance Benchmarks
- **Idle CPU**: `0.0%`
- **Resident RAM**: `< 12 MB`
- **Binary Architecture**: Universal 2 (`arm64` Apple Silicon + `x86_64` Intel)
- **External Dependencies**: `0`

---

### Installation

1. Download **`mini-satset-1.0.0.dmg`** below.
2. Open the DMG and drag **mini-satset** into your **Applications** folder.
3. **First Launch Note**: Right-click (or Control-click) `mini-satset` in Applications → choose **Open** → click **Open** to approve self-signed ad-hoc binary on macOS Ventura, Sonoma, or Sequoia.

---

### Verification (SHA-256)
```text
dist/mini-satset-1.0.0.dmg
```
