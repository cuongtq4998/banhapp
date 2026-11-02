package app.banh.admin.ui.forms

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.owner.Problem

/** The `A_ERR_*` text of a problem; every message names its field (AC-40). [label] is the field's visible label. */
@Composable
fun problemText(label: String, problem: Problem): String = when (problem) {
    Problem.Required -> stringResource(R.string.a_err_required, label)
    is Problem.TooLong -> stringResource(R.string.a_err_too_long, label, problem.max)
    is Problem.Range -> stringResource(R.string.a_err_range_int, label, problem.min, problem.max)
    Problem.Phone -> stringResource(R.string.a_err_phone, label)
    Problem.MinAboveLimit -> stringResource(R.string.a_err_min_above_limit, label)
    Problem.Taken -> stringResource(R.string.a_err_cake_name_dup)
    Problem.EmailInvalid -> stringResource(R.string.a_err_email_invalid)
    Problem.SlotOrder -> stringResource(R.string.a_err_slot_order)
    Problem.SlotDuplicate -> stringResource(R.string.a_err_slot_dup)
    Problem.ImageRequired -> stringResource(R.string.a_err_img_required)
    Problem.ImageType -> stringResource(R.string.a_err_img_type)
    Problem.ImageSize -> stringResource(R.string.a_err_img_size)
    Problem.ImageRead -> stringResource(R.string.a_err_img_read)
}
