package app.banh.customer.data

/** State of data that a screen shows: not yet known, known, or not obtainable. */
sealed interface Load<out T> {
    data object Loading : Load<Nothing>

    data class Ready<out T>(val value: T) : Load<T>

    data class Failed(val failure: LoadFailure) : Load<Nothing>
}

/** Why data could not be obtained; the screens pick their message from it (UI document 5.10). */
enum class LoadFailure {
    /** No connection: the message names the network. */
    NETWORK,

    /** Any other cause: the screen's generic message. */
    OTHER,
}

inline fun <T, R> Load<T>.flatMap(transform: (T) -> Load<R>): Load<R> = when (this) {
    is Load.Ready -> transform(value)
    Load.Loading -> Load.Loading
    is Load.Failed -> this
}

inline fun <T, R> Load<T>.map(transform: (T) -> R): Load<R> = flatMap { Load.Ready(transform(it)) }
