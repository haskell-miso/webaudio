# miso-webaudio

Web Audio for [miso](https://github.com/dmjio/miso), on the JS and WebAssembly backends. It
is written with `Miso.DSL` alone: no foreign imports, no `eval`, no flags.

There are two layers. `Miso.WebAudio` re-exports both.

- `Miso.WebAudio.Node` is typed bindings to the audio graph, for sounds you design.
- `Miso.WebAudio.Player` plays lists of `Note` values and takes care of starting audio.
  `Miso.WebAudio.Note` holds the pure note type and builds natively, so note lists can be
  tested without a browser.

## Notes

```haskell
main = do
  player <- newPlayer 0.4
  startApp defaultEvents (component model (update player) view)

update player Hit = io_ (playNotes player [Note Sine 0 440 (Just (880, 0.08)) 0.3 0.12 0.13])
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
  burst <- newBufferSource context
  setBuffer burst noise
  band <- newBiquadFilter context
  setFilterType band Bandpass
  bandFrequency <- frequency band
  setValue bandFrequency 2400
  level <- newGain context
  envelope <- gain level
  setValueAt envelope 0 t
  linearRampTo envelope 0.5 (t + 0.003)
  exponentialRampTo envelope 0.0001 (t + 0.053)
  connect burst band
  connect band level
  connect level output
  startAt burst t
```

Every interface on [MDN's list](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
that can run on the main thread is covered, apart from the obsolete `ScriptProcessorNode`:

| Area | Interfaces |
| --- | --- |
| Contexts and graph | `AudioContext`, `BaseAudioContext`, `OfflineAudioContext`, `OfflineAudioCompletionEvent` (through `onComplete`), `AudioNode`, `AudioParam`, `AudioParamMap` |
| Sources | `AudioScheduledSourceNode` (as the `AudioSource` class), `OscillatorNode`, `AudioBuffer`, `AudioBufferSourceNode`, `ConstantSourceNode`, `MediaElementAudioSourceNode`, `MediaStreamAudioSourceNode`, `MediaStreamTrackAudioSourceNode` |
| Effects | `GainNode`, `BiquadFilterNode`, `IIRFilterNode`, `WaveShaperNode`, `DynamicsCompressorNode`, `ConvolverNode`, `DelayNode`, `PeriodicWave` |
| Destinations | `AudioDestinationNode`, `MediaStreamAudioDestinationNode` |
| Analysis | `AnalyserNode`, `AudioPlaybackStats` |
| Channels | `ChannelSplitterNode`, `ChannelMergerNode` |
| Spatial | `PannerNode`, `StereoPannerNode`, `AudioListener` |
| Worklets | `AudioWorklet`, `AudioWorkletNode` |

`AudioWorkletProcessor` and `AudioWorkletGlobalScope` run on the audio thread, so a processor
has to be JavaScript. `addWorkletModule` loads it and `newAudioWorkletNode` creates its node.

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

To play a sample file:

```haskell
sample <- fetchAudioBuffer context "kick.wav"
source <- newBufferSource context
setBuffer source sample
connect source output
startAt source now
```

`decodeAudioData` does the same from bytes you already have. These functions wait for the
browser, so call them from `io` or a thread of your own, not from a `syncCallback`. If the
fetch or the decode fails they throw a `JSException` you can catch.

## Things to know

- **Only Chrome has run this.** Safari, iOS and Firefox are untested, including the
  `touchend` path. `newMediaStreamTrackSource` returns `Nothing` in Chrome, which has no such
  node, so only that path has run.
- **`await` is lazy on wasm.** `Miso.DSL.await` returns at once there, and only blocks and
  throws when you force its result. The functions here force it. Do the same in your own
  bindings.
- **Some features are not everywhere.** Check `hasCancelAndHold` and `hasSetSinkId` first.
  `playbackStats` returns `Nothing` where it is missing. Some browsers lack the listener's
  position and orientation params, so use `setListenerPosition` and `setListenerOrientation`
  there.
- **Set `setNormalize` before `setBuffer`.** A convolver reads it when the buffer is assigned.
- **JS exceptions cannot be caught from Haskell.** miso's method calls are unsafe foreign
  calls, so `try` does not see an exception thrown by a Web Audio call, on either backend.
  It ends the Haskell thread. Do not pass 0 to `exponentialRampTo`, negative times to
  anything, or an unconnected parameter to `disconnectParam`. `newAudioContext` returns
  `Nothing` when there is no constructor. It also returns `Nothing` when the constructor
  throws on the JS backend, but on wasm that exception escapes.
- **`onEnded` and `onComplete` leak on the JS backend with stock miso 1.14**, one callback per
  use, and so does `onStateChange` after you unsubscribe, because `freeFunction` does nothing
  there. The note player uses none of them.
- **Filling buffers is slow on wasm**: about 2.5 µs per sample against 0.03 µs on JS, so a
  two-second noise buffer takes about 240 ms. Reuse buffers. The analyser readings and
  `readChannel` build Haskell lists, so they cost about as much per value.
- **Names are short** (`q`, `gain`, `offset`, `attack`). Import the module qualified if they
  clash.
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
their signal in a live context. It then drives the player with real input events, with
Chrome's autoplay policy on.

```bash
nix develop .#ghcjs --command bash -c 'make update-js build-js check-js'
nix develop .#wasm --command bash -c 'make update-wasm build-wasm'
nix develop .#ghcjs --command make check-wasm
```

`check.mjs` needs Playwright. Set `WEBAUDIO_PW` to its `index.mjs` and `WEBAUDIO_BROWSER` to
a browser binary if they are not found on their own.
