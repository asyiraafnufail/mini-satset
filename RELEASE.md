# mini-satset v1.1.0 (5-Page Production Suite + Pin Mode)

> Ultra-lightweight native macOS menu bar utility built for speed, portability, and zero-overhead workflow.
> Zero external dependencies • 0.0% idle CPU • Resident RAM < 12 MB • Pure Swift & AppKit

---

### What's New in v1.1.0

#### 1. Pin Mode (Always on Top)
- Dedicated header toggle button (`pin` / `pin.fill`) to lock the panel open while multitasking, dragging files across workspaces, or taking notes.
- Completely shuts down hover polling timers while pinned (**0.0% CPU impact**).
- Restores smooth auto-dismiss behavior instantly upon unpinning.

#### 2. Page 4: QR Code Lab (Two-Way Generator & Scanner)
- **Live Vector QR Generation**: High-contrast, sharp QR code synthesis in real-time as you type or paste URL/text (`CIQRCodeGenerator`), padded with clean quiet zone margins.
- **Direct Drag & Copy**: Copy QR image or raw text directly to clipboard, or drag the QR image directly from the card into Finder or other apps.
- **Image Drop Scanner**: Drop any image containing a QR code to decode instantly via CoreImage `CIDetector` and copy extracted text to clipboard.

#### 3. Page 5: Screen OCR & Text Grabber (100% On-Device Neural Engine)
- **Interactive Screen Area Snipping**: Snip any rectangular area of your screen using native `/usr/sbin/screencapture`.
- **Apple Vision Framework**: Real-time on-device text recognition with language correction (`VNRecognizeTextRequest`), running entirely offline via the Apple Neural Engine.
- **Screenshot Drag & Drop**: Drop any image or screenshot file into the drop zone to extract selectable, scrollable text instantly.
- **100% Offline & Private**: Zero network calls, zero cloud telemetry, instant clipboard copy.

#### 4. Engine & Memory Optimizations
- **Scoped Autoreleasepool Execution**: Wrapped heavy ImageIO, CoreGraphics, CoreImage, and Apple Vision operations in localized `autoreleasepool` blocks to release memory immediately upon task completion.
- **Zero Idle CPU**: Complete elimination of continuous timers; all toast resets and hover monitors are invalidatable and stop when idle or pinned.
- **Lazy Drag Export**: QR image PNGs are only written to disk if an actual drag gesture to Finder is initiated.

#### 5. Native 1-Click Complete Uninstaller
- Right-click the menu bar icon and select **Uninstall mini-satset...** to cleanly unregister login items (`SMAppService`), purge preference plists and caches, move the `.app` bundle to Trash (`FileManager.default.trashItem`), and quit cleanly with zero residual files on your Mac.

---

### Core Suite (All 5 Pages)
1. **Shelf**: File staging zone (up to 4 files) + text snippets with lazy 5-minute auto-destruct.
2. **Converter**: Hardware-accelerated image & CoreAudio transcoding with 1:1 pixel protection.
3. **Color Sampler**: Precision screen loupe with HEX, RGB, HSL conversion and recent swatches.
4. **QR Code Lab**: Two-way QR generator and image drop scanner with drag-to-export.
5. **Screen OCR**: Interactive rectangle screen capture + on-device Apple Neural Engine text recognition.

---

### Performance Benchmarks
- **Idle CPU**: `0.0%`
- **Resident RAM**: `< 12 MB`
- **Binary Architecture**: Universal 2 (`arm64` Apple Silicon + `x86_64` Intel)
- **External Dependencies**: `0`

---

### Installation

1. Download **`mini-satset-1.1.0.dmg`** below.
2. Open the DMG and drag **mini-satset** into your **Applications** folder.
3. **First Launch Note**: Right-click (or Control-click) `mini-satset` in Applications → choose **Open** → click **Open** to approve self-signed ad-hoc binary on macOS Ventura, Sonoma, or Sequoia.

---

### Verification (SHA-256)
```text
dist/mini-satset-1.1.0.dmg
```
