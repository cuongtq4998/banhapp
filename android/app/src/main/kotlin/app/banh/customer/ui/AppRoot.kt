package app.banh.customer.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.banh.customer.R
import app.banh.customer.design.BanhTheme

// Empty shell: navigation, AppContainer and feature packages (ui/home, products, order,
// confirmation) are added slice by slice so no unused structure is carried.
@Composable
fun AppRoot() {
    BanhTheme {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = stringResource(R.string.shell_placeholder),
                style = MaterialTheme.typography.headlineLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
        }
    }
}
