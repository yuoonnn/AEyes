# DFD Level 1 - AEyes System Decomposition

## Overview
This diagram decomposes the AEyes system into major processes, showing data flows between processes, external entities, and data stores.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│                              AEyes System (Level 1)                                │
│                                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  1.0         │    │  2.0         │    │  3.0         │    │  4.0         │   │
│  │ Authenticate │    │ Manage       │    │ Process      │    │ Process      │   │
│  │ & Register   │    │ Device       │    │ Images       │    │ Voice        │   │
│  │ Users        │    │ Connection   │    │ & AI         │    │ Commands     │   │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘   │
│         │                   │                   │                   │            │
│  ┌──────▼───────┐    ┌──────▼───────┐    ┌──────▼───────┐    ┌──────▼───────┐   │
│  │  5.0         │    │  6.0         │    │  7.0         │    │  8.0         │   │
│  │ Track        │    │ Manage       │    │ Handle       │    │ Manage      │   │
│  │ Location     │    │ Messages     │    │ Emergency    │    │ Settings    │   │
│  └──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Processes

### 1.0 Authenticate & Register Users
**Description:** Handles user and guardian authentication, registration, and profile management.

**Inputs:**
- User credentials (from User)
- Guardian credentials (from Guardian)
- Registration data (from User/Guardian)
- Google/Facebook auth tokens (from User/Guardian)

**Outputs:**
- Authentication status (to User/Guardian)
- User profile data (to D1: Users)
- Guardian profile data (to D1: Users)

**Sub-processes:**
- Email/password authentication
- Google Sign-In
- Facebook Sign-In
- User profile creation
- Guardian profile creation

---

### 2.0 Manage Device Connection
**Description:** Handles Bluetooth connection with ESP32 device, device pairing, and device status monitoring.

**Inputs:**
- Device scan requests (from User)
- Connection requests (from User)
- Image data (from ESP32 Device)
- Button events (from ESP32 Device)
- Voice audio (from ESP32 Device)
- Battery status (from ESP32 Device)

**Outputs:**
- Device list (to User)
- Connection status (to User)
- Image capture requests (to ESP32 Device)
- Audio output (to ESP32 Device)
- Control commands (to ESP32 Device)
- Device information (to D2: Devices)

**Sub-processes:**
- Bluetooth scanning
- Device pairing
- Image reception
- Button event handling
- Voice command reception
- Battery monitoring

---

### 3.0 Process Images & AI Analysis
**Description:** Receives images from ESP32, sends them to OpenAI API for analysis, and processes results.

**Inputs:**
- Image data (from Process 2.0)
- Voice prompts (from Process 4.0)
- Analysis requests (from User)

**Outputs:**
- Analysis results (to Process 4.0 for TTS)
- Analysis results (to User via notifications)
- Detection events (to D3: Detection Events)
- Analysis text (to D4: AI State)

**Sub-processes:**
- Image preprocessing
- OpenAI API communication
- Result processing
- Detection event logging

---

### 4.0 Process Voice Commands
**Description:** Handles voice input, transcription, text-to-speech output, and voice command routing.

**Inputs:**
- Voice audio (from Process 2.0)
- Voice commands (from User via phone)
- Text for TTS (from Process 3.0, Process 6.0)

**Outputs:**
- Transcribed text (to Process 3.0)
- TTS audio (to User via speakers)
- Voice command text (to Process 3.0)
- Recording status (to User)

**Sub-processes:**
- Voice recording
- Speech-to-text transcription
- Text-to-speech conversion
- Voice command parsing
- Location command detection

---

### 5.0 Track Location
**Description:** Monitors user location, saves location data, and provides location services.

**Inputs:**
- GPS coordinates (from GPS Service)
- Location requests (from User)
- Location sharing settings (from Process 8.0)

**Outputs:**
- Location data (to D5: Locations)
- Location updates (to Process 6.0 for Guardian)
- Current location (to User)
- Location callouts (to Process 4.0 for TTS)

**Sub-processes:**
- GPS tracking
- Location updates (periodic/significant movement)
- Location saving
- Address geocoding
- Location sharing

---

### 6.0 Manage Messages
**Description:** Handles messaging between users and guardians, message notifications, and message reading.

**Inputs:**
- Messages from guardian (from Guardian)
- Messages from user (from User)
- Message read status (from User/Guardian)

**Outputs:**
- Messages (to User/Guardian)
- Message notifications (to User via Process 4.0)
- Message data (to D6: Messages)
- Auto TTS messages (to Process 4.0)

**Sub-processes:**
- Message sending
- Message receiving
- Message notifications
- Message reading (TTS)
- Message status updates

---

### 7.0 Handle Emergency Alerts
**Description:** Manages emergency situations, creates alerts, and notifies guardians.

**Inputs:**
- Emergency triggers (from User, Process 2.0)
- Battery low alerts (from Process 2.0)
- Device disconnect alerts (from Process 2.0)
- Location data (from Process 5.0)

