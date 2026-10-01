class_name Elements
extends RefCounted
## Triangle des éléments de CREOS.
## Feu > Nature > Eau > Feu. Lumière et Ombre se battent mutuellement.

const ADVANTAGE := 1.30
const DISADVANTAGE := 0.75

const BEATS := {
	"feu": "nature",
	"nature": "eau",
	"eau": "feu",
	"lumiere": "ombre",
	"ombre": "lumiere",
}


## Multiplicateur de dégâts quand `attacker` frappe `defender`.
static func multiplier(attacker: String, defender: String) -> float:
	if BEATS.get(attacker, "") == defender:
		return ADVANTAGE
	# Lumière/Ombre : pas de désavantage, seulement un avantage mutuel.
	if BEATS.get(defender, "") == attacker and attacker in ["feu", "nature", "eau"]:
		return DISADVANTAGE
	return 1.0
