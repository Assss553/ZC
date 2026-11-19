package com.rox.tv

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.TextView

object Ui {
    const val ORANGE = 0xFFFF7A00.toInt()
    var sizeSp = 30f
    var alpha = 0.78f

    fun subtitleView(ctx: Context) = TextView(ctx).apply {
        setTextColor(Color.WHITE)
        textSize = sizeSp
        typeface = Typeface.create("sans-serif", Typeface.BOLD)
        gravity = Gravity.CENTER
        textDirection = View.TEXT_DIRECTION_RTL
        setPadding(36, 18, 36, 18)
        maxWidth = (ctx.resources.displayMetrics.widthPixels * 0.85f).toInt()
        background = GradientDrawable().apply { cornerRadius = 22f; setColor(Color.argb((alpha * 255).toInt(), 0, 0, 0)); setStroke(3, ORANGE) }
        visibility = View.GONE
    }

    fun applyText(v: TextView, text: String) {
        v.textSize = sizeSp
        (v.background as? GradientDrawable)?.setColor(Color.argb((alpha * 255).toInt(), 0, 0, 0))
        v.text = text
        v.visibility = if (text.isBlank()) View.GONE else View.VISIBLE
    }
}
