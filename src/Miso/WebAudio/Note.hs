{-# LANGUAGE StrictData #-}
module Miso.WebAudio.Note
  ( -- * Types
    Wave (..)
  , Note (..)
  ) where

import Miso.DSL (ToJSVal (..))
import Miso.String (MisoString)

data Wave = Sine | Square | Sawtooth | Triangle
  deriving (Eq, Show)

instance ToJSVal Wave where
  toJSVal wave = toJSVal @MisoString $ case wave of
    Sine -> "sine"
    Square -> "square"
    Sawtooth -> "sawtooth"
    Triangle -> "triangle"

data Note = Note
  { noteWave :: Wave
  , noteStart :: Double
  , noteFrequency :: Double
  , noteFrequencyTo :: Maybe (Double, Double)
  , noteGain :: Double
  , noteGainFadeAt :: Double
  , noteStop :: Double
  }
  deriving (Eq, Show)
