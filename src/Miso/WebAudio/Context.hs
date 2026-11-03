module Miso.WebAudio.Context
  ( -- * Types
    BaseAudioContext
  , AudioContext (..)
  , OfflineAudioContext (..)
  , LatencyHint (..)
  , ContextState (..)
  , OutputTimestamp (..)
    -- * Construction
  , newAudioContext
  , newAudioContextAtRate
  , newOfflineAudioContext
    -- * Lifecycle
  , resume
  , suspend
  , close
  , contextState
  , contextStateSub
    -- * Offline rendering
  , startRendering
  , startRendering_
  , onComplete
  , onComplete_
  , offlineLength
  , suspendOfflineAt
  , suspendOfflineAt_
  , resumeOffline
    -- * Properties
  , currentTime
  , sampleRate
  , baseLatency
  , outputLatency
  , getOutputTimestamp
  , destination
    -- * Output device
  , hasSetSinkId
  , setSinkId
  , setSinkId_
  ) where

import Control.Exception (try)
import Control.Monad (join, void)
import Miso.DSL
  ( FromJSVal (fromJSValUnchecked)
  , Function (..)
  , JSException
  , JSVal
  , ToJSVal (toJSVal)
  , asyncCallback
  , createWith
  , freeFunction
  , freeJSVal
  , isNull
  , isUndefined
  , jsg
  , new
  , (!)
  , (#)
  )
import Miso.Effect (Effect, Sub, withSink)
import Miso.String (MisoString)
import Miso.Subscription.Util (createSub)
import Miso.WebAudio.Internal (attempt, deliver, hasMethod, invoke_, listenOnce, readProperty, settled, unavailable)
import Miso.WebAudio.Types
  ( AudioBuffer (..)
  , AudioContext (..)
  , AudioDestinationNode (..)
  , BaseAudioContext
  , ContextState (..)
  , LatencyHint (..)
  , OfflineAudioContext (..)
  , OutputTimestamp (..)
  )

constructorNamed :: [MisoString] -> IO (Maybe JSVal)
constructorNamed = \case
  [] -> pure Nothing
  name : rest -> do
    found <- jsg name
    missing <- (||) <$> isUndefined found <*> isNull found
    if missing then constructorNamed rest else pure (Just found)

constructContext :: [(MisoString, JSVal)] -> IO (Maybe AudioContext)
constructContext settings =
  constructorNamed ["AudioContext", "webkitAudioContext"] >>= \case
    Nothing -> pure Nothing
    Just constructor -> do
      options <- createWith settings
      created <- try (new constructor [options])
      pure $ case created of
        Left (_ :: JSException) -> Nothing
        Right context -> Just (AudioContext context)

newAudioContext :: LatencyHint -> IO (Maybe AudioContext)
newAudioContext hint = do
  latency <- toJSVal hint
  constructContext [("latencyHint", latency)]

newAudioContextAtRate :: LatencyHint -> Double -> IO (Maybe AudioContext)
newAudioContextAtRate hint rate = do
  latency <- toJSVal hint
  sampling <- toJSVal rate
  constructContext [("latencyHint", latency), ("sampleRate", sampling)]

newOfflineAudioContext :: Int -> Int -> Double -> IO OfflineAudioContext
newOfflineAudioContext channels frames rate = do
  constructor <- jsg "OfflineAudioContext"
  OfflineAudioContext <$> new constructor (channels, frames, rate)

resume :: AudioContext -> IO ()
resume context = invoke_ context "resume" ()

suspend :: AudioContext -> IO ()
suspend context = invoke_ context "suspend" ()

close :: AudioContext -> IO ()
close context = invoke_ context "close" ()

contextState :: BaseAudioContext context => context -> IO ContextState
contextState context = readProperty context "state"

contextStateSub
  :: BaseAudioContext context
  => context
  -> (ContextState -> action)
  -> Sub model action
contextStateSub context toAction sink = createSub acquire release sink
  where
    acquire = do
      callback <- asyncCallback (sink . toAction =<< contextState context)
      invoke_ context "addEventListener" ("statechange" :: MisoString, callback)
      pure callback
    release callback = do
      invoke_ context "removeEventListener" ("statechange" :: MisoString, callback)
      freeFunction (Function callback)

startRendering
  :: OfflineAudioContext
  -> (AudioBuffer -> action)
  -> (MisoString -> action)
  -> Effect parent props model action
startRendering context = deliver (startRendering_ context)

startRendering_ :: OfflineAudioContext -> IO (Either MisoString AudioBuffer)
startRendering_ context = attempt (AudioBuffer <$> (settled =<< (context # "startRendering") ()))

onComplete
  :: OfflineAudioContext
  -> (AudioBuffer -> action)
  -> Effect parent props model action
onComplete context toAction = withSink $ \sink -> onComplete_ context (sink . toAction)

onComplete_ :: OfflineAudioContext -> (AudioBuffer -> IO ()) -> IO ()
onComplete_ context action = listenOnce context "complete" $ \event ->
  action . AudioBuffer =<< event ! "renderedBuffer"

offlineLength :: OfflineAudioContext -> IO Int
offlineLength context = readProperty context "length"

suspendOfflineAt
  :: OfflineAudioContext
  -> Double
  -> action
  -> (MisoString -> action)
  -> Effect parent props model action
suspendOfflineAt context at successful =
  deliver (join (suspendOfflineAt_ context at)) (const successful)

suspendOfflineAt_ :: OfflineAudioContext -> Double -> IO (IO (Either MisoString ()))
suspendOfflineAt_ context at = do
  available <- hasMethod context "suspend"
  if available
    then do
      promise <- (context # "suspend") at
      pure (attempt (void (settled promise)))
    else pure (pure (unavailable "suspend"))

resumeOffline :: OfflineAudioContext -> IO ()
resumeOffline context = invoke_ context "resume" ()

currentTime :: BaseAudioContext context => context -> IO Double
currentTime context = readProperty context "currentTime"

sampleRate :: BaseAudioContext context => context -> IO Double
sampleRate context = readProperty context "sampleRate"

optionalNumber :: AudioContext -> MisoString -> IO Double
optionalNumber context property = do
  handle <- context ! property
  missing <- isUndefined handle
  value <- if missing then pure 0 else fromJSValUnchecked handle
  freeJSVal handle
  pure value

baseLatency :: AudioContext -> IO Double
baseLatency context = optionalNumber context "baseLatency"

outputLatency :: AudioContext -> IO Double
outputLatency context = optionalNumber context "outputLatency"

getOutputTimestamp :: AudioContext -> IO OutputTimestamp
getOutputTimestamp context = do
  stamp <- (context # "getOutputTimestamp") ()
  timestamp <- OutputTimestamp <$> readProperty stamp "contextTime" <*> readProperty stamp "performanceTime"
  freeJSVal stamp
  pure timestamp

destination :: BaseAudioContext context => context -> IO AudioDestinationNode
destination context = AudioDestinationNode <$> context ! "destination"

hasSetSinkId :: AudioContext -> IO Bool
hasSetSinkId context = hasMethod context "setSinkId"

setSinkId
  :: AudioContext
  -> MisoString
  -> action
  -> (MisoString -> action)
  -> Effect parent props model action
setSinkId context device successful =
  deliver (setSinkId_ context device) (const successful)

setSinkId_ :: AudioContext -> MisoString -> IO (Either MisoString ())
setSinkId_ context device = do
  available <- hasSetSinkId context
  if available
    then attempt $ do
      promise <- (context # "setSinkId") device
      void (settled promise)
    else pure (unavailable "setSinkId")
