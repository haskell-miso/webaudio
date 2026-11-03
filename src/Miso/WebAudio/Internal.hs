module Miso.WebAudio.Internal
  ( -- * Promises
    settled
  , attempt
  , deliver
  , unavailable
    -- * Calls
  , invoke
  , invoke_
  , readProperty
  , hasMethod
  , assignNumber
  , param
    -- * Events
  , listenOnce
    -- * Typed arrays
  , float32Of
  , freshFloat32
  , freshUint8
  , numbersOf
  , fill
  ) where

import Control.Exception (displayException, evaluate, finally, try)
import Data.Bifunctor (first)
import Data.Foldable (for_, traverse_)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.Traversable (for)
import Miso.DSL
  ( FromJSVal (fromJSValUnchecked)
  , Function (..)
  , JSException
  , JSVal
  , ToArgs
  , ToJSVal (toJSVal)
  , ToObject
  , asyncCallback1
  , await
  , createWith
  , freeFunction
  , freeJSVal
  , isUndefined
  , jsg
  , new
  , setField
  , (!)
  , (#)
  , (<##)
  )
import Miso.DSL qualified as DSL ((!!))
import Miso.Effect (Effect, io)
import Miso.String (MisoString, ms)
import Miso.WebAudio.Types (AudioParam (..), releaseHandle)

settled :: JSVal -> IO JSVal
settled promise = evaluate =<< await promise

attempt :: IO result -> IO (Either MisoString result)
attempt action = first describe <$> try action
  where
    describe :: JSException -> MisoString
    describe = ms . displayException

deliver
  :: IO (Either MisoString result)
  -> (result -> action)
  -> (MisoString -> action)
  -> Effect parent props model action
deliver blocking successful errorful = io (either errorful successful <$> blocking)

unavailable :: MisoString -> Either MisoString result
unavailable name = Left (name <> " is not available here")

invoke :: ToObject object => object -> MisoString -> [Double] -> IO ()
invoke object method arguments = do
  handles <- traverse toJSVal arguments
  freeJSVal =<< (object # method) handles
  traverse_ freeJSVal handles

invoke_ :: (ToObject object, ToArgs arguments) => object -> MisoString -> arguments -> IO ()
invoke_ object method arguments = freeJSVal =<< (object # method) arguments

readProperty :: (ToObject object, FromJSVal value) => object -> MisoString -> IO value
readProperty object property = do
  handle <- object ! property
  value <- fromJSValUnchecked handle
  freeJSVal handle
  pure value

hasMethod :: ToObject object => object -> MisoString -> IO Bool
hasMethod object name = do
  method <- object ! name
  missing <- evaluate =<< isUndefined method
  freeJSVal method
  pure (not missing)

listenOnce :: ToObject target => target -> MisoString -> (JSVal -> IO ()) -> IO ()
listenOnce target event action = do
  slot <- newIORef Nothing
  callback <- asyncCallback1 $ \fired -> action fired `finally` (readIORef slot >>= traverse_ freeFunction)
  writeIORef slot (Just (Function callback))
  options <- createWith [("once" :: MisoString, True)]
  invoke_ target "addEventListener" (event, callback, options)
  releaseHandle options

assignNumber :: ToObject object => object -> MisoString -> Double -> IO ()
assignNumber object property value = do
  handle <- toJSVal value
  setField object property handle
  freeJSVal handle

param :: ToObject node => MisoString -> node -> IO AudioParam
param name node = AudioParam <$> node ! name

freshArray :: MisoString -> Int -> IO JSVal
freshArray name size = do
  constructor <- jsg name
  array <- new constructor [size]
  freeJSVal constructor
  pure array

freshFloat32 :: Int -> IO JSVal
freshFloat32 = freshArray "Float32Array"

freshUint8 :: Int -> IO JSVal
freshUint8 = freshArray "Uint8Array"

float32Of :: [Double] -> IO JSVal
float32Of samples = do
  array <- freshFloat32 (length samples)
  fill array samples
  pure array

numbersOf :: JSVal -> IO [Double]
numbersOf array = do
  size <- readProperty array "length"
  for [0 .. size - 1] $ \index -> do
    handle <- array DSL.!! index
    value <- fromJSValUnchecked handle
    freeJSVal handle
    pure value

fill :: JSVal -> [Double] -> IO ()
fill target samples =
  for_ (zip [0 ..] samples) $ \(index, sample) -> do
    handle <- toJSVal sample
    (target <## index) handle
    freeJSVal handle
