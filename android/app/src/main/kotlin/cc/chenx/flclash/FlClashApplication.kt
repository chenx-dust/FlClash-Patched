package cc.chenx.flclash

import android.app.Application
import android.content.Context
import cc.chenx.flclash.common.GlobalState

class FlClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
