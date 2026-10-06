package com.generalsx.zerohour;

import android.content.Context;
import android.content.Intent;
import android.net.wifi.WifiManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.Settings;

import org.libsdl.app.SDLActivity;

/**
 * Launcher activity for the native Zero Hour port.
 *
 * SDLActivity does all the work: it creates the surface, forwards touch/keys/
 * lifecycle to SDL3, then loads the libraries below in order and calls SDL_main
 * (GeneralsMD/Code/Main/SDL3Main.cpp) on its own thread. DXVK's libdxvk_d3d8.so /
 * libdxvk_d3d9.so are not listed: the engine dlopen()s them itself at D3D init.
 *
 * No libc++_shared: the engine replaces global operator new/delete with its own
 * pool allocator, so libc++ is linked statically into each .so (ANDROID_STL=c++_static).
 * A shared libc++ would keep allocating with malloc while engine code frees with the
 * pool allocator (heap corruption; the first on-device crash, 04/10/2026).
 */
public class GeneralsActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL3",
            "SDL3_image",
            "openal",
            "gamespy",
            "main"
        };
    }

    // LAN lobby discovery is UDP broadcast; Android Wi-Fi drops incoming broadcast and
    // multicast packets (power saving) unless a MulticastLock is held.
    private WifiManager.MulticastLock multicastLock;

    @Override
    protected void onDestroy() {
        if (multicastLock != null && multicastLock.isHeld()) {
            multicastLock.release();
        }
        super.onDestroy();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        WifiManager wifi = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wifi != null) {
            multicastLock = wifi.createMulticastLock("GeneralsZH-LAN");
            multicastLock.setReferenceCounted(false);
            multicastLock.acquire();
        }
        // The game data folder (/storage/emulated/0/GeneralsZH) holds non-media files,
        // readable only with All-files access on Android 11+. Send the player to the
        // toggle once; the native side explains what to do if the files stay unreadable.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
            Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                       Uri.parse("package:" + getPackageName()));
            try {
                startActivity(intent);
            } catch (android.content.ActivityNotFoundException e) {
                startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
            }
        }
    }
}