**Outputs:**
- Emergency alerts (to D7: Emergency Alerts)
- SMS notifications (to SMS Service)
- Guardian notifications (to Guardian via Process 6.0)
- Alert status (to User)

**Sub-processes:**
- Alert creation
- Guardian notification
- SMS sending
- Alert acknowledgment

---

### 8.0 Manage Settings
**Description:** Handles user preferences, settings updates, and configuration management.

**Inputs:**
- Settings changes (from User)
- Settings requests (from User)

**Outputs:**
- Settings data (to D8: Settings)
- Settings confirmation (to User)
- Settings updates (to other processes)

**Sub-processes:**
- Settings retrieval
- Settings update
- Language preferences
- TTS preferences
- Volume controls
- Location sharing preferences

---

## Data Stores

### D1: Users
**Description:** Stores user and guardian profiles, authentication data.

**Contents:**
- User ID
- Email
- Name
- Phone
- Address
- Role (user/guardian)
- Created/Updated timestamps

**Accessed by:**
- Process 1.0 (read/write)
- Process 6.0 (read)
- Process 7.0 (read)

---

### D2: Devices
**Description:** Stores ESP32 device information and status.

**Contents:**
- Device ID
- User ID
- Device name
- BLE MAC address
- Battery level
- Firmware version
- Last seen timestamp
- Paired timestamp

**Accessed by:**
- Process 2.0 (read/write)

---

### D3: Detection Events
**Description:** Logs AI detection events (hazards, OCR, currency, scene narration).

**Contents:**
- Event ID
- User ID
- Device ID
- Event type
- Confidence
- Detected label/value
- Image reference
- Location ID
- Timestamp

**Accessed by:**
- Process 3.0 (write)
- Process 6.0 (read for Guardian)

---

### D4: AI State
**Description:** Temporary storage for current AI analysis results.

**Contents:**
- Analysis text
- Timestamp

**Accessed by:**
- Process 3.0 (write)
- UI components (read)

---

### D5: Locations
**Description:** Stores user location history and current location.

**Contents:**
- Location ID
- User ID
- Latitude
- Longitude
- Accuracy
- Altitude
- Address
- Landmark
- Timestamp

**Accessed by:**
- Process 5.0 (write)
- Process 6.0 (read for Guardian)
- Process 7.0 (read)

---

### D6: Messages
**Description:** Stores messages between users and guardians.

**Contents:**
- Message ID
- User ID
- Guardian ID
- Message type (text/voice/alert)
- Content
- Direction (user_to_guardian/guardian_to_user)
- Is read status
- Created timestamp

**Accessed by:**
- Process 6.0 (read/write)

---

### D7: Emergency Alerts
**Description:** Stores emergency alert records.

**Contents:**
- Alert ID
- User ID
- Alert type (manual/battery_low/device_disconnect)
- Severity
- Location ID
- SMS sent status
- Guardian notified status
- Triggered timestamp
- Resolved timestamp

**Accessed by:**
- Process 7.0 (read/write)
- Process 6.0 (read for Guardian)

---

### D8: Settings
**Description:** Stores user preferences and configuration.

**Contents:**
- Settings ID
- User ID
- TTS language
- TTS rate
- TTS voice
- Audio volume
- Beep volume
- Hazard confidence threshold
- Detection mode
- Verbosity level
- Emergency contacts enabled
- Location sharing enabled
- Updated timestamp

**Accessed by:**
- Process 8.0 (read/write)
- Process 4.0 (read for TTS)
- Process 5.0 (read for location sharing)

---

### D9: Guardians
**Description:** Stores guardian-user relationships and link requests.

**Contents:**
- Guardian ID
- User ID
- Guardian email
- Guardian name
- Phone
- Relationship status (pending/active)
- Created timestamp
- Approved timestamp

**Accessed by:**
- Process 1.0 (write)
- Process 6.0 (read)
- Process 7.0 (read)

---

## External Entities (Same as Level 0)

1. **User** - Visually impaired person
2. **Guardian** - Caregiver
3. **ESP32 Device** - Smart glasses hardware
4. **OpenAI API** - AI service
5. **Firebase Database** - Cloud storage (represented as data stores D1-D9)
6. **SMS Service** - Emergency notifications
7. **GPS Service** - Location services

---

## Key Data Flows

### Image Processing Flow:
ESP32 Device → Process 2.0 → Process 3.0 → OpenAI API → Process 3.0 → Process 4.0 (TTS) → User

### Voice Command Flow:
User/ESP32 → Process 2.0 → Process 4.0 → Process 3.0 (if image command) → Process 3.0 → Process 4.0 (TTS) → User

### Location Tracking Flow:
GPS Service → Process 5.0 → D5: Locations → Process 6.0 → Guardian

### Messaging Flow:
Guardian → Process 6.0 → D6: Messages → Process 6.0 → Process 4.0 (TTS) → User

### Emergency Flow:
User/Process 2.0 → Process 7.0 → D7: Emergency Alerts → SMS Service → Guardian


