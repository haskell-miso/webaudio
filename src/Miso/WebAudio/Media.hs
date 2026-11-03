module Miso.WebAudio.Media
  ( -- * Media elements
    MediaElementAudioSourceNode (..)
  , createMediaElementSource
    -- * Media streams
  , MediaStreamAudioSourceNode (..)
  , createMediaStreamSource
  , MediaStreamTrackAudioSourceNode (..)
  , createMediaStreamTrackSource
  , MediaStreamAudioDestinationNode (..)
  , createMediaStreamDestination
  , destinationStream
  ) where

import Miso.DSL (ToJSVal, (!), (#))
import Miso.Media (Media, Stream)
import Miso.WebAudio.Internal (hasMethod)
import Miso.WebAudio.Types
  ( AudioContext
  , MediaElementAudioSourceNode (..)
  , MediaStreamAudioDestinationNode (..)
  , MediaStreamAudioSourceNode (..)
  , MediaStreamTrackAudioSourceNode (..)
  )

createMediaElementSource :: AudioContext -> Media -> IO MediaElementAudioSourceNode
createMediaElementSource context element =
  MediaElementAudioSourceNode <$> (context # "createMediaElementSource") [element]

createMediaStreamSource :: AudioContext -> Stream -> IO MediaStreamAudioSourceNode
createMediaStreamSource context stream =
  MediaStreamAudioSourceNode <$> (context # "createMediaStreamSource") [stream]

createMediaStreamTrackSource :: ToJSVal track => AudioContext -> track -> IO (Maybe MediaStreamTrackAudioSourceNode)
createMediaStreamTrackSource context track = do
  available <- hasMethod context "createMediaStreamTrackSource"
  if available
    then Just . MediaStreamTrackAudioSourceNode <$> (context # "createMediaStreamTrackSource") [track]
    else pure Nothing

createMediaStreamDestination :: AudioContext -> IO MediaStreamAudioDestinationNode
createMediaStreamDestination context = MediaStreamAudioDestinationNode <$> (context # "createMediaStreamDestination") ()

destinationStream :: MediaStreamAudioDestinationNode -> IO Stream
destinationStream node = node ! "stream"
