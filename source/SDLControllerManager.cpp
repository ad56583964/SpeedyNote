#include "SDLControllerManager.h"

#include <QDebug>
#include <QSettings>
#include <QStringList>

#if SPEEDYNOTE_ENABLE_SDL
#include <QtMath>
#endif

#if SPEEDYNOTE_ENABLE_SDL

SDLControllerManager::SDLControllerManager(QObject *parent)
    : QObject(parent), pollTimer(new QTimer(this)) {

    // Load saved controller mappings or use defaults
    loadControllerMappings();

    connect(pollTimer, &QTimer::timeout, this, [=]() {
        SDL_PumpEvents();  // ✅ Update SDL input state

        // 🔁 Poll for axis movement (left stick)
        if (joystick) {
            // Use joystick axis instead of controller axis
            int x = SDL_JoystickGetAxis(joystick, 0); // Axis 0 = X
            int y = SDL_JoystickGetAxis(joystick, 1); // Axis 1 = Y

            const int DEADZONE = 16000;
            if (qAbs(x) >= DEADZONE || qAbs(y) >= DEADZONE) {
                float fx = x / 32768.0f;
                float fy = y / 32768.0f;

                float angle = qAtan2(-fy, fx) * 180.0 / M_PI;
                if (angle < 0) angle += 360;

                int angleInt = static_cast<int>(angle);

                // ✅ Invert angle for dial so clockwise = clockwise
                angleInt = (360 - angleInt) % 360;

                if (qAbs(angleInt - lastAngle) > 3) {
                    lastAngle = angleInt;
                    emit leftStickAngleChanged(angleInt);
                }
                leftStickActive = true;  // ✅ Mark stick as active
            }
            else {
                // Stick is in deadzone (center)
                if (leftStickActive) {
                    // ✅ Was active → now released → emit release signal once
                    emit leftStickReleased();
                    leftStickActive = false;
                }
            }
        }

        SDL_PumpEvents();

        // Check hold timer
        for (auto it = buttonPressTime.begin(); it != buttonPressTime.end(); ++it) {
            QString btn = it.key();
            quint32 pressTime = it.value();
            quint32 now = SDL_GetTicks();

            if (!buttonHeldEmitted.value(btn, false) && (now - pressTime) >= HOLD_THRESHOLD) {
                emit buttonHeld(btn);
                buttonHeldEmitted[btn] = true;
            }
        }

        // 🔁 Poll for button events using joystick API
        SDL_Event e;

        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_JOYBUTTONDOWN) {
                // In button detection mode, emit raw button info
                if (buttonDetectionMode) {
                    QString physicalName = getPhysicalButtonName(e.jbutton.button);
                    emit rawButtonPressed(e.jbutton.button, physicalName);
                    continue; // Don't process as normal button press
                }
                
                QString btnName = getLogicalButtonName(e.jbutton.button);
                if (!btnName.isEmpty()) {
                    buttonPressTime[btnName] = SDL_GetTicks();
                    buttonHeldEmitted[btnName] = false;
                }
            }
        
            if (e.type == SDL_JOYBUTTONUP) {
                // Skip processing in button detection mode
                if (buttonDetectionMode) {
                    continue;
                }
                
                QString btnName = getLogicalButtonName(e.jbutton.button);
                if (!btnName.isEmpty()) {
                    quint32 pressTime = buttonPressTime.value(btnName, 0);
                    quint32 now = SDL_GetTicks();
                    quint32 duration = now - pressTime;
            
                    if (duration < HOLD_THRESHOLD) {
                        emit buttonSinglePress(btnName);
                    } else {
                        emit buttonReleased(btnName);
                    }
            
                    buttonPressTime.remove(btnName);
                    buttonHeldEmitted.remove(btnName);
                }
            }
        }
    });
}

QString SDLControllerManager::getButtonName(int sdlButton) {
    // This method is now deprecated in favor of getLogicalButtonName
    return getLogicalButtonName(sdlButton);
}

QString SDLControllerManager::getLogicalButtonName(int sdlButton) {
    // Find which logical button this physical button is mapped to
    for (auto it = physicalButtonMappings.begin(); it != physicalButtonMappings.end(); ++it) {
        if (it.value() == sdlButton) {
            return it.key(); // Return the logical button name
        }
    }
    return QString(); // Return empty string if not mapped
}

QString SDLControllerManager::getPhysicalButtonName(int sdlButton) const {
    // Return human-readable names for physical SDL joystick buttons
    // Since we're using raw joystick buttons, we'll use generic names
    return QString("Button %1").arg(sdlButton);
}

QStringList SDLControllerManager::getAvailablePhysicalButtons() const {
    QStringList buttons;
    if (joystick) {
        int buttonCount = SDL_JoystickNumButtons(joystick);
        for (int i = 0; i < buttonCount; ++i) {
            buttons << getPhysicalButtonName(i);
        }
    } else {
        // If no joystick connected, show a reasonable range
        for (int i = 0; i < 20; ++i) {
            buttons << getPhysicalButtonName(i);
        }
    }
    return buttons;
}

int SDLControllerManager::getJoystickButtonCount() const {
    if (joystick) {
        return SDL_JoystickNumButtons(joystick);
    }
    return 0;
}

void SDLControllerManager::startButtonDetection() {
    buttonDetectionMode = true;
}

void SDLControllerManager::stopButtonDetection() {
    buttonDetectionMode = false;
}

SDLControllerManager::~SDLControllerManager() {
    if (joystick) SDL_JoystickClose(joystick);
    if (sdlInitialized) SDL_QuitSubSystem(SDL_INIT_JOYSTICK);
}

