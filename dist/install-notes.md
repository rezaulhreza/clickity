### Installing

Clickity isn't notarized by Apple yet, so macOS blocks the first launch. You only do this once;
later versions install themselves through the app's updater.

1. Download the **.dmg** below and open it.
2. Drag **Clickity** onto **Applications**.
3. Open Clickity from Applications. macOS says it can't verify the app: click **Done**, not
   *Move to Trash*.
4. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click
   **Open Anyway** next to *"Clickity" was blocked*. Enter your password, then click
   **Open Anyway** again.
5. Clickity appears in the menu bar. Allow **Screen Recording** when asked, then quit and reopen it.

Prefer Terminal? After step 2, run this instead of steps 3–4:

```sh
xattr -dr com.apple.quarantine /Applications/Clickity.app && open /Applications/Clickity.app
```

**Already installed?** Use **Settings → General → Check for Updates…** instead of downloading.
