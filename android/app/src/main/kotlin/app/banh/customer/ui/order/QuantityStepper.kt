package app.banh.customer.ui.order

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.design.Sizes
import app.banh.customer.design.bodyStrong

/**
 * Chooses a quantity from 0 to [max]. Minus is off at 0 and plus is off at [max], silently: the upper bound is an
 * input-safety limit and has no message (UI document 5.5, ADR-0009). Both buttons are 48 dp wide and high.
 */
@Composable
fun QuantityStepper(
    productId: String,
    productName: String,
    quantity: Int,
    max: Int,
    onQuantityChange: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val valueDescription = stringResource(R.string.qty_value_a11y, productName, quantity)
    Row(
        modifier = modifier.background(MaterialTheme.colorScheme.primaryContainer, CircleShape),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StepButton(
            iconRes = R.drawable.ic_remove,
            description = stringResource(R.string.qty_dec_a11y, productName),
            enabled = quantity > 0,
            testTag = TestTags.orderQtyDecrease(productId),
            onClick = { onQuantityChange(quantity - 1) },
        )
        Text(
            text = quantity.toString(),
            style = MaterialTheme.typography.bodyStrong,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .widthIn(min = Sizes.touchTarget)
                .testTag(TestTags.orderQtyValue(productId))
                .semantics { contentDescription = valueDescription },
        )
        StepButton(
            iconRes = R.drawable.ic_add,
            description = stringResource(R.string.qty_inc_a11y, productName),
            enabled = quantity < max,
            testTag = TestTags.orderQtyIncrease(productId),
            onClick = { onQuantityChange(quantity + 1) },
        )
    }
}

@Composable
private fun StepButton(iconRes: Int, description: String, enabled: Boolean, testTag: String, onClick: () -> Unit) {
    IconButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.size(Sizes.touchTarget).testTag(testTag),
        colors = IconButtonDefaults.iconButtonColors(contentColor = MaterialTheme.colorScheme.onPrimaryContainer),
    ) {
        Icon(painter = painterResource(iconRes), contentDescription = description)
    }
}

