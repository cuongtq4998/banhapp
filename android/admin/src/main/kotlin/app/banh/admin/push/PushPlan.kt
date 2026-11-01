package app.banh.admin.push

enum class PushStep { ASK, REGISTER, NOTHING }

/** Android 13 added the runtime permission for notifications. */
const val RUNTIME_PERMISSION_SDK = 33

/**
 * What to do right after a sign-in (FR-25, AC-42): when push is built in and the permission is granted, register the token; when it
 * was never asked, ask once; when it was refused, do nothing and show nothing. Before Android 13 there is no question.
 */
fun decidePush(available: Boolean, granted: Boolean, alreadyAsked: Boolean): PushStep = when {
    !available -> PushStep.NOTHING
    granted -> PushStep.REGISTER
    alreadyAsked -> PushStep.NOTHING
    else -> PushStep.ASK
}

/** Remembers that the permission question was shown, so it is shown once per phone. */
interface AskedFlag {
    var asked: Boolean
}

class MemoryAskedFlag(override var asked: Boolean = false) : AskedFlag
