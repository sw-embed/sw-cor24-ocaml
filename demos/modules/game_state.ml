type room = Hall | Cave | Vault
let describe room = match room with Hall -> "hall" | Cave -> "cave" | Vault -> "vault"
let score room has_lamp = match room with Hall -> 1 | Cave -> if has_lamp then 10 else 2 | Vault -> if has_lamp then 50 else 5
