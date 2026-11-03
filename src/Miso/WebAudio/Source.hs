module Miso.WebAudio.Source
  ( -- * Scheduling
    AudioSource
  , start
  , stop
  , onEnded
  , onEnded_
    -- * Oscillators
  , OscillatorNode (..)
  , Wave (..)
  , createOscillator
  , setOscillatorType
  , PeriodicWave (..)
  , createPeriodicWave
  , setPeriodicWave
    -- * Buffer sources
  , AudioBufferSourceNode (..)
  , createBufferSource
  , startAtOffset
  , startFor
  , setLoop
  , setLoopStart
  , setLoopEnd
  , playbackRate
    -- * Constant sources
  , ConstantSourceNode (..)
  , createConstantSource
  , offset
    -- * Shared parameters
  , HasFrequency
  , frequency
  , HasDetune
  , detune
  ) where

import Data.Foldable (traverse_)
import Miso.DSL (createWith, freeJSVal, setField, (#))
import Miso.Effect (Effect, withSink)
import Miso.String (MisoString)
import Miso.WebAudio.Internal (assignNumber, float32Of, invoke, invoke_, listenOnce, param)
import Miso.WebAudio.Note (Wave (..))
import Miso.WebAudio.Param (detune, frequency)
import Miso.WebAudio.Types
  ( AudioBufferSourceNode (..)
  , AudioParam
  , AudioSource
  , BaseAudioContext
  , ConstantSourceNode (..)
  , HasDetune
  , HasFrequency
  , OscillatorNode (..)
  , PeriodicWave (..)
  , releaseHandle
  )

start :: AudioSource source => source -> Double -> IO ()
start source at = invoke source "start" [at]

stop :: AudioSource source => source -> Double -> IO ()
stop source at = invoke source "stop" [at]

onEnded :: AudioSource source => source -> action -> Effect parent props model action
onEnded source action = withSink $ \sink -> onEnded_ source (sink action)

onEnded_ :: AudioSource source => source -> IO () -> IO ()
onEnded_ source action = listenOnce source "ended" (const action)

createOscillator :: BaseAudioContext context => context -> IO OscillatorNode
createOscillator context = OscillatorNode <$> (context # "createOscillator") ()

setOscillatorType :: OscillatorNode -> Wave -> IO ()
setOscillatorType oscillator = setField oscillator "type"

createPeriodicWave :: BaseAudioContext context => context -> [Double] -> [Double] -> Bool -> IO PeriodicWave
createPeriodicWave context real imaginary normalize = do
  realPart <- float32Of real
  imaginaryPart <- float32Of imaginary
  options <- createWith [("disableNormalization" :: MisoString, not normalize)]
  wave <- (context # "createPeriodicWave") (realPart, imaginaryPart, options)
  traverse_ freeJSVal [realPart, imaginaryPart]
  releaseHandle options
  pure (PeriodicWave wave)

setPeriodicWave :: OscillatorNode -> PeriodicWave -> IO ()
setPeriodicWave oscillator wave = invoke_ oscillator "setPeriodicWave" [wave]

createBufferSource :: BaseAudioContext context => context -> IO AudioBufferSourceNode
createBufferSource context = AudioBufferSourceNode <$> (context # "createBufferSource") ()

startAtOffset :: AudioBufferSourceNode -> Double -> Double -> IO ()
startAtOffset source at position = invoke source "start" [at, position]

startFor :: AudioBufferSourceNode -> Double -> Double -> Double -> IO ()
startFor source at position duration = invoke source "start" [at, position, duration]

setLoop :: AudioBufferSourceNode -> Bool -> IO ()
setLoop source = setField source "loop"

setLoopStart :: AudioBufferSourceNode -> Double -> IO ()
setLoopStart source = assignNumber source "loopStart"

setLoopEnd :: AudioBufferSourceNode -> Double -> IO ()
setLoopEnd source = assignNumber source "loopEnd"

playbackRate :: AudioBufferSourceNode -> IO AudioParam
playbackRate = param "playbackRate"

createConstantSource :: BaseAudioContext context => context -> IO ConstantSourceNode
createConstantSource context = ConstantSourceNode <$> (context # "createConstantSource") ()

offset :: ConstantSourceNode -> IO AudioParam
offset = param "offset"
