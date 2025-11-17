# DFD Level 0 - AEyes System Context Diagram

## Overview
This diagram shows the AEyes system as a single process with all external entities and data flows.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                        AEyes System                             │
│                    (Mobile App + Cloud)                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         │                    │                    │
    ┌────▼────┐          ┌────▼────┐          ┌────▼────┐
    │  User  │          │ Guardian│          │  ESP32  │
    │        │          │         │          │ Device  │
    └────┬────┘          └────┬────┘          └────┬────┘
         │                    │                    │
         │                    │                    │
    ┌────▼────────────────────▼────────────────────▼────┐
    │                                                    │
    │              AEyes System                          │
    │                                                    │
    └────────────────────────────────────────────────────┘
         │                    │                    │
         │                    │                    │
    ┌────▼────┐          ┌────▼────┐          ┌────▼────┐
    │ OpenAI │          │ Firebase│          │   SMS   │
    │  API   │          │Database │          │ Service │
    └────────┘          └────────┘          └─────────┘
```

## External Entities

1. **User** - Visually impaired person using the system
2. **Guardian** - Caregiver monitoring the user
3. **ESP32 Device** - Smart glasses hardware (camera, buttons, sensors)
4. **OpenAI API** - External AI service for image analysis
5. **Firebase Database** - Cloud database for data storage
6. **SMS Service** - External service for emergency notifications

## Data Flows

### From User to System:
- User credentials (login/registration)
- User settings preferences
- Voice commands
- Emergency alerts
- Message responses

### From System to User:
- Authentication status
- AI analysis results (text-to-speech)
- Navigation guidance
- Notifications
- Settings confirmation

### From Guardian to System:
- Guardian credentials
- Messages to user
- Guardian settings
- Link requests

### From System to Guardian:
- User location updates
- Emergency alerts
- User status
- Messages from user
- Detection events

### From ESP32 Device to System:
- Captured images
- Button press events
- Voice commands (audio)
- Battery status
- Device status

### From System to ESP32 Device:
- Image capture requests
- Audio output (TTS)
- Control commands
- Connection status

### From System to OpenAI API:
- Image data
- Analysis prompts

### From OpenAI API to System:
- Image analysis results
- Text descriptions

### From System to Firebase Database:
- User profiles
- Settings
- Location data
- Messages
- Detection events
- Device information
- Guardian links
- Emergency alerts

### From Firebase Database to System:
- User profiles
- Settings
- Location history
- Messages
- Detection events
- Device status
- Guardian information
- Emergency alerts

### From System to SMS Service:
- Emergency alert messages
- Location notifications

### From SMS Service to System:
- SMS delivery status


