module Miso.WebAudio.Stats
  ( -- * Types
    AudioPlaybackStats (..)
    -- * Reading
  , playbackStats
  , averageLatency
  , minimumLatency
  , maximumLatency
  , totalDuration
  , underrunDuration
  , underrunEvents
    -- * Resetting
  , resetLatency
  ) where

import Miso.DSL (isUndefined, (!))
import Miso.WebAudio.Internal (invoke_, readProperty)
import Miso.WebAudio.Types (AudioContext, AudioPlaybackStats (..))

playbackStats :: AudioContext -> IO (Maybe AudioPlaybackStats)
playbackStats context = do
  stats <- context ! "playbackStats"
  missing <- isUndefined stats
  pure (if missing then Nothing else Just (AudioPlaybackStats stats))

averageLatency :: AudioPlaybackStats -> IO Double
averageLatency stats = readProperty stats "averageLatency"

minimumLatency :: AudioPlaybackStats -> IO Double
minimumLatency stats = readProperty stats "minimumLatency"

maximumLatency :: AudioPlaybackStats -> IO Double
maximumLatency stats = readProperty stats "maximumLatency"

totalDuration :: AudioPlaybackStats -> IO Double
totalDuration stats = readProperty stats "totalDuration"

underrunDuration :: AudioPlaybackStats -> IO Double
underrunDuration stats = readProperty stats "underrunDuration"

underrunEvents :: AudioPlaybackStats -> IO Int
underrunEvents stats = readProperty stats "underrunEvents"

resetLatency :: AudioPlaybackStats -> IO ()
resetLatency stats = invoke_ stats "resetLatency" ()
