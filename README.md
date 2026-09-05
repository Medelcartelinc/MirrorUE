# OmniMirror — Ultra-Low-Latency 120 FPS iPhone Mirroring & Control for macOS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B%20(Intel%20%26%20Apple%20Silicon)-black.svg)](#requisiti)
[![iOS](https://img.shields.io/badge/iOS-16%2B-lightgrey.svg)](#requisiti)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](Package.swift)

Applicazione nativa macOS ad altissime prestazioni sviluppata da **Medelcartel** per visualizzare e controllare iPhone fisici con rendering **Metal zero-copy a 120 FPS**, latenza istantanea su cavo USB (<5 ms), supporto completo a gesture capacitivi (mouse/trackpad), mappatura tastiera fisica e automazione locale.

```text
Cavo USB    → CoreMediaIO (iPhone screen DAL) → Metal (IOSurface zero-copy, <5ms)
Wi-Fi / Net → CoreDevice tunnel → UniversalHID (Touch · Gesti · Pulsanti hardware)
```

---

## ✨ Funzionalità Principali

| Categoria | Funzionalità |
| :--- | :--- |
| **Video a 120 FPS** | Flusso video diretto tramite CoreMediaIO DAL e pipeline Metal GPU con IOSurface zero-copy a latenza ultra-bassa (0–5 ms su cavo USB). |
| **Touch & Gesti** | Clic, trascina, scorri con rotella e supporto completo alla rotazione orizzontale/verticale in tempo reale. |
| **Screenshot Istantaneo** | Premi **`⌘S`** per salvare uno screenshot PNG ad altissima risoluzione sulla Scrivania e **copiarlo contemporaneamente negli appunti** del Mac. |
| **Ingrandimento Schermo** | Ridimensiona liberamente la finestra o premi **`⌘0`** per espandere il display iPhone a tutto schermo mantenendo le proporzioni corrette. |
| **Sempre in Primo Piano** | Modalità fluttuante (**`⌘T`**) per mantenere OmniMirror sopra a tutte le altre finestre durante il lavoro. |
| **Cornice Personalizzabile** | Nascondi o mostra la cornice del telefono (**`⌘⇧B`**) per una visualizzazione borderless minimale. |
| **Dock Multifunzione** | Accesso rapido a Home, Blocco Schermo, App Switcher, Centro di Controllo, Screenshot, Registrazione video e Mute. |
| **Tastiera Intelligente** | Traduzione automatica dei tasti del Mac nella tastiera dell'iPhone. |
| **Automazione & AI** | Supporto per workflow locali e integrazione LLM/OCR per test QA automatici. |

---

## ⌨️ Scorciatoie da Tastiera

| Scorciatoia | Azione |
| :--- | :--- |
| **`⌘S`** | Scatta Screenshot (Salva su Scrivania + Copia negli Appunti) |
| **`⌘⇧R`** | Avvia / Interrompi Registrazione Video (.mov) |
| **`⌘T`** | Attiva / Disattiva "Sempre in primo piano" (Floating Window) |
| **`⌘⇧B`** | Mostra / Nascondi la cornice del telefono |
| **`⌘0`** | Adatta e massimizza la finestra allo schermo (Fit Screen) |
| **`⌘1`** / **`⌘2`** | Dimensioni standard (100% / 150%) |
| **`⌃⌘F`** | Attiva / Disattiva schermo intero (Full Screen) |
| **`⌘⇧V`** | Incolla testo dagli appunti del Mac sull'iPhone |
| **`⌘P`** | Visualizza pannello prestazioni (FPS / Latenza real-time) |
| **`⌘,`** | Apri le Impostazioni (FPS target, orientamento, layout tastiera) |

---

## 📋 Requisiti

* **Mac**: macOS Sonoma 14.0 o superiore (supporto nativo sia per **Intel x86_64** che per **Apple Silicon ARM64**).
* **iPhone**: iOS 16.0 o superiore, collegato via cavo USB e sbloccato.
* **Modalità Sviluppatore**: Attivata su iPhone (*Impostazioni > Privacy e sicurezza > Modalità sviluppatore*).

---

## 🚀 Installazione Rapida

### 1. Installazione in 1 Clic (Consigliata)

Esegui il comando di installazione dal terminale:

```bash
./install.sh
```

Questo script:
1. Compila i binari nativi ottimizzati per la tua architettura (Intel o Apple Silicon).
2. Firma il bundle con la firma digitale locale verificata.
3. Installa l'applicazione in `/Applications/OmniMirror.app`.
4. Crea i comandi rapidi da riga di comando `omnimirror`.

### 2. Creazione del pacchetto DMG di distribuzione

Per creare un'immagine disco `.dmg` pronta per la condivisione:

```bash
./scripts/build_dmg.sh
```

Il file verrà generato in `dist/OmniMirror-1.0.0-Intel.dmg`.

---

## 📱 Come Utilizzare OmniMirror

1. **Collega l'iPhone al Mac** con un cavo USB e tocca "Autorizza questo computer" se richiesto.
2. **Apri OmniMirror**:
   * Da **Spotlight**: premi `⌘ + Spazio`, scrivi `OmniMirror` e premi Invio.
   * Da **Finder**: apri `/Applications/OmniMirror.app`.
   * Da **Terminale**: digita `omnimirror`.
3. Seleziona il tuo iPhone dalla lista dei dispositivi disponibili.
4. Lo schermo dell'iPhone apparirà immediatamente a 120 FPS con latenza ultra-bassa!

---

## 🛠️ Architettura Tecnica

```text
Sources/
  MirrorUEApp/     Interfaccia AppKit nativa, rendering Metal GPU, gestione finestra e Dock
  MediaKit/        Modulo CoreMediaIO DAL, acquisizione video e buffer ring IOSurface
  DeviceKit/       Rilevamento dispositivi via usbmux e tunnel CoreDevice
  ControlKit/      Iniezione input HID, mappatura coordinate touch e tastiera

tools/
  mirrorue_engine.py   Demone di bridging CoreDevice e tunnel UniversalHID
```

---

## 📄 Licenza

Distribuito sotto licenza MIT. Sviluppato e ottimizzato da **Medelcartel**.
