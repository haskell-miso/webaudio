{-# LANGUAGE StrictData #-}
module Miso.WebAudio.Note
  ( Wave (..)
  , Note (..)
  ) where

data Wave = Sine | Square | Sawtooth | Triangle
  deriving (Eq, Show)

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
