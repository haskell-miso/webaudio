module Miso.WebAudio.Analyser
  ( -- * Types
    AnalyserNode (..)
    -- * Construction
  , createAnalyser
    -- * Configuration
  , fftSize
  , setFftSize
  , frequencyBinCount
  , setMinDecibels
  , setMaxDecibels
  , setSmoothingTimeConstant
    -- * Readings
  , getFloatTimeDomainData
  , getFloatFrequencyData
  , getByteTimeDomainData
  , getByteFrequencyData
  ) where

import Miso.DSL (JSVal, freeJSVal, setField, (#))
import Miso.String (MisoString)
import Miso.WebAudio.Internal (assignNumber, freshFloat32, freshUint8, invoke_, numbersOf, readProperty)
import Miso.WebAudio.Types (AnalyserNode (..), BaseAudioContext)

createAnalyser :: BaseAudioContext context => context -> IO AnalyserNode
createAnalyser context = AnalyserNode <$> (context # "createAnalyser") ()

fftSize :: AnalyserNode -> IO Int
fftSize node = readProperty node "fftSize"

setFftSize :: AnalyserNode -> Int -> IO ()
setFftSize node = setField node "fftSize"

frequencyBinCount :: AnalyserNode -> IO Int
frequencyBinCount node = readProperty node "frequencyBinCount"

setMinDecibels :: AnalyserNode -> Double -> IO ()
setMinDecibels node = assignNumber node "minDecibels"

setMaxDecibels :: AnalyserNode -> Double -> IO ()
setMaxDecibels node = assignNumber node "maxDecibels"

setSmoothingTimeConstant :: AnalyserNode -> Double -> IO ()
setSmoothingTimeConstant node = assignNumber node "smoothingTimeConstant"

analyserReading :: (Int -> IO JSVal) -> MisoString -> IO Int -> AnalyserNode -> IO [Double]
analyserReading freshArray method size node = do
  target <- freshArray =<< size
  invoke_ node method [target]
  values <- numbersOf target
  freeJSVal target
  pure values

getFloatTimeDomainData :: AnalyserNode -> IO [Double]
getFloatTimeDomainData node = analyserReading freshFloat32 "getFloatTimeDomainData" (fftSize node) node

getFloatFrequencyData :: AnalyserNode -> IO [Double]
getFloatFrequencyData node = analyserReading freshFloat32 "getFloatFrequencyData" (frequencyBinCount node) node

getByteTimeDomainData :: AnalyserNode -> IO [Double]
getByteTimeDomainData node = analyserReading freshUint8 "getByteTimeDomainData" (fftSize node) node

getByteFrequencyData :: AnalyserNode -> IO [Double]
getByteFrequencyData node = analyserReading freshUint8 "getByteFrequencyData" (frequencyBinCount node) node
