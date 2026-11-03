module Miso.WebAudio.Channel
  ( -- * Splitting
    ChannelSplitterNode (..)
  , createChannelSplitter
    -- * Merging
  , ChannelMergerNode (..)
  , createChannelMerger
  ) where

import Miso.DSL ((#))
import Miso.WebAudio.Types (BaseAudioContext, ChannelMergerNode (..), ChannelSplitterNode (..))

createChannelSplitter :: BaseAudioContext context => context -> Int -> IO ChannelSplitterNode
createChannelSplitter context outputs = ChannelSplitterNode <$> (context # "createChannelSplitter") outputs

createChannelMerger :: BaseAudioContext context => context -> Int -> IO ChannelMergerNode
createChannelMerger context inputs = ChannelMergerNode <$> (context # "createChannelMerger") inputs
