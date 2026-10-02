package com.xopmc.galaxybridge.gallery

import android.app.Activity
import android.os.Bundle

class GalleryPermissionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (GalleryPermissions.hasFullAccess(this)) {
            finish()
            return
        }
        requestPermissions(GalleryPermissions.required(), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE) finish()
    }

    companion object {
        private const val REQUEST_CODE = 4_712
    }
}
