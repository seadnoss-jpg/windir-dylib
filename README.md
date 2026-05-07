# Windir Keygate `.dylib`

iOS license key protection tweak — inject into any `.ipa` to add keygate authentication.

## How it works

1. When the app opens, the dylib checks if a valid key is stored locally
2. If no key → shows the Windir keygate screen
3. User enters a key (generated from the Windir dashboard)
4. Key is validated against the Windir API → returns package type + time remaining
5. If valid → key is saved locally, **never asks again** until expiry
6. On expiry → keygate shows again automatically

## Setup before building

Open `Tweak.x` and replace this line with your deployed Windir dashboard URL:

```objc
static NSString *const kAPIBase = @"https://YOUR_REPLIT_DOMAIN/api";
```

## Build requirements

- macOS with Xcode
- [Theos](https://theos.dev/docs/installation) installed at `$THEOS`
- iOS 14+ SDK

## Build commands

```bash
# Build .deb package
make package

# Build + install on connected device (jailbroken)
make package install THEOS_DEVICE_IP=192.168.x.x
```

## Generated key format

```
WINDI-VIP-1M-XXXXXXXXXX
WINDI-STD-7D-XXXXXXXXXX
```

Keys are created and managed from the **Windir Admin Dashboard**.

## API endpoint used

```
POST /api/keys/validate
Body: { "key": "WINDI-VIP-...", "deviceId": "unique-device-uuid" }
Response: { "valid": true, "type": "VIP", "timeLeft": "28d 5h", "expiresAt": "..." }
```

## Links

- Telegram: [t.me/windirffx](https://t.me/windirffx)
- Discord: [discord.gg/4hsjpkWfa](https://discord.gg/4hsjpkWfa)