void SDLControllerManager::start() {
    if (!sdlInitialized) {
        if (SDL_InitSubSystem(SDL_INIT_JOYSTICK) != 0) {
            qWarning() << "Failed to initialize SDL joystick subsystem:" << SDL_GetError();
            return;
        }
        sdlInitialized = true;
    }

    SDL_JoystickEventState(SDL_ENABLE);  // ✅ Enable joystick events

    // Look for any available joystick
    int numJoysticks = SDL_NumJoysticks();
    
    for (int i = 0; i < numJoysticks; ++i) {
        const char* joystickName = SDL_JoystickNameForIndex(i);
        
        joystick = SDL_JoystickOpen(i);
        if (joystick) {
            break;
        }
    }

    if (!joystick) {
        qWarning() << "No joystick could be opened";
    }

    pollTimer->start(POLL_INTERVAL);
}

void SDLControllerManager::stop() {
    pollTimer->stop();
}

void SDLControllerManager::reconnect() {
    // Stop current polling
    pollTimer->stop();
    
    // Close existing joystick if open
    if (joystick) {
        SDL_JoystickClose(joystick);
        joystick = nullptr;
    }
    
    // Clear any cached state
    buttonPressTime.clear();
    buttonHeldEmitted.clear();
    lastAngle = -1;
    leftStickActive = false;
    buttonDetectionMode = false;
    
    // Re-initialize SDL joystick subsystem
    SDL_QuitSubSystem(SDL_INIT_JOYSTICK);
    if (SDL_InitSubSystem(SDL_INIT_JOYSTICK) != 0) {
        qWarning() << "Failed to re-initialize SDL joystick subsystem:" << SDL_GetError();
        sdlInitialized = false;
        return;
    }
    sdlInitialized = true;
    
    SDL_JoystickEventState(SDL_ENABLE);
    
    // Look for any available joystick
    int numJoysticks = SDL_NumJoysticks();
    
    for (int i = 0; i < numJoysticks; ++i) {
        const char* joystickName = SDL_JoystickNameForIndex(i);
        Q_UNUSED(joystickName);
        
        joystick = SDL_JoystickOpen(i);
        if (joystick) {
            break;
        }
    }
    
    if (!joystick) {
        qWarning() << "Reconnect: No joystick could be opened";
    }
    
    // Restart polling
    pollTimer->start(POLL_INTERVAL);
}

#else // SPEEDYNOTE_ENABLE_SDL

SDLControllerManager::SDLControllerManager(QObject *parent)
    : QObject(parent), pollTimer(new QTimer(this)) {
    loadControllerMappings();
}

SDLControllerManager::~SDLControllerManager() = default;

QString SDLControllerManager::getButtonName(int) {
    return QString();
}

QString SDLControllerManager::getLogicalButtonName(int) {
    return QString();
}

QString SDLControllerManager::getPhysicalButtonName(int sdlButton) const {
    Q_UNUSED(sdlButton);
    return QString();
}

QStringList SDLControllerManager::getAvailablePhysicalButtons() const {
    return {};
}

int SDLControllerManager::getJoystickButtonCount() const {
    return 0;
}

void SDLControllerManager::startButtonDetection() {
    buttonDetectionMode = true;
}

void SDLControllerManager::stopButtonDetection() {
    buttonDetectionMode = false;
}

void SDLControllerManager::start() {}

void SDLControllerManager::stop() {
    pollTimer->stop();
}

void SDLControllerManager::reconnect() {}

#endif // SPEEDYNOTE_ENABLE_SDL

void SDLControllerManager::setPhysicalButtonMapping(const QString &logicalButton, int physicalSDLButton) {
    physicalButtonMappings[logicalButton] = physicalSDLButton;
    saveControllerMappings();
}

int SDLControllerManager::getPhysicalButtonMapping(const QString &logicalButton) const {
    return physicalButtonMappings.value(logicalButton, -1);
}

QMap<QString, int> SDLControllerManager::getAllPhysicalMappings() const {
    return physicalButtonMappings;
}

QMap<QString, int> SDLControllerManager::getDefaultMappings() const {
    QMap<QString, int> defaults;
    defaults["LEFTSHOULDER"] = 4;
    defaults["RIGHTSHOULDER"] = 6;
    defaults["PADDLE2"] = 14;
    defaults["PADDLE4"] = 15;
    defaults["Y"] = 0;
    defaults["A"] = 1;
    defaults["B"] = 2;
    defaults["X"] = 3;
    defaults["LEFTSTICK"] = 10;
    defaults["START"] = 8;
    defaults["GUIDE"] = 13;
    return defaults;
}

void SDLControllerManager::saveControllerMappings() {
    QSettings settings("SpeedyNote", "App");
    settings.beginGroup("ControllerPhysicalMappings");
    for (auto it = physicalButtonMappings.begin(); it != physicalButtonMappings.end(); ++it) {
        settings.setValue(it.key(), it.value());
    }
    settings.endGroup();
}

void SDLControllerManager::loadControllerMappings() {
    QSettings settings("SpeedyNote", "App");
    settings.beginGroup("ControllerPhysicalMappings");
    QStringList keys = settings.allKeys();

    if (keys.isEmpty()) {
        physicalButtonMappings = getDefaultMappings();
        saveControllerMappings();
    } else {
        for (const QString &key : keys) {
            physicalButtonMappings[key] = settings.value(key).toInt();
        }
    }
    settings.endGroup();
}
