package app.banh.customer.testing

import app.banh.customer.order.OrderFlowViewModel
import app.banh.customer.order.SubmitProblem
import app.banh.customer.order.SubmitState

/** The problem S-8 shows; fails the test when the send did not fail. */
fun OrderFlowViewModel.problem(): SubmitProblem = (state.value.submit as SubmitState.Failed).problem
