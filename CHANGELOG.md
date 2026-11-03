# Revision history for miso-webaudio

## 0.1.0.0

* Typed bindings to the Web Audio graph: every interface that can run on the main thread,
  except the obsolete `ScriptProcessorNode`, in one module per area and under their JS names.
* Calls that wait for the browser are `Effect`s with an `IO` variant suffixed `_`, and context
  state changes are a `Sub`.
* A note player that unlocks audio from its own gesture listener.
