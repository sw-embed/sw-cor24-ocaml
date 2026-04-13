Add COR24 board I/O primitives to the evaluator.

Add built-in functions:
  set_led : bool -> unit    (write LED state)
  switch : unit -> bool     (read switch)
  led_on : unit -> unit     (convenience)
  led_off : unit -> unit    (convenience)

Implementation:
- In the evaluator, recognize these names like print_int
- For set_led: use Pascal's LedOn/LedOff from the Hardware unit,
  or use poke() to write to the LED MMIO address
- For switch: use ReadSwitch or peek() to read the switch MMIO address
- For led_on/led_off: call set_led true / set_led false

Test on emulator: let _ = led_on () in print_int 1  outputs 1 with LED on
Update src/ocaml.pas, rebuild, create reg-rs baselines.