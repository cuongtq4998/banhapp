package app.banh.admin.cakes

import app.banh.core.model.Cake

/** Active cakes first, then hidden ones, each by name (S-A7). Removed cakes never arrive (AC-34). */
fun sortedCakes(cakes: List<Cake>): List<Cake> = cakes.sortedWith(compareByDescending<Cake> { it.isActive }.thenBy { it.name.lowercase() })

/** The state a form starts in: edit mode knows whether this is the only cake on sale. */
fun initialCakeForm(cake: Cake?, all: List<Cake>) = CakeFormState(original = cake, onlyActive = cake != null && cake.isActive && all.count { it.isActive } == 1)
