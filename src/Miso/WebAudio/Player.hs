module Miso.WebAudio.Player
  ( Player
  , newPlayer
  , playNotes
  , setMuted
  , closePlayer
  , scheduleNotes
  ) where

import Control.Monad (unless, void, when)
import Data.Foldable (for_, traverse_)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Miso.DSL (Function (..), JSVal, fromJSValUnchecked, freeFunction, global, isUndefined, jsg, now_ffi, syncCallback1, (!), (#))
import Miso.String (MisoString)
import Miso.WebAudio.Node
import Miso.WebAudio.Note

data Output = Output AudioContext GainNode
  deriving (Eq)

data Player = Player
  { playerVolume :: Double
  , playerOutput :: IORef (Maybe Output)
  , playerMuted :: IORef Bool
  , playerLastGesture :: IORef Double
  , playerListener :: IORef (Maybe Function)
  }
  deriving (Eq)

gestureEvents :: [MisoString]
gestureEvents = ["pointerdown", "pointerup", "mousedown", "touchend", "keydown", "click"]

startingGraceMs :: Double
startingGraceMs = 250

lowestGlide :: Double
lowestGlide = 0.001

fadeFloor :: Double
fadeFloor = 0.001

newPlayer :: Double -> IO Player
newPlayer volume = do
  output <- newIORef Nothing
  muted <- newIORef False
  lastGesture <- newIORef (-1 / 0)
  handler <- syncCallback1 (onGesture volume output muted lastGesture)
  listening <- not <$> (isUndefined =<< (global ! "addEventListener"))
  when listening $ for_ gestureEvents $ \event ->
    void ((global # "addEventListener") (event, handler, True))
  Player volume output muted lastGesture <$> newIORef (Just (Function handler))

onGesture :: Double -> IORef (Maybe Output) -> IORef Bool -> IORef Double -> JSVal -> IO ()
onGesture volume outputRef mutedRef lastGesture event = do
  unlocking <- canUnlock event
  when unlocking $ do
    writeIORef lastGesture =<< now_ffi
    traverse_ wake =<< ensureOutput volume outputRef mutedRef

canUnlock :: JSVal -> IO Bool
canUnlock event = do
  trusted <- fromJSValUnchecked =<< (event ! "isTrusted")
  if trusted then activationGranted else pure False

activationGranted :: IO Bool
activationGranted = do
  navigator <- jsg "navigator"
  activation <- navigator ! "userActivation"
  missing <- isUndefined activation
  if missing then pure True else fromJSValUnchecked =<< (activation ! "isActive")

ensureOutput :: Double -> IORef (Maybe Output) -> IORef Bool -> IO (Maybe Output)
ensureOutput volume outputRef mutedRef =
  readIORef outputRef >>= \case
    Just existing -> pure (Just existing)
    Nothing ->
      newAudioContext LatencyInteractive >>= \case
        Nothing -> pure Nothing
        Just context -> do
          master <- newGain context
          muted <- readIORef mutedRef
          applyLevel context master (if muted then 0 else volume)
          connect master =<< destination context
          let output = Output context master
          writeIORef outputRef (Just output)
          pure (Just output)

applyLevel :: AudioContext -> GainNode -> Double -> IO ()
applyLevel context master value = do
  level <- gain master
  now <- currentTime context
  setValueAt level value now
  releaseHandle level

wake :: Output -> IO ()
wake (Output context _) = do
  state <- contextState context
  when (state == Suspended || state == Interrupted) (resume context)

playNotes :: Player -> [Note] -> IO ()
playNotes _ [] = pure ()
playNotes player notes = do
  muted <- readIORef (playerMuted player)
  output <- readIORef (playerOutput player)
  unless muted $ for_ output $ \current@(Output context master) -> do
    state <- contextState context
    audible <- if state == Running then pure True else wake current >> startedRecently player
    when audible $ do
      now <- currentTime context
      scheduleNotes context master now notes

startedRecently :: Player -> IO Bool
startedRecently player = do
  stamp <- now_ffi
  lastGesture <- readIORef (playerLastGesture player)
  pure (stamp - lastGesture <= startingGraceMs)

setMuted :: Player -> Bool -> IO ()
setMuted player muted = do
  writeIORef (playerMuted player) muted
  output <- readIORef (playerOutput player)
  for_ output $ \(Output context master) ->
    applyLevel context master (if muted then 0 else playerVolume player)

closePlayer :: Player -> IO ()
closePlayer player = do
  listener' <- readIORef (playerListener player)
  for_ listener' $ \handler -> do
    listening <- not <$> (isUndefined =<< (global ! "removeEventListener"))
    when listening $ for_ gestureEvents $ \event ->
      void ((global # "removeEventListener") (event, unFunction handler, True))
    freeFunction handler
    writeIORef (playerListener player) Nothing
  output <- readIORef (playerOutput player)
  for_ output $ \(Output context _) -> close context
  writeIORef (playerOutput player) Nothing

scheduleNotes :: (BaseAudioContext context, AudioNode output) => context -> output -> Double -> [Note] -> IO ()
scheduleNotes context output now = traverse_ (scheduleNote context output now)

scheduleNote :: (BaseAudioContext context, AudioNode output) => context -> output -> Double -> Note -> IO ()
scheduleNote context output now note = do
  let start = now + max 0 (noteStart note)
  oscillator <- newOscillator context
  envelope <- newGain context
  setWave oscillator (noteWave note)
  pitch <- frequency oscillator
  setValueAt pitch (noteFrequency note) start
  for_ (noteFrequencyTo note) $ \(target, at) ->
    exponentialRampTo pitch (max lowestGlide target) (start + max 0 at)
  level <- gain envelope
  setValueAt level (noteGain note) start
  exponentialRampTo level fadeFloor (start + max 0 (noteGainFadeAt note))
  connect oscillator envelope
  connect envelope output
  startAt oscillator start
  stopAt oscillator (start + max 0 (noteStop note))
  releaseHandle pitch
  releaseHandle level
  releaseHandle envelope
  releaseHandle oscillator
