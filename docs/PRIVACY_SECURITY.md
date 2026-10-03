# Privacy and Security Requirements

## MVP rule

The MVP must behave like a fully offline local game. It must not collect, transmit, sell, share, or infer personal data.

## Disallowed in MVP

- User accounts or registration.
- Backend/API calls.
- Analytics SDKs.
- Advertising SDKs.
- Tracking SDKs.
- Telemetry.
- Crash-reporting SDKs.
- Push notifications.
- Device identifiers or advertising identifiers.
- Location, contacts, camera, microphone, photo/media, or shared storage access.
- Accessibility Service, Device Administrator, VPN, or other special Android capabilities.
- Writes to Downloads, Documents, Pictures, Music, or other shared user folders.

## Android local test APK requirements

- No `android.permission.INTERNET` permission.
- No dangerous permissions.
- `android:allowBackup="false"`.
- `android:fullBackupContent="false"`.
- Only app-private local storage for saves.
- No exported activities except the required launcher activity.

## Dependency policy

Every added package must be reviewed before use:

1. Does it request or imply Android permissions?
2. Does it make network requests?
3. Does it collect device/user identifiers?
4. Does it include analytics, ads, telemetry, or crash reporting?
5. Can the feature be implemented without the dependency?

For MVP, prefer no runtime dependencies beyond Flutter itself.

## Pre-APK audit checklist

Before installing an APK on a main phone, verify:

- Permissions: no dangerous permissions.
- Internet: absent.
- Analytics/ads/tracking: absent.
- External/shared storage: absent.
- Backup: disabled.
- Exported components: only what Android requires for launch.
- Dependencies: reviewed.
- App behavior: works offline with airplane mode enabled.
