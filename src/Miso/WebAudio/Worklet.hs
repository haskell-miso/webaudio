module Miso.WebAudio.Worklet
  ( -- * Modules
    addModule
  , addModule_
    -- * Nodes
  , AudioWorkletNode (..)
  , newAudioWorkletNode
  , newAudioWorkletNodeWith
  , workletPort
    -- * Parameters
  , AudioParamMap (..)
  , workletParameters
  , lookupParam
  , paramNames
  ) where

import Control.Monad (void)
import Data.Foldable (traverse_)
import Miso.DSL (FromJSVal (fromJSValUnchecked), JSVal, ToJSVal, create, freeJSVal, isUndefined, jsg, new, (!), (#))
import Miso.Effect (Effect)
import Miso.String (MisoString)
import Miso.WebAudio.Internal (attempt, deliver, hasMethod, settled, unavailable)
import Miso.WebAudio.Types (AudioParam (..), AudioParamMap (..), AudioWorkletNode (..), BaseAudioContext)

addModule
  :: BaseAudioContext context
  => context
  -> MisoString
  -> action
  -> (MisoString -> action)
  -> Effect parent props model action
addModule context url successful =
  deliver (addModule_ context url) (const successful)

addModule_ :: BaseAudioContext context => context -> MisoString -> IO (Either MisoString ())
addModule_ context url = do
  available <- hasMethod context "audioWorklet"
  if available
    then attempt $ do
      worklet <- context ! "audioWorklet"
      promise <- (worklet # "addModule") url
      freeJSVal worklet
      void (settled promise)
    else pure (unavailable "audioWorklet")

newAudioWorkletNode :: BaseAudioContext context => context -> MisoString -> IO AudioWorkletNode
newAudioWorkletNode context name = newAudioWorkletNodeWith context name =<< create

newAudioWorkletNodeWith :: (BaseAudioContext context, ToJSVal options) => context -> MisoString -> options -> IO AudioWorkletNode
newAudioWorkletNodeWith context name options = do
  constructor <- jsg "AudioWorkletNode"
  AudioWorkletNode <$> new constructor (context, name, options)

workletPort :: AudioWorkletNode -> IO JSVal
workletPort node = node ! "port"

workletParameters :: AudioWorkletNode -> IO AudioParamMap
workletParameters node = AudioParamMap <$> node ! "parameters"

lookupParam :: AudioParamMap -> MisoString -> IO (Maybe AudioParam)
lookupParam parameters name = do
  found <- (parameters # "get") name
  missing <- isUndefined found
  pure (if missing then Nothing else Just (AudioParam found))

paramNames :: AudioParamMap -> IO [MisoString]
paramNames parameters = do
  keys <- (parameters # "keys") ()
  arrayClass <- jsg "Array"
  names <- (arrayClass # "from") [keys]
  values <- fromJSValUnchecked names
  traverse_ freeJSVal [keys, arrayClass, names]
  pure values
