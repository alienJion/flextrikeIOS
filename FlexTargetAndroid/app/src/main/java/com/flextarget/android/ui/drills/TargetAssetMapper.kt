package com.flextarget.android.ui.drills

/**
 * Maps target types to live target image asset names
 */
object TargetAssetMapper {
    fun getTargetImageAssetName(targetType: String): String {
        return when (targetType.lowercase()) {
            "ipsc" -> "ipsc.live.target"
            "hostage" -> "hostage.live.target"
            "popper" -> "popper.live.target"
            "paddle" -> "paddle.live.target"
            "special_1" -> "ipsc.special.1.live.target"
            "special_2" -> "ipsc.special.2.live.target"
            "rotation" -> "rotation.live.target"
            "cqb_front" -> "cqb_front.live.target"
            "cqb_hostage" -> "cqb_hostage.live.target"
            "cqb_move" -> "cqb_move.live.target"
            "cqb_swing" -> "cqb_swing.live.target"
            "idpa" -> "idpa.live.target"
            "disguised_enemy" -> "disguised_enemy.live.target"
            else -> "ipsc.live.target" // Default fallback
        }
    }
}
