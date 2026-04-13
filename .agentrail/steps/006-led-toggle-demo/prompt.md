Create the target demo: interactive LED toggle driven by switch input.

Write an OCaml program that:
1. Reads the switch state
2. Sets the LED to match the switch
3. Optionally prints status via UART
4. Loops (using let rec for the event loop)

Example:
  let rec loop = fun u ->
    let s = switch () in
    set_led s;
    loop ()
  in loop ()

Run this on the emulator and verify LED behavior.
This is the final step of the phase1-embedded-io saga.
Create the demo program in tests/demo_led_toggle.ml.