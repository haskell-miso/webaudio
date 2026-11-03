module Miso.WebAudio.Buffer
  ( -- * Types
    AudioBuffer (..)
  , HasBuffer
    -- * Construction
  , createBuffer
    -- * Loading
  , decodeAudioData
  , decodeAudioData_
  , fetchAudioBuffer
  , fetchAudioBuffer_
    -- * Samples
  , writeChannel
  , readChannel
    -- * Properties
  , bufferLength
  , numberOfChannels
  , bufferSampleRate
  , bufferDuration
    -- * Assignment
  , setBuffer
  ) where

import Control.Monad (join)
import Miso.DSL (freeJSVal, jsg1, setField, (#))
import Miso.Effect (Effect)
import Miso.FFI (ArrayBuffer (..))
import Miso.String (MisoString, ms)
import Miso.WebAudio.Internal (attempt, deliver, fill, numbersOf, readProperty, settled)
import Miso.WebAudio.Types (AudioBuffer (..), BaseAudioContext, HasBuffer)

createBuffer :: BaseAudioContext context => context -> Int -> Int -> Double -> IO AudioBuffer
createBuffer context channels frames rate = AudioBuffer <$> (context # "createBuffer") (channels, frames, rate)

decodeAudioData
  :: BaseAudioContext context
  => context
  -> ArrayBuffer
  -> (AudioBuffer -> action)
  -> (MisoString -> action)
  -> Effect parent props model action
decodeAudioData context bytes = deliver (decodeAudioData_ context bytes)

decodeAudioData_ :: BaseAudioContext context => context -> ArrayBuffer -> IO (Either MisoString AudioBuffer)
decodeAudioData_ context = attempt . decoded context

fetchAudioBuffer
  :: BaseAudioContext context
  => context
  -> MisoString
  -> (AudioBuffer -> action)
  -> (MisoString -> action)
  -> Effect parent props model action
fetchAudioBuffer context url = deliver (fetchAudioBuffer_ context url)

fetchAudioBuffer_ :: BaseAudioContext context => context -> MisoString -> IO (Either MisoString AudioBuffer)
fetchAudioBuffer_ context url = fmap join . attempt $ do
  response <- settled =<< jsg1 "fetch" url
  succeeded <- readProperty response "ok"
  if succeeded
    then do
      bytes <- settled =<< (response # "arrayBuffer") ()
      Right <$> decoded context (ArrayBuffer bytes)
    else do
      status <- readProperty response "status"
      pure (Left (url <> ": HTTP " <> ms (status :: Int)))

decoded :: BaseAudioContext context => context -> ArrayBuffer -> IO AudioBuffer
decoded context bytes = do
  promise <- (context # "decodeAudioData") [bytes]
  AudioBuffer <$> settled promise

writeChannel :: AudioBuffer -> Int -> [Double] -> IO ()
writeChannel buffer channel samples = do
  target <- (buffer # "getChannelData") [channel]
  fill target samples
  freeJSVal target

readChannel :: AudioBuffer -> Int -> IO [Double]
readChannel buffer channel = do
  samples <- (buffer # "getChannelData") [channel]
  values <- numbersOf samples
  freeJSVal samples
  pure values

bufferLength :: AudioBuffer -> IO Int
bufferLength buffer = readProperty buffer "length"

numberOfChannels :: AudioBuffer -> IO Int
numberOfChannels buffer = readProperty buffer "numberOfChannels"

bufferSampleRate :: AudioBuffer -> IO Double
bufferSampleRate buffer = readProperty buffer "sampleRate"

bufferDuration :: AudioBuffer -> IO Double
bufferDuration buffer = readProperty buffer "duration"

setBuffer :: HasBuffer node => node -> AudioBuffer -> IO ()
setBuffer node = setField node "buffer"
