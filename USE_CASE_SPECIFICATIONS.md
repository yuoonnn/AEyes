# AEyes System - Use Case Specifications

**Document Version:** 1.0  
**Date:** 2024  
**Project:** AEyes - Wearable Assistive System for Visually Impaired Users

---

## Table of Contents

1. [Use Case 1: User Registration](#use-case-1-user-registration)
2. [Use Case 2: User Login](#use-case-2-user-login)
3. [Use Case 3: Guardian Registration](#use-case-3-guardian-registration)
4. [Use Case 4: Guardian Login](#use-case-4-guardian-login)
5. [Use Case 5: Connect Bluetooth Device (ESP32)](#use-case-5-connect-bluetooth-device-esp32)
6. [Use Case 6: Capture and Analyze Image with Voice Command](#use-case-6-capture-and-analyze-image-with-voice-command)
7. [Use Case 7: Send Emergency SMS Alert](#use-case-7-send-emergency-sms-alert)
8. [Use Case 8: Receive GPS Location Callout](#use-case-8-receive-gps-location-callout)
9. [Use Case 9: Send Message to Guardian](#use-case-9-send-message-to-guardian)
10. [Use Case 10: View AI Analysis Results](#use-case-10-view-ai-analysis-results)
11. [Use Case 11: Configure Application Settings](#use-case-11-configure-application-settings)
12. [Use Case 12: Monitor Battery Status](#use-case-12-monitor-battery-status)

---

## Use Case 1: User Registration

### Use Case ID
UC-001

### Use Case Name
User Registration

### Description
A visually impaired user registers for an account in the AEyes application to access assistive features. The user can register using email/password, Google Sign-In, or Facebook Sign-In.

### Actors
- **Primary Actor:** Visually Impaired User
- **Secondary Actors:** 
  - Firebase Authentication Service
  - Google Authentication Service (if using Google Sign-In)
  - Facebook Authentication Service (if using Facebook Sign-In)

### Preconditions
1. The AEyes mobile application is installed on the user's device
2. The device has an active internet connection
3. The user has not previously registered with the same email address
4. Firebase services are properly configured and accessible

### Postconditions
1. A new user account is created in Firebase Authentication
2. User profile information is stored in Firestore database
3. User is automatically logged into the application
4. User is redirected to the Home Screen
5. User can access all user-specific features

### Basic Flow (Main Success Scenario)

1. User launches the AEyes application
2. System displays the Role Selection Screen
3. User selects "User" role
4. System displays the Registration Screen with registration options
5. User chooses registration method:
   - **Option A (Email/Password):**
     5a. User enters email address
     5b. User enters password (minimum 6 characters)
     5c. User confirms password
     5d. User taps "Register" button
     5e. System validates email format and password strength
     5f. System creates account in Firebase Authentication
   - **Option B (Google Sign-In):**
     5a. User taps "Sign in with Google" button
     5b. System displays Google Sign-In dialog
     5c. User selects Google account
     5d. User grants permissions
     5e. System authenticates with Google
   - **Option C (Facebook Sign-In):**
     5a. User taps "Sign in with Facebook" button
     5b. System displays Facebook Sign-In dialog
     5c. User enters Facebook credentials
     5d. User grants permissions
     5e. System authenticates with Facebook
6. System creates user profile in Firestore with:
   - User ID (from Firebase Auth)
   - Email address
   - Display name (if available)
   - Registration timestamp
   - Role: "user"
   - Default settings (language, TTS volume, etc.)
7. System displays success message
8. System automatically logs in the user
9. System navigates to Home Screen

### Alternative Flows

**A1: Invalid Email Format**
- At step 5a, if email format is invalid:
  - System displays error message: "Please enter a valid email address"
  - Flow returns to step 5a

**A2: Weak Password**
- At step 5b, if password is less than 6 characters:
  - System displays error message: "Password must be at least 6 characters"
  - Flow returns to step 5b

**A3: Password Mismatch**
- At step 5c, if passwords do not match:
  - System displays error message: "Passwords do not match"
  - Flow returns to step 5c

**A4: Email Already Registered**
- At step 5f, if email is already registered:
  - System displays error message: "An account with this email already exists"
  - Flow returns to step 5a with option to navigate to Login Screen

**A5: Network Error**
- At any step, if network connection is lost:
  - System displays error message: "Network error. Please check your internet connection"
  - Flow pauses until connection is restored

**A6: Authentication Service Unavailable**
- At step 5e (for Google/Facebook), if service is unavailable:
  - System displays error message: "Authentication service temporarily unavailable. Please try again"
  - Flow returns to step 4

### Special Requirements
- Registration must complete within 10 seconds under normal network conditions
- All user data must be encrypted during transmission
- Password must be stored securely using Firebase Authentication hashing
- The application must be accessible with screen readers (TalkBack/VoiceOver)

---

## Use Case 2: User Login

### Use Case ID
UC-002

### Use Case Name
User Login

### Description
A registered user logs into the AEyes application to access their account and assistive features.

### Actors
- **Primary Actor:** Registered User
- **Secondary Actors:**
  - Firebase Authentication Service
  - Google Authentication Service (if using Google Sign-In)
  - Facebook Authentication Service (if using Facebook Sign-In)

### Preconditions
1. The AEyes mobile application is installed on the user's device
2. The device has an active internet connection
3. User has a registered account in the system
4. Firebase services are properly configured and accessible

### Postconditions
1. User is authenticated and logged into the application
2. User session is established
3. User is redirected to the Home Screen
4. User can access all authenticated features
5. User's preferences and settings are loaded

### Basic Flow (Main Success Scenario)

1. User launches the AEyes application
2. System displays the Role Selection Screen
3. User selects "User" role
4. System displays the Login Screen with login options
5. User chooses login method:
   - **Option A (Email/Password):**
     5a. User enters registered email address
     5b. User enters password
     5c. User taps "Login" button
     5d. System validates credentials with Firebase Authentication
   - **Option B (Google Sign-In):**
     5a. User taps "Sign in with Google" button
     5b. System displays Google Sign-In dialog
     5c. User selects previously used Google account
     5d. System authenticates with Google
   - **Option C (Facebook Sign-In):**
     5a. User taps "Sign in with Facebook" button
     5b. System displays Facebook Sign-In dialog
     5c. User authenticates with Facebook
6. System verifies authentication credentials
7. System retrieves user profile from Firestore
8. System loads user preferences and settings
9. System establishes user session
10. System displays success message
11. System navigates to Home Screen

### Alternative Flows

**A1: Invalid Credentials**
- At step 5d, if email/password combination is incorrect:
  - System displays error message: "Invalid email or password"
  - Flow returns to step 5a

**A2: Account Not Found**
- At step 6, if account does not exist:
  - System displays error message: "No account found with this email. Please register"
  - Flow returns to step 4 with option to navigate to Registration Screen

**A3: Account Disabled**
- At step 6, if account is disabled:
  - System displays error message: "This account has been disabled. Please contact support"
  - Flow terminates

**A4: Network Error**
- At any step, if network connection is lost:
  - System displays error message: "Network error. Please check your internet connection"
  - Flow pauses until connection is restored

**A5: Too Many Failed Attempts**
- If user fails login 5 times consecutively:
  - System temporarily locks account for 15 minutes
  - System displays message: "Too many failed attempts. Account locked for 15 minutes"
  - Flow terminates

### Special Requirements
- Login must complete within 5 seconds under normal network conditions
- Session must remain active for 24 hours of inactivity
- All authentication data must be encrypted during transmission
- The application must support biometric authentication (fingerprint/face) if available

---

## Use Case 3: Guardian Registration

### Use Case ID
UC-003

### Use Case Name
Guardian Registration

### Description
A caregiver or guardian registers for an account to monitor and assist visually impaired users. Guardians have access to monitoring features, location tracking, and emergency alerts.

### Actors
- **Primary Actor:** Guardian/Caregiver
- **Secondary Actors:**
  - Firebase Authentication Service
  - Firestore Database

### Preconditions
1. The AEyes mobile application is installed on the guardian's device
2. The device has an active internet connection
3. The guardian has not previously registered with the same email address
4. Firebase services are properly configured and accessible

### Postconditions
1. A new guardian account is created in Firebase Authentication
2. Guardian profile information is stored in Firestore database
3. Guardian is automatically logged into the application
4. Guardian is redirected to the Guardian Dashboard
5. Guardian can access all guardian-specific features

### Basic Flow (Main Success Scenario)

1. Guardian launches the AEyes application
2. System displays the Role Selection Screen
3. Guardian selects "Guardian" role
4. System displays the Guardian Registration Screen
5. Guardian enters email address
6. Guardian enters password (minimum 6 characters)
7. Guardian confirms password
8. Guardian enters phone number (for SMS alerts)
9. Guardian enters full name
10. Guardian taps "Register" button
11. System validates:
    - Email format
    - Password strength
    - Password match
    - Phone number format
12. System creates guardian account in Firebase Authentication
13. System creates guardian profile in Firestore with:
    - Guardian ID (from Firebase Auth)
    - Email address
    - Phone number
    - Full name
    - Registration timestamp
    - Role: "guardian"
    - Associated users list (initially empty)
14. System displays success message
15. System automatically logs in the guardian
16. System navigates to Guardian Dashboard

### Alternative Flows

**A1: Invalid Email Format**
- At step 5, if email format is invalid:
  - System displays error message: "Please enter a valid email address"
  - Flow returns to step 5

**A2: Weak Password**
- At step 6, if password is less than 6 characters:
  - System displays error message: "Password must be at least 6 characters"
  - Flow returns to step 6

**A3: Password Mismatch**
- At step 7, if passwords do not match:
  - System displays error message: "Passwords do not match"
  - Flow returns to step 6

**A4: Invalid Phone Number**
- At step 8, if phone number format is invalid:
  - System displays error message: "Please enter a valid phone number"
  - Flow returns to step 8

**A5: Email Already Registered**
- At step 12, if email is already registered:
  - System displays error message: "An account with this email already exists"
  - Flow returns to step 5 with option to navigate to Login Screen

**A6: Network Error**
- At any step, if network connection is lost:
  - System displays error message: "Network error. Please check your internet connection"
  - Flow pauses until connection is restored

### Special Requirements
- Registration must complete within 10 seconds under normal network conditions
- Phone number must be validated according to international format standards
- All guardian data must be encrypted during transmission
- Guardian accounts require email verification (optional enhancement)

---

## Use Case 4: Guardian Login

### Use Case ID
UC-004

### Use Case Name
Guardian Login

### Description
A registered guardian logs into the AEyes application to access monitoring and management features for associated users.

### Actors
- **Primary Actor:** Registered Guardian
- **Secondary Actors:**
  - Firebase Authentication Service
  - Firestore Database

### Preconditions
1. The AEyes mobile application is installed on the guardian's device
2. The device has an active internet connection
3. Guardian has a registered account in the system
4. Firebase services are properly configured and accessible

### Postconditions
1. Guardian is authenticated and logged into the application
2. Guardian session is established
3. Guardian is redirected to the Guardian Dashboard
4. Guardian can view associated users and their status
5. Guardian can access monitoring features

### Basic Flow (Main Success Scenario)

1. Guardian launches the AEyes application
2. System displays the Role Selection Screen
3. Guardian selects "Guardian" role
4. System displays the Guardian Login Screen
5. Guardian enters registered email address
6. Guardian enters password
7. Guardian taps "Login" button
8. System validates credentials with Firebase Authentication
9. System verifies guardian role in Firestore
10. System retrieves guardian profile and associated users list
11. System loads guardian preferences
12. System establishes guardian session
13. System displays success message
14. System navigates to Guardian Dashboard

### Alternative Flows

**A1: Invalid Credentials**
- At step 8, if email/password combination is incorrect:
  - System displays error message: "Invalid email or password"
  - Flow returns to step 5

**A2: Account Not Found**
- At step 8, if account does not exist:
  - System displays error message: "No guardian account found. Please register"
  - Flow returns to step 4 with option to navigate to Registration Screen

**A3: Wrong Role**
- At step 9, if account exists but is not a guardian:
  - System displays error message: "This account is not registered as a guardian"
  - Flow returns to step 2 (Role Selection)

**A4: Network Error**
- At any step, if network connection is lost:
  - System displays error message: "Network error. Please check your internet connection"
  - Flow pauses until connection is restored

### Special Requirements
- Login must complete within 5 seconds under normal network conditions
- Guardian session must remain active for 24 hours of inactivity
- All authentication data must be encrypted during transmission

---

## Use Case 5: Connect Bluetooth Device (ESP32)

### Use Case ID
UC-005

### Use Case Name
Connect Bluetooth Device (ESP32)

### Description
A user connects their AEyes smart glasses (ESP32 device) to the mobile application via Bluetooth Low Energy (BLE) to enable image capture, voice commands, and device control.

### Actors
- **Primary Actor:** User
- **Secondary Actors:**
  - Bluetooth Service
  - ESP32 Smart Glasses Device
  - Android/iOS Bluetooth System

### Preconditions
1. User is logged into the application
2. User's device has Bluetooth capability enabled
3. ESP32 smart glasses device is powered on and in pairing mode
4. ESP32 device is within Bluetooth range (approximately 10 meters)
5. User has granted Bluetooth permissions to the application

### Postconditions
1. ESP32 device is successfully paired and connected via BLE
2. Bluetooth connection status is displayed in the application
3. User can receive images from ESP32 device
4. User can send commands to ESP32 device
5. Battery level of ESP32 device is monitored
6. Voice commands from ESP32 are enabled

### Basic Flow (Main Success Scenario)

1. User navigates to Bluetooth Screen from Home Screen
2. System checks Bluetooth permissions
3. If permissions not granted:
   - System requests Bluetooth permissions
   - User grants permissions
4. System checks if Bluetooth is enabled on device
5. If Bluetooth is disabled:
   - System prompts user to enable Bluetooth
   - User enables Bluetooth in device settings
6. User taps "Scan for Devices" button
7. System starts BLE device scan
8. System displays list of available BLE devices
9. User identifies and selects "AEyes-ESP32" device from the list
10. System initiates connection to selected device
11. System establishes BLE connection
12. System discovers required BLE services and characteristics:
    - Image capture service
    - Voice command service
    - Battery service
    - Button press service
13. System enables notifications for all required characteristics
14. System displays connection success message
15. System updates connection status to "Connected"
16. System starts monitoring ESP32 battery level
17. System enables image capture functionality
18. System enables voice command functionality

### Alternative Flows

**A1: Bluetooth Permissions Denied**
- At step 3, if user denies Bluetooth permissions:
  - System displays error message: "Bluetooth permissions are required for device connection"
  - System provides link to app settings
  - Flow terminates

**A2: Bluetooth Not Enabled**
- At step 5, if user does not enable Bluetooth:
  - System displays persistent message: "Please enable Bluetooth to connect device"
  - Flow pauses at step 5

**A3: No Devices Found**
- At step 8, if no BLE devices are found:
  - System displays message: "No devices found. Make sure your ESP32 device is powered on and in range"
  - User can retry scan (returns to step 6)

**A4: Device Not in Range**
- At step 10, if device is out of range:
  - System displays error message: "Device is out of range. Please move closer"
  - Flow returns to step 6

**A5: Connection Failed**
- At step 11, if connection fails:
  - System displays error message: "Connection failed. Please try again"
  - Flow returns to step 6

**A6: Required Services Not Found**
- At step 12, if required BLE services are not available:
  - System displays error message: "Device does not support required services"
  - System disconnects from device
  - Flow returns to step 6

**A7: Connection Lost During Use**
- During normal use, if connection is lost:
  - System detects disconnection
  - System displays notification: "Device disconnected. Attempting to reconnect..."
  - System attempts automatic reconnection
  - If reconnection fails after 3 attempts:
    - System displays error: "Reconnection failed. Please manually reconnect"
    - Flow returns to step 6

### Special Requirements
- Device scan must complete within 10 seconds
- Connection establishment must complete within 5 seconds
- System must automatically attempt reconnection if connection is lost
- BLE connection must maintain stability within 10-meter range
- Battery level updates must be received every 30 seconds

---

## Use Case 6: Capture and Analyze Image with Voice Command

### Use Case ID
UC-006

### Use Case Name
Capture and Analyze Image with Voice Command

### Description
A user captures an image from the ESP32 smart glasses camera using a voice command, and the system analyzes the image using OpenAI GPT-4 Vision API to provide descriptive audio feedback about the scene.

### Actors
- **Primary Actor:** User
- **Secondary Actors:**
  - ESP32 Smart Glasses Device
  - Bluetooth Service
  - OpenAI GPT-4 Vision API
  - Text-to-Speech Service
  - Speech Recognition Service

### Preconditions
1. User is logged into the application
2. ESP32 device is connected via Bluetooth
3. ESP32 device has camera functionality enabled
4. User has an active internet connection
5. OpenAI API key is configured in the application
6. Text-to-Speech service is initialized
7. Speech Recognition service is available (for phone-based voice commands)

### Postconditions
1. Image is captured from ESP32 camera
2. Image is received via Bluetooth
3. Image is analyzed by OpenAI GPT-4 Vision API
4. Analysis result is stored in the system
5. Analysis result is converted to speech via TTS
6. Audio feedback is played to the user
7. Analysis result is displayed on screen (if accessible)
8. Analysis history is saved in Firestore

### Basic Flow (Main Success Scenario)

#### Option A: Push-to-Talk Voice Command (Phone)

1. User navigates to Home Screen
2. User locates and holds the "Push-to-Talk" button
3. System starts speech recognition
4. System provides audio/visual feedback that listening has started
5. User speaks voice command (e.g., "What's in front of me?", "How much money am I holding?")
6. User releases the "Push-to-Talk" button
7. System stops speech recognition
8. System captures final speech text
9. System sends "CAPTURE" command to ESP32 via Bluetooth
10. ESP32 device captures image from camera
11. ESP32 device sends image data via Bluetooth to mobile app
12. System receives image data
13. System sends image and voice command text to OpenAI GPT-4 Vision API
14. OpenAI API analyzes image with custom prompt based on voice command
15. System receives analysis result from OpenAI
16. System stores analysis result in local state
17. System saves analysis to Firestore database
18. System converts analysis text to speech using TTS service
19. System plays audio feedback through device speakers/earphones
20. System displays analysis result on screen
21. System provides completion feedback to user

#### Option B: ESP32 Button Press

1. User presses capture button on ESP32 device
2. ESP32 device sends button press signal via Bluetooth
3. System receives button press notification
4. System sends "CAPTURE" command to ESP32 via Bluetooth
5. ESP32 device captures image from camera
6. ESP32 device sends image data via Bluetooth to mobile app
7. System receives image data
8. System sends image to OpenAI GPT-4 Vision API with default prompt
9. OpenAI API analyzes image
10. System receives analysis result from OpenAI
11. System stores analysis result in local state
12. System saves analysis to Firestore database
13. System converts analysis text to speech using TTS service
14. System plays audio feedback through device speakers/earphones
15. System displays analysis result on screen

#### Option C: ESP32 Voice Command

1. User speaks voice command into ESP32 device microphone
2. ESP32 device processes voice command locally or sends audio to phone
3. ESP32 device sends voice command text via Bluetooth
4. System receives voice command text
5. System sends "CAPTURE" command to ESP32 via Bluetooth
6. ESP32 device captures image from camera
7. ESP32 device sends image data via Bluetooth to mobile app
8. System receives image data
9. System sends image and voice command text to OpenAI GPT-4 Vision API
10. OpenAI API analyzes image with custom prompt based on voice command
11. System receives analysis result from OpenAI
12. System stores analysis result in local state
13. System saves analysis to Firestore database
14. System converts analysis text to speech using TTS service
15. System plays audio feedback through device speakers/earphones
16. System displays analysis result on screen

### Alternative Flows

**A1: ESP32 Not Connected**
- At step 9 (Option A), if ESP32 is not connected:
  - System displays error message: "ESP32 device not connected. Please connect device first"
  - Flow terminates

**A2: Image Capture Failed**
- At step 10, if ESP32 fails to capture image:
  - System displays error message: "Image capture failed. Please try again"
  - Flow returns to step 9

**A3: Image Transfer Failed**
- At step 11, if image transfer via Bluetooth fails:
  - System displays error message: "Image transfer failed. Please check connection"
  - System attempts retry (up to 3 times)
  - If all retries fail, flow terminates

**A4: OpenAI API Error**
- At step 13, if OpenAI API returns an error:
  - System displays error message: "Analysis service unavailable. Please try again later"
  - Flow terminates

**A5: Network Error**
- At step 13, if network connection is lost:
  - System displays error message: "Network error. Please check your internet connection"
  - Flow terminates

**A6: TTS Service Unavailable**
- At step 18, if TTS service fails:
  - System displays analysis result on screen only
  - System logs error
  - Flow continues (audio feedback skipped)

**A7: Speech Recognition Failed**
- At step 8 (Option A), if speech recognition fails:
  - System displays error message: "Could not understand voice command. Please try again"
  - Flow returns to step 2

**A8: Voice Command Not Recognized**
- At step 8 (Option A), if no speech is detected:
  - System displays message: "No voice command detected"
  - Flow returns to step 2

### Special Requirements
- Image capture must complete within 2 seconds
- Image transfer must complete within 5 seconds
- OpenAI API response must be received within 15 seconds
- TTS audio must start playing within 2 seconds of receiving analysis
- Analysis must support multiple languages based on user preferences
- System must handle images up to 5MB in size
- Analysis results must be cached for offline access
- System must support OCR (Optical Character Recognition) for text reading
- System must support currency denomination identification

---

## Use Case 7: Send Emergency SMS Alert

### Use Case ID
UC-007

### Use Case Name
Send Emergency SMS Alert

### Description
A user sends an emergency SMS alert to all registered guardians when they need immediate assistance. The alert includes a predefined message and the user's current location.

### Actors
- **Primary Actor:** User
- **Secondary Actors:**
  - SMS Service
  - Firestore Database
  - GPS Service
  - Guardian(s)

### Preconditions
1. User is logged into the application
2. User has at least one guardian registered in the system
3. Guardian(s) have valid phone numbers in their profiles
4. User's device has SMS sending capability
5. User has granted SMS permissions to the application
6. User's device has location services enabled (for location sharing)

### Postconditions
1. Emergency SMS is sent to all registered guardians
2. SMS includes predefined message text
3. SMS includes user's current location (if available)
4. Alert is logged in Firestore database
5. Guardians receive SMS notifications
6. User receives confirmation of sent alerts

### Basic Flow (Main Success Scenario)

1. User triggers emergency alert using one of the following methods:
   - **Option A:** Presses emergency button on ESP32 device
   - **Option B:** Uses voice command "help" or "emergency"
   - **Option C:** Taps emergency button in mobile app
2. System detects emergency trigger
3. System retrieves list of predefined emergency messages from Firestore
4. If multiple messages exist:
   - System displays dialog with list of predefined messages
   - User selects desired message
5. If only one message exists:
   - System uses that message automatically
6. System retrieves user's current GPS location
7. System formats location as address or coordinates
8. System retrieves all guardian phone numbers from Firestore
9. For each guardian:
   - System formats SMS message:
     - Predefined message text
     - User's current location
     - Timestamp
   - System sends SMS to guardian's phone number
10. System records SMS send status for each guardian
11. System logs emergency alert in Firestore with:
    - User ID
    - Timestamp
    - Message sent
    - Location
    - Guardian recipients
    - Send status for each guardian
12. System displays confirmation message to user:
    - Number of guardians notified
    - Success/failure status
13. System provides audio confirmation via TTS (if enabled)

### Alternative Flows

**A1: No Guardians Registered**
- At step 8, if no guardians are found:
  - System displays error message: "No guardians registered. Please add a guardian in Settings"
  - Flow terminates

**A2: No Guardian Phone Numbers**
- At step 8, if guardians exist but have no phone numbers:
  - System displays warning: "Guardians do not have phone numbers. SMS cannot be sent"
  - System logs alert in Firestore without SMS
  - Flow continues to step 12

**A3: SMS Permissions Denied**
- At step 9, if SMS permissions are not granted:
  - System requests SMS permissions
  - If user denies:
    - System displays error: "SMS permissions required for emergency alerts"
    - Flow terminates

**A4: Location Unavailable**
- At step 6, if GPS location cannot be obtained:
  - System uses last known location from Firestore
  - If no location available:
    - System sends SMS without location information
    - System logs warning in Firestore

**A5: SMS Send Failure**
- At step 9, if SMS fails to send to a guardian:
  - System logs failure for that guardian
  - System continues sending to other guardians
  - System includes failure count in confirmation message

**A6: No Predefined Messages**
- At step 3, if no predefined messages exist:
  - System displays message: "No emergency messages configured. Please add messages in Settings"
  - System navigates to Settings screen
  - Flow terminates

**A7: Network Error**
- At step 9, if network connection is lost:
  - System queues SMS for sending when connection is restored
  - System displays message: "Network error. SMS will be sent when connection is restored"
  - Flow continues

### Special Requirements
- SMS must be sent within 5 seconds of trigger
- Location must be accurate within 10 meters
- System must support multiple guardians (up to 10)
- SMS must be sent even if app is in background
- System must retry failed SMS sends up to 3 times
- Emergency alerts must be logged for 90 days
- System must support international phone number formats

---

## Use Case 8: Receive GPS Location Callout

### Use Case ID
UC-008

### Use Case Name
Receive GPS Location Callout

### Description
The system periodically provides audio callouts of the user's current location and nearby landmarks using GPS coordinates and reverse geocoding, helping the user maintain spatial awareness while navigating.

### Actors
- **Primary Actor:** User
- **Secondary Actors:**
  - GPS Service
  - Mapbox Geocoding API
  - Text-to-Speech Service
  - Firestore Database

### Preconditions
1. User is logged into the application
2. User's device has location services enabled
3. User has granted location permissions to the application
4. Mapbox API key is configured in the application
5. Text-to-Speech service is initialized and enabled
6. GPS callout service is enabled in user settings
7. User's device has an active internet connection (for reverse geocoding)

### Postconditions
1. User's current location is obtained via GPS
2. Location is reverse geocoded to address/landmark
3. Location callout is converted to speech
4. Audio callout is played to the user
5. Location is saved to Firestore database
6. User receives spatial awareness information

### Basic Flow (Main Success Scenario)

1. System initializes GPS Callout Service on app startup
2. System checks location permissions
3. If permissions not granted:
   - System requests location permissions
   - User grants permissions
4. System starts periodic location updates (every 2 minutes)
5. At each update interval:
   - System requests current GPS location from device
   - System receives GPS coordinates (latitude, longitude, accuracy)
6. System sends coordinates to Mapbox Reverse Geocoding API
7. Mapbox API returns address and nearby landmarks
8. System formats location information:
   - Street address or landmark name
   - Distance from previous location (if applicable)
   - Nearby points of interest (optional)
9. System converts location text to speech using TTS service
10. System plays audio callout through device speakers/earphones
11. System saves location to Firestore database with:
    - User ID
    - Timestamp
    - Latitude
    - Longitude
    - Accuracy
    - Address/landmark
12. System waits for next update interval (2 minutes)
13. Flow repeats from step 5

### Alternative Flows

**A1: Location Permissions Denied**
- At step 3, if user denies location permissions:
  - System displays message: "Location permissions required for GPS callouts"
  - System disables GPS callout service
  - Flow terminates

**A2: Location Services Disabled**
- At step 4, if device location services are disabled:
  - System prompts user to enable location services
  - System pauses updates until location is enabled
  - Flow pauses at step 4

**A3: GPS Signal Lost**
- At step 5, if GPS signal cannot be obtained:
  - System uses last known location
  - System attempts to get location again after 30 seconds
  - If signal remains lost:
    - System pauses updates
    - System displays notification: "GPS signal lost. Location updates paused"
    - Flow pauses

**A4: Reverse Geocoding Failed**
- At step 7, if Mapbox API fails:
  - System uses coordinates format: "Latitude [lat], Longitude [lon]"
  - System continues with coordinate-based callout
  - Flow continues to step 9

**A5: Network Error**
- At step 6, if network connection is lost:
  - System uses coordinates format instead of address
  - System continues with coordinate-based callout
  - System logs location to Firestore for later geocoding
  - Flow continues

**A6: TTS Service Unavailable**
- At step 9, if TTS service fails:
  - System displays location on screen (if accessible)
  - System logs error
  - Flow continues (audio callout skipped)

**A7: User Disables GPS Callouts**
- During operation, if user disables GPS callouts in settings:
  - System stops periodic updates
  - System saves current state
  - Flow terminates

### Special Requirements
- Location updates must occur every 2 minutes (±10 seconds)
- GPS accuracy must be within 10 meters
- Location callout audio must be clear and audible
- System must not interrupt ongoing TTS announcements
- Location data must be stored efficiently (prune old data after 30 days)
- System must work in background mode
- Battery usage must be optimized (use low-power location mode when possible)
- System must respect user's language preference for callouts

---

## Use Case 9: Send Message to Guardian

### Use Case ID
UC-009

### Use Case Name
Send Message to Guardian

### Description
A user sends a text message to one or more registered guardians through the in-app messaging system. Messages are stored in Firestore and can be read by guardians in real-time.

### Actors
- **Primary Actor:** User
- **Secondary Actors:**
  - Firestore Database
  - Guardian(s)
  - Notification Service (for guardian notifications)

### Preconditions
1. User is logged into the application
2. User has at least one guardian registered in the system
3. User is on the Messages Screen
4. Firestore database is accessible
5. User has an active internet connection

### Postconditions
1. Message is created and stored in Firestore
2. Message is marked as unread for guardian(s)
3. Guardian(s) receive notification of new message (if app is open or push notifications enabled)
4. Message appears in user's sent messages
5. Message appears in guardian's received messages

### Basic Flow (Main Success Scenario)

1. User navigates to Messages Screen from Home Screen
2. System displays list of guardians
3. User selects a guardian to message
4. System displays conversation view with message history
5. User composes message using one of the following methods:
   - **Option A:** Types message using keyboard (if accessible)
   - **Option B:** Uses voice input (speech-to-text)
   - **Option C:** Selects predefined message
6. System validates message (not empty, within character limit)
7. User taps "Send" button
8. System creates message document in Firestore with:
   - Message ID (auto-generated)
   - Sender ID (user ID)
   - Recipient ID (guardian ID)
   - Message text
   - Timestamp
   - Direction: "user_to_guardian"
   - Is read: false
9. System saves message to Firestore
10. System updates conversation view with new message
11. System marks message as sent
12. System triggers notification to guardian (if guardian app is active)
13. System provides audio confirmation via TTS: "Message sent"
14. System scrolls to show latest message

### Alternative Flows

**A1: No Guardians Registered**
- At step 2, if no guardians are found:
  - System displays message: "No guardians registered. Please add a guardian in Settings"
  - Flow terminates

**A2: Empty Message**
- At step 6, if message is empty:
  - System displays error: "Message cannot be empty"
  - Flow returns to step 5

**A3: Message Too Long**
- At step 6, if message exceeds character limit (500 characters):
  - System displays error: "Message is too long. Maximum 500 characters"
  - Flow returns to step 5

**A4: Network Error**
- At step 9, if network connection is lost:
  - System displays error: "Network error. Message will be sent when connection is restored"
  - System queues message for sending
  - When connection is restored:
    - System automatically sends queued message
    - System displays confirmation

**A5: Firestore Error**
- At step 9, if Firestore save fails:
  - System displays error: "Failed to send message. Please try again"
  - Flow returns to step 5

**A6: Voice Input Failed**
- At step 5 (Option B), if speech-to-text fails:
  - System displays error: "Could not process voice input. Please try typing"
  - Flow returns to step 5

### Special Requirements
- Message must be sent within 2 seconds under normal network conditions
- System must support messages up to 500 characters
- Messages must be stored in Firestore with proper indexing
- System must support real-time message updates
- Messages must be encrypted in transit
- System must support message history (last 100 messages per conversation)
- System must mark messages as read when guardian views them

---

## Use Case 10: View AI Analysis Results

### Use Case ID
UC-010

### Use Case Name
View AI Analysis Results

### Description
A user views the history of AI image analysis results, including recent analyses and detailed descriptions. The user can access both current and historical analysis data.

### Actors
- **Primary Actor:** User
- **Secondary Actors:**
  - Firestore Database
  - AI State Service
  - Text-to-Speech Service (for reading results)

### Preconditions
1. User is logged into the application
2. User has performed at least one image analysis
3. Analysis results are stored in Firestore or local state
4. User navigates to Analysis Screen

### Postconditions
1. User views list of analysis results
2. User can access detailed view of any analysis
3. User can hear analysis results via TTS (if enabled)
4. Analysis history is displayed in chronological order

### Basic Flow (Main Success Scenario)

1. User navigates to Analysis Screen from Home Screen or navigation menu
2. System retrieves analysis history from:
   - Local AI State (for current session)
   - Firestore Database (for historical analyses)
3. System displays list of analyses sorted by timestamp (newest first)
4. For each analysis, system displays:
   - Timestamp
   - Preview of analysis text (first 100 characters)
   - Image thumbnail (if available)
5. User selects an analysis to view details
6. System displays detailed analysis view with:
   - Full analysis text
   - Complete timestamp
   - Associated image (if available)
   - Voice command used (if applicable)
7. User can interact with analysis:
   - **Option A:** Tap "Read Aloud" button to hear analysis via TTS
   - **Option B:** Tap "Share" button to share analysis
   - **Option C:** Tap "Delete" button to remove analysis
8. If user taps "Read Aloud":
   - System converts analysis text to speech
   - System plays audio through device speakers/earphones
9. User navigates back to list view or home

### Alternative Flows

**A1: No Analysis History**
- At step 3, if no analyses are found:
  - System displays message: "No analysis history. Capture an image to get started"
  - System provides button to navigate to Home Screen
  - Flow pauses

**A2: Firestore Error**
- At step 2, if Firestore retrieval fails:
  - System displays local analyses only
  - System displays warning: "Could not load full history. Showing recent analyses only"
  - Flow continues with local data

**A3: TTS Service Unavailable**
- At step 8, if TTS service fails:
  - System displays error: "Text-to-speech unavailable"
  - Flow continues (audio playback skipped)

**A4: Image Not Available**
- At step 6, if associated image is not available:
  - System displays analysis text only
  - System shows placeholder: "Image not available"
  - Flow continues

**A5: Network Error**
- At step 2, if network connection is lost:
  - System displays local analyses only
  - System displays message: "Offline mode. Showing local analyses only"
  - Flow continues with cached data

### Special Requirements
- Analysis list must load within 3 seconds
- System must display last 50 analyses
- Analysis text must be fully accessible via screen readers
- System must support pagination for large analysis histories
- Images must be optimized for display (thumbnail generation)
- System must support search/filter functionality (optional enhancement)

---

## Use Case 11: Configure Application Settings

### Use Case ID
UC-011

### Use Case Name
Configure Application Settings

### Description
A user configures various application settings including text-to-speech preferences, language settings, Bluetooth preferences, GPS callout settings, and accessibility options.

### Actors
- **Primary Actor:** User
- **Secondary Actors:**
  - Firestore Database
  - Text-to-Speech Service
  - GPS Callout Service
  - Bluetooth Service

### Preconditions
1. User is logged into the application
2. User navigates to Settings Screen
3. User has necessary permissions for settings being configured

### Postconditions
1. User preferences are updated
2. Settings are saved to Firestore database
3. Settings are applied immediately to relevant services
4. Changes persist across app sessions

### Basic Flow (Main Success Scenario)

1. User navigates to Settings Screen from Home Screen or navigation menu
2. System displays settings categories:
   - Text-to-Speech Settings
   - Language Settings
   - Bluetooth Settings
   - GPS Callout Settings
   - Accessibility Settings
   - Emergency Message Settings
   - App Preferences
3. User selects a settings category
4. System displays settings options for that category
5. User modifies settings:

   **For TTS Settings:**
   - User adjusts speech rate (slower/normal/faster)
   - User adjusts speech volume (0-100%)
   - User selects voice type (male/female/neutral)
   - User enables/disables TTS

   **For Language Settings:**
   - User selects preferred language
   - User selects region/dialect

   **For Bluetooth Settings:**
   - User views connected device status
   - User can disconnect device
   - User can clear Bluetooth cache

   **For GPS Callout Settings:**
   - User enables/disables GPS callouts
   - User adjusts callout frequency (1 min, 2 min, 5 min)
   - User selects callout detail level (address only, address + landmarks)

   **For Accessibility Settings:**
   - User enables/disables dark mode
   - User adjusts font size
   - User enables/disables high contrast mode
   - User configures screen reader settings

   **For Emergency Message Settings:**
   - User manages predefined emergency messages
   - User adds new message
   - User edits existing message
   - User deletes message

   **For App Preferences:**
   - User enables/disables notifications
   - User configures battery monitoring alerts
   - User sets data usage preferences
6. System validates each setting change
7. System saves settings to Firestore database
8. System applies settings to relevant services immediately
9. System displays confirmation message: "Settings saved"
10. User can continue modifying other settings or navigate away

### Alternative Flows

**A1: Invalid Setting Value**
- At step 6, if setting value is invalid:
  - System displays error: "Invalid setting value"
  - System reverts to previous value
  - Flow returns to step 5

**A2: Firestore Save Failed**
- At step 7, if Firestore save fails:
  - System displays error: "Failed to save settings. Please try again"
  - Settings are saved locally only
  - System attempts to sync when connection is restored
  - Flow continues

**A3: Service Application Failed**
- At step 8, if service cannot apply setting:
  - System displays warning: "Setting saved but not applied. Please restart app"
  - Flow continues

**A4: Permission Required**
- At step 5, if setting requires permission not granted:
  - System requests necessary permission
  - If user denies:
    - System displays message: "Permission required for this setting"
    - Setting remains unchanged
    - Flow returns to step 5

**A5: Network Error**
- At step 7, if network connection is lost:
  - System saves settings locally
  - System displays message: "Settings saved locally. Will sync when online"
  - System syncs when connection is restored
  - Flow continues

### Special Requirements
- Settings must be saved within 2 seconds
- Settings must persist across app restarts
- Settings must sync across multiple devices (if user logs in on different device)
- All settings must have sensible defaults
- Settings UI must be fully accessible via screen readers
- System must support settings export/import (optional enhancement)

---

## Use Case 12: Monitor Battery Status

### Use Case ID
UC-012

### Use Case Name
Monitor Battery Status

### Description
The system continuously monitors the battery levels of both the mobile device and the connected ESP32 smart glasses device, displaying status information and providing low battery alerts.

### Actors
- **Primary Actor:** User
- **Secondary Actors:**
  - Battery Service
  - ESP32 Smart Glasses Device
  - Bluetooth Service
  - Notification Service

### Preconditions
1. User is logged into the application
2. Battery Service is initialized
3. For ESP32 monitoring: ESP32 device is connected via Bluetooth
4. Application has necessary permissions to access battery information

### Postconditions
1. Battery levels are displayed on Home Screen
2. Battery status is updated in real-time
3. Low battery alerts are triggered when thresholds are reached
4. Battery information is accessible to user at all times

### Basic Flow (Main Success Scenario)

1. System initializes Battery Service on app startup
2. System starts monitoring phone battery level
3. System displays phone battery level on Home Screen
4. If ESP32 is connected:
   - System starts monitoring ESP32 battery level via Bluetooth
   - System displays ESP32 battery level on Home Screen
5. System updates battery levels every 30 seconds
6. System checks battery levels against thresholds:
   - **Critical:** < 10%
   - **Low:** 10-20%
   - **Medium:** 20-50%
   - **Good:** > 50%
7. System updates visual indicators:
   - Color coding (red for critical/low, yellow for medium, green for good)
   - Battery icon with appropriate fill level
8. If battery level drops below 20%:
   - System triggers low battery alert
   - System displays notification
   - System provides audio alert via TTS: "Low battery warning"
9. If battery level drops below 10%:
   - System triggers critical battery alert
   - System displays urgent notification
   - System provides audio alert via TTS: "Critical battery level. Please charge soon"
10. System continues monitoring and updating display
11. User can view detailed battery information on Home Screen at any time

### Alternative Flows

**A1: ESP32 Not Connected**
- At step 4, if ESP32 is not connected:
   - System displays "N/A" for ESP32 battery
   - System monitors phone battery only
   - Flow continues

**A2: ESP32 Connection Lost During Monitoring**
- During monitoring, if ESP32 disconnects:
   - System stops monitoring ESP32 battery
   - System displays "Disconnected" status
   - System continues monitoring phone battery
   - When ESP32 reconnects:
     - System resumes ESP32 battery monitoring
     - Flow continues from step 4

**A3: Battery Service Unavailable**
- At step 2, if battery service cannot be initialized:
   - System displays "Battery monitoring unavailable"
   - System logs error
   - Flow continues (monitoring disabled)

**A4: Bluetooth Communication Error**
- At step 4, if ESP32 battery data cannot be retrieved:
   - System displays "Unable to read battery level"
   - System attempts retry after 30 seconds
   - Flow continues

**A5: Device Shutting Down**
- If phone battery reaches critical level and device is shutting down:
   - System saves current state
   - System logs final battery level
   - Flow terminates

### Special Requirements
- Battery levels must update every 30 seconds (±5 seconds)
- Low battery alerts must be clearly audible
- Battery status must be visible on Home Screen at all times
- System must not drain battery excessively through monitoring
- ESP32 battery monitoring must not interfere with other Bluetooth communications
- Battery alerts must respect user's notification preferences
- System must support battery level history (optional enhancement)

---

## Document Control

### Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2024 | System Analyst | Initial Use Case Specifications Document |

### Related Documents
- AEyes System Requirements Document
- AEyes Technical Design Document
- AEyes User Manual
- AEyes API Documentation

### Notes
- All use cases are based on the current AEyes system implementation
- Use cases may be updated as the system evolves
- Additional use cases can be added as new features are developed
- All timings and performance requirements are targets and may vary based on device capabilities and network conditions

---

**End of Document**

