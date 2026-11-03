module Miso.WebAudio.Param
  ( -- * Types
    AudioParam (..)
  , AutomationRate (..)
    -- * Value
  , setValue
  , paramValue
  , defaultValue
  , minValue
  , maxValue
  , setAutomationRate
    -- * Automation
  , setValueAtTime
  , linearRampToValueAtTime
  , exponentialRampToValueAtTime
  , setTargetAtTime
  , setValueCurveAtTime
  , cancelScheduledValues
  , cancelAndHoldAtTime
  , hasCancelAndHold
    -- * Shared parameters
  , HasGain
  , gain
  , HasFrequency
  , frequency
  , HasDetune
  , detune
  ) where

import Miso.DSL (freeJSVal, setField)
import Miso.WebAudio.Internal (assignNumber, float32Of, hasMethod, invoke, invoke_, param, readProperty)
import Miso.WebAudio.Types (AudioParam (..), AutomationRate (..), HasDetune, HasFrequency, HasGain)

setValue :: AudioParam -> Double -> IO ()
setValue target = assignNumber target "value"

paramValue :: AudioParam -> IO Double
paramValue target = readProperty target "value"

defaultValue :: AudioParam -> IO Double
defaultValue target = readProperty target "defaultValue"

minValue :: AudioParam -> IO Double
minValue target = readProperty target "minValue"

maxValue :: AudioParam -> IO Double
maxValue target = readProperty target "maxValue"

setAutomationRate :: AudioParam -> AutomationRate -> IO ()
setAutomationRate target = setField target "automationRate"

setValueAtTime :: AudioParam -> Double -> Double -> IO ()
setValueAtTime target value at = invoke target "setValueAtTime" [value, at]

linearRampToValueAtTime :: AudioParam -> Double -> Double -> IO ()
linearRampToValueAtTime target value at = invoke target "linearRampToValueAtTime" [value, at]

exponentialRampToValueAtTime :: AudioParam -> Double -> Double -> IO ()
exponentialRampToValueAtTime target value at = invoke target "exponentialRampToValueAtTime" [value, at]

setTargetAtTime :: AudioParam -> Double -> Double -> Double -> IO ()
setTargetAtTime target value at constant = invoke target "setTargetAtTime" [value, at, constant]

setValueCurveAtTime :: AudioParam -> [Double] -> Double -> Double -> IO ()
setValueCurveAtTime target values at duration = do
  curve <- float32Of values
  invoke_ target "setValueCurveAtTime" (curve, at, duration)
  freeJSVal curve

cancelScheduledValues :: AudioParam -> Double -> IO ()
cancelScheduledValues target at = invoke target "cancelScheduledValues" [at]

cancelAndHoldAtTime :: AudioParam -> Double -> IO ()
cancelAndHoldAtTime target at = invoke target "cancelAndHoldAtTime" [at]

hasCancelAndHold :: AudioParam -> IO Bool
hasCancelAndHold target = hasMethod target "cancelAndHoldAtTime"

gain :: HasGain node => node -> IO AudioParam
gain = param "gain"

frequency :: HasFrequency node => node -> IO AudioParam
frequency = param "frequency"

detune :: HasDetune node => node -> IO AudioParam
detune = param "detune"
