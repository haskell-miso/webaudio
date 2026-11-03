module Miso.WebAudio.Filter
  ( -- * Gain
    GainNode (..)
  , createGain
  , HasGain
  , gain
    -- * Biquad filters
  , BiquadFilterNode (..)
  , FilterType (..)
  , createBiquadFilter
  , setFilterType
  , q
  , HasFrequency
  , frequency
  , HasDetune
  , detune
    -- * IIR filters
  , IIRFilterNode (..)
  , createIIRFilter
    -- * Frequency response
  , HasFrequencyResponse
  , getFrequencyResponse
    -- * Wave shapers
  , WaveShaperNode (..)
  , Oversample (..)
  , createWaveShaper
  , setCurve
  , setOversample
    -- * Compressors
  , DynamicsCompressorNode (..)
  , createDynamicsCompressor
  , threshold
  , knee
  , ratio
  , attack
  , release
  , reduction
    -- * Convolvers
  , ConvolverNode (..)
  , createConvolver
  , setNormalize
    -- * Delays
  , DelayNode (..)
  , createDelay
  , delayTime
  ) where

import Data.Foldable (traverse_)
import Miso.DSL (freeJSVal, setField, (#))
import Miso.WebAudio.Internal (float32Of, freshFloat32, invoke_, numbersOf, param, readProperty)
import Miso.WebAudio.Param (detune, frequency, gain)
import Miso.WebAudio.Types
  ( AudioParam
  , BaseAudioContext
  , BiquadFilterNode (..)
  , ConvolverNode (..)
  , DelayNode (..)
  , DynamicsCompressorNode (..)
  , FilterType (..)
  , GainNode (..)
  , HasDetune
  , HasFrequency
  , HasFrequencyResponse
  , HasGain
  , IIRFilterNode (..)
  , Oversample (..)
  , WaveShaperNode (..)
  )

createGain :: BaseAudioContext context => context -> IO GainNode
createGain context = GainNode <$> (context # "createGain") ()

createBiquadFilter :: BaseAudioContext context => context -> IO BiquadFilterNode
createBiquadFilter context = BiquadFilterNode <$> (context # "createBiquadFilter") ()

setFilterType :: BiquadFilterNode -> FilterType -> IO ()
setFilterType node = setField node "type"

q :: BiquadFilterNode -> IO AudioParam
q = param "Q"

createIIRFilter :: BaseAudioContext context => context -> [Double] -> [Double] -> IO IIRFilterNode
createIIRFilter context feedforward feedback = IIRFilterNode <$> (context # "createIIRFilter") (feedforward, feedback)

getFrequencyResponse :: HasFrequencyResponse node => node -> [Double] -> IO [(Double, Double)]
getFrequencyResponse node frequencies = do
  hertz <- float32Of frequencies
  magnitudes <- freshFloat32 (length frequencies)
  phases <- freshFloat32 (length frequencies)
  invoke_ node "getFrequencyResponse" (hertz, magnitudes, phases)
  response <- zip <$> numbersOf magnitudes <*> numbersOf phases
  traverse_ freeJSVal [hertz, magnitudes, phases]
  pure response

createWaveShaper :: BaseAudioContext context => context -> IO WaveShaperNode
createWaveShaper context = WaveShaperNode <$> (context # "createWaveShaper") ()

setCurve :: WaveShaperNode -> [Double] -> IO ()
setCurve shaper samples = do
  curve <- float32Of samples
  setField shaper "curve" curve
  freeJSVal curve

setOversample :: WaveShaperNode -> Oversample -> IO ()
setOversample shaper = setField shaper "oversample"

createDynamicsCompressor :: BaseAudioContext context => context -> IO DynamicsCompressorNode
createDynamicsCompressor context = DynamicsCompressorNode <$> (context # "createDynamicsCompressor") ()

threshold :: DynamicsCompressorNode -> IO AudioParam
threshold = param "threshold"

knee :: DynamicsCompressorNode -> IO AudioParam
knee = param "knee"

ratio :: DynamicsCompressorNode -> IO AudioParam
ratio = param "ratio"

attack :: DynamicsCompressorNode -> IO AudioParam
attack = param "attack"

release :: DynamicsCompressorNode -> IO AudioParam
release = param "release"

reduction :: DynamicsCompressorNode -> IO Double
reduction node = readProperty node "reduction"

createConvolver :: BaseAudioContext context => context -> IO ConvolverNode
createConvolver context = ConvolverNode <$> (context # "createConvolver") ()

setNormalize :: ConvolverNode -> Bool -> IO ()
setNormalize node = setField node "normalize"

createDelay :: BaseAudioContext context => context -> Double -> IO DelayNode
createDelay context longest = DelayNode <$> (context # "createDelay") longest

delayTime :: DelayNode -> IO AudioParam
delayTime = param "delayTime"
