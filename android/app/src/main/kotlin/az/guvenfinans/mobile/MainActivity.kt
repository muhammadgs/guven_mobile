package az.guvenfinans.mobile

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity

/**
 * Hides Android's navigation bar so the app owns the full height of the screen.
 *
 * The bar is hidden, not merely drawn behind: a swipe up from the bottom edge
 * brings it back as a transient overlay and it slides away again on its own,
 * so it never permanently costs the layout the ~48dp it used to take from a
 * three-button phone.
 *
 * Done here rather than through `SystemChrome.setEnabledSystemUIMode` because
 * this app targets Android SDK 36, and from API 35 upwards Flutter pins the
 * mode to `edgeToEdge` and ignores every other `SystemUiMode` — with no way to
 * opt out at API 36. Edge-to-edge is about *drawing behind* the bars, though;
 * hiding them is a separate capability the platform still offers, and
 * `WindowInsetsController` reaches it directly.
 *
 * Only the navigation bar goes. The status bar stays, so the clock, signal and
 * battery remain where users expect them.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hideNavigationBar()
    }

    /**
     * Android restores the system bars whenever it takes the window back —
     * returning from the recents switcher, dismissing the soft keyboard, or
     * coming out of a permission dialog. Both hooks re-assert the hide; a
     * single call in [onCreate] would only survive until the first of those.
     */
    override fun onResume() {
        super.onResume()
        hideNavigationBar()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideNavigationBar()
    }

    private fun hideNavigationBar() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.apply {
                // Swipe from the edge shows the bar for a few seconds and then
                // lets it go, instead of leaving it up and resizing the app.
                systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsets.Type.navigationBars())
            }
        } else {
            // API 24–29 — `WindowInsetsController` arrived in API 30, and
            // `minSdk` here is 24. `IMMERSIVE_STICKY` is the old spelling of
            // the same transient-on-swipe behaviour.
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }
    }
}
