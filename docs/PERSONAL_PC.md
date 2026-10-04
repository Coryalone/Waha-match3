# Two launch modes

Run `PC-Personal.cmd` for the personal Chrome version on your computer.
Run `APK-Standard.cmd` to test and build the standard release APK.
Both launchers can be opened from Explorer or run from PowerShell.

The personal launcher creates a temporary web project, reads the same application
code, copies local images into that temporary project's assets, and removes the
temporary project when the game exits. It never modifies the main pubspec.

Put six transparent PNG images in `.local/tiles/`, named `0.png` through `5.png`.
Missing images fall back to the existing tile symbols. The artwork itself is not
included with these launch tools. Keep the original artwork in that local folder.
The entire `.local/` directory is ignored by Git; do not force-add it.

The ordinary application's asset list contains only its background audio.
Android always uses the standard symbols, including when the personal flag is
set accidentally. The APK launcher explicitly disables that flag and checks the
actual APK archive for personal directories and all bitmap/vector images in the
Flutter asset bundle. Android launcher icons under `res/` are allowed.

The release APK is written to `build/app/outputs/flutter-apk/app-release.apk`.
If standard tile images are added to the app later, update the APK asset check
deliberately so it can distinguish them from personal artwork.

