# miso-webaudio

Web Audio for [miso](https://github.com/dmjio/miso).

There are two layers. `Miso.WebAudio` re-exports both.

- The graph modules are typed bindings to Web Audio, for sounds you design. There is one
  module per area, and functions keep their JS names, so MDN can be searched directly.
- `Miso.WebAudio.Player` plays lists of `Note` values and takes care of starting audio.
  `Miso.WebAudio.Note` holds the note type, so note lists can be tested without a browser.

## Notes

```haskell
main = do
  player <- newPlayer 0.4
  startApp defaultEvents (component initialModel (updateModel player) viewModel)

updateModel player Hit = io_ (playNotes player [Note Sine 0 440 (Just (880, 0.08)) 0.3 0.12 0.13])
```

A `Note` is one oscillator and one gain:

| Field | Meaning |
| --- | --- |
| `noteWave` | oscillator shape |
| `noteStart` | seconds after the call |
| `noteFrequency` | starting pitch in Hz |
| `noteFrequencyTo` | optional exponential glide: target Hz, seconds after the note starts |
| `noteGain` | starting gain |
| `noteGainFadeAt` | seconds after the note starts when the gain has faded out |
| `noteStop` | seconds after the note starts when the oscillator stops |

A glide target of zero or below is raised to 0.001 Hz, because Web Audio cannot ramp to
zero. Negative times count as zero.

`newPlayer` adds its own listeners for `pointerdown`, `pointerup`, `mousedown`, `touchend`,
`keydown` and `click`. The first one that grants user activation creates the `AudioContext`
on the event's own stack, and any later one resumes a suspended context. Effects in `update`
run later, so a resume from there could miss what a browser counts as a gesture. Synthetic
events, and real ones that grant no activation such as Escape, are ignored.

- Before the first gesture, notes are dropped.
- For 250 ms after a gesture, notes are kept while the context starts up.
- If a context stays suspended past that, notes are dropped rather than saved up to all
  sound at once on resume.
- While muted, notes are not scheduled, and notes already sounding are silenced.

`closePlayer` removes the listeners and closes the context. `scheduleNotes` puts notes on
any context and output node, which is how you render them offline.

## Nodes

```haskell
knock :: (BaseAudioContext context, AudioNode output) => context -> output -> AudioBuffer -> Double -> IO ()
knock context output noise t = do
  burst <- createBufferSource context
  setBuffer burst noise
  band <- createBiquadFilter context
  setFilterType band Bandpass
  bandFrequency <- frequency band
  setValue bandFrequency 2400
  level <- createGain context
  envelope <- gain level
  setValueAtTime envelope 0 t
  linearRampToValueAtTime envelope 0.5 (t + 0.003)
  exponentialRampToValueAtTime envelope 0.0001 (t + 0.053)
  connect burst band
  connect band level
  connect level output
  start burst t
```

Every interface on [MDN's list](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
that can run on the main thread is covered, apart from the obsolete `ScriptProcessorNode`:

| Module | Interfaces |
| --- | --- |
| `Miso.WebAudio.Context` | `AudioContext`, `BaseAudioContext`, `OfflineAudioContext`, `OfflineAudioCompletionEvent` (through `onComplete`) |
| `Miso.WebAudio.Node` | `AudioNode`, `AudioDestinationNode` |
| `Miso.WebAudio.Param` | `AudioParam` |
| `Miso.WebAudio.Buffer` | `AudioBuffer` |
| `Miso.WebAudio.Source` | `AudioScheduledSourceNode` (as the `AudioSource` class), `OscillatorNode`, `PeriodicWave`, `AudioBufferSourceNode`, `ConstantSourceNode` |
| `Miso.WebAudio.Media` | `MediaElementAudioSourceNode`, `MediaStreamAudioSourceNode`, `MediaStreamTrackAudioSourceNode`, `MediaStreamAudioDestinationNode` |
| `Miso.WebAudio.Filter` | `GainNode`, `BiquadFilterNode`, `IIRFilterNode`, `WaveShaperNode`, `DynamicsCompressorNode`, `ConvolverNode`, `DelayNode` |
| `Miso.WebAudio.Analyser` | `AnalyserNode` |
| `Miso.WebAudio.Stats` | `AudioPlaybackStats` |
| `Miso.WebAudio.Channel` | `ChannelSplitterNode`, `ChannelMergerNode` |
| `Miso.WebAudio.Spatial` | `PannerNode`, `StereoPannerNode`, `AudioListener` |
| `Miso.WebAudio.Worklet` | `AudioWorklet`, `AudioWorkletNode`, `AudioParamMap` |

`Miso.WebAudio.Types` holds the handles, classes and enums. `AudioWorkletProcessor` and
`AudioWorkletGlobalScope` run on the audio thread, so a processor has to be JavaScript.
`addModule` loads it and `newAudioWorkletNode` creates its node.

Configuration properties are set-only unless reading them is useful. Not bound: node
constructors such as `new GainNode(context)` (the factory methods are), `AudioNode.context`,
`copyFromChannel` and `copyToChannel` (use `writeChannel` and `readChannel`), `sinkId`,
`renderQuantumSize`, the context `error` and worklet `processorerror` events, and the panner's
deprecated `setPosition` and `setOrientation`.

Node types and `AudioParam` are newtypes over `JSVal` with their constructors exported, so
you can bind anything else with `Miso.DSL`:

```haskell
newtype Ramp = Ramp JSVal
  deriving (ToJSVal, ToObject)

instance AudioNode Ramp

speed :: Ramp -> IO AudioParam
speed node = AudioParam <$> node ! "speed"
```

Build a whole graph against `BaseAudioContext`, and the same code runs live and through
`newOfflineAudioContext` and `startRendering`.

## In an app

Calls that wait for the browser are `Effect`s that take a success action and an error action,
like `Miso.Cookie` and `Miso.Navigator`. Events that keep firing are `Sub`s:

```haskell
updateModel :: AudioContext -> Action -> Effect parent props model Action
updateModel context = \case
  LoadKick -> fetchAudioBuffer context "kick.wav" KickLoaded LoadFailed
  KickLoaded sample -> io_ $ do
    source <- createBufferSource context
    setBuffer source sample
    connect source =<< destination context
    start source =<< currentTime context
  LoadFailed message -> io_ (consoleError message)
  StateChanged _ -> pure ()

app context = (component initialModel (updateModel context) viewModel)
  { subs = [contextStateSub context StateChanged]
  }
```

| `Effect` | `IO` variant |
| --- | --- |
| `startRendering` | `startRendering_` |
| `decodeAudioData` | `decodeAudioData_` |
| `fetchAudioBuffer` | `fetchAudioBuffer_` |
| `addModule` | `addModule_` |
| `setSinkId` | `setSinkId_` |
| `suspendOfflineAt` | `suspendOfflineAt_` |
| `onEnded` | `onEnded_` |
| `onComplete` | `onComplete_` |

The `IO` variants block and return `Either MisoString`, so call them from `io` or a thread of
your own, not from a `syncCallback`. `suspendOfflineAt_` registers the suspend at once and
returns the wait as an action, so it can be set up before rendering starts. The `Effect` form
registers it on a forked thread, so use `suspendOfflineAt_` when its order against
`startRendering` matters. `onEnded_` and `onComplete_` take a callback and do not block.

Everything else is plain `IO`, which you run with `io_`, as with `Miso.Media`. That includes
`resume`, `suspend` and `close`, which do not wait for the browser.

The graph takes miso's own types where they exist. `createMediaElementSource` takes a `Media`,
`createMediaStreamSource` takes a `Stream` from `getUserMedia`, `destinationStream` returns a
`Stream` for `srcObject`, and `decodeAudioData` takes the `ArrayBuffer` in the `Response` that
`Miso.Fetch.getArrayBuffer` gives you.

## Things to know

- **Only Chrome has run this.** Safari, iOS and Firefox are untested, including the
  `touchend` path. `createMediaStreamTrackSource` returns `Nothing` in Chrome, which has no such
  node, so only that path has run.
- **`await` is lazy on wasm.** `Miso.DSL.await` returns at once there, and only blocks and
  throws when you force its result. The functions here force it. Do the same in your own
  bindings.
- **Some features are not everywhere.** Check `hasCancelAndHold` first. `setSinkId`, `addModule`
  and `suspendOfflineAt` give their error action, or a `Left`, where they are missing, and
  `hasSetSinkId` tells you ahead of time. `playbackStats` returns `Nothing` where it is missing. Some browsers lack the listener's
  position and orientation params, so use `setListenerPosition` and `setListenerOrientation`
  there.
- **Set `setNormalize` before `setBuffer`.** A convolver reads it when the buffer is assigned.
- **JS exceptions cannot be caught from Haskell.** miso's method calls are unsafe foreign
  calls, so `try` does not see an exception thrown by a Web Audio call, on either backend.
  It ends the Haskell thread. Do not pass 0 to `exponentialRampToValueAtTime`, negative times
  to anything, or an unconnected parameter to `disconnectParam`. `newAudioContext` returns
  `Nothing` when there is no constructor. It also returns `Nothing` when the constructor
  throws on the JS backend, but on wasm that exception escapes. A rejected promise is
  different: it arrives as the error action, or as a `Left`, and so does an HTTP error status
  from `fetchAudioBuffer`.
- **Cross-origin media is silent without CORS.** A media element from another origin feeds
  silence into the graph unless the server sends CORS headers and the element asks for them.
- **`onEnded` and `onComplete` leak on the JS backend with stock miso 1.14**, one callback per
  use, and so does `contextStateSub` after it stops, because `freeFunction` does nothing
  there. The note player uses none of them.
- **Filling buffers is slow on wasm**: about 2.5 µs per sample against 0.03 µs on JS, so a
  two-second noise buffer takes about 240 ms. Reuse buffers. The analyser readings and
  `readChannel` build Haskell lists, so they cost about as much per value.
- **Some names clash**: `offset` and `setValue` with `Miso`, `onEnded` with `Miso.Html`,
  `currentTime` and `playbackRate` with `Miso.Media`. Others are short (`q`, `gain`, `attack`).
  Import the module qualified if they get in the way.
- **Handles on wasm** carry a finalizer. `releaseHandle` frees one early. It frees only the
  Haskell handle, and you must not use it afterwards.

## Cost

Measured in Chrome on one laptop, per call:

| | JS backend | wasm |
| --- | --- | --- |
| one `Note` | about 20 µs | 50–75 µs |
| one voice of 3 oscillators, 3 gains and a filter | about 50 µs | 120–215 µs |

## Checks

`test/browser` renders graphs through this package and through raw Web Audio in an
`OfflineAudioContext` and compares them sample by sample, and does the same for analyser
readings and frequency responses. It checks media streams and media elements by measuring
their signal in a live context. It runs the `Effect` and `Sub` forms the way the runtime does,
on forked threads, but not inside a mounted component. It then drives the player with real
input events, with Chrome's autoplay policy on.

```bash
nix develop .#ghcjs --command bash -c 'make update-js build-js check-js'
nix develop .#wasm --command bash -c 'make update-wasm build-wasm'
nix develop .#ghcjs --command make check-wasm
```

`check.mjs` needs Playwright. Set `WEBAUDIO_PW` to its `index.mjs` and `WEBAUDIO_BROWSER` to
a browser binary if they are not found on their own.
