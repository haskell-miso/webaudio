module Miso.WebAudio.Node
  ( -- * Types
    AudioNode
  , AudioDestinationNode (..)
  , ChannelCountMode (..)
  , ChannelInterpretation (..)
    -- * Connecting
  , connect
  , connectPorts
  , connectParam
  , connectOutputToParam
    -- * Disconnecting
  , disconnect
  , disconnectFrom
  , disconnectOutput
  , disconnectPorts
  , disconnectParam
    -- * Channels
  , numberOfInputs
  , numberOfOutputs
  , channelCount
  , setChannelCount
  , setChannelCountMode
  , setChannelInterpretation
    -- * Destination
  , maxChannelCount
  ) where

import Miso.DSL (setField)
import Miso.WebAudio.Internal (invoke_, readProperty)
import Miso.WebAudio.Types (AudioDestinationNode (..), AudioNode, AudioParam, ChannelCountMode (..), ChannelInterpretation (..))

connect :: (AudioNode from, AudioNode to) => from -> to -> IO ()
connect from to = invoke_ from "connect" [to]

connectPorts :: (AudioNode from, AudioNode to) => from -> Int -> to -> Int -> IO ()
connectPorts from output to input = invoke_ from "connect" (to, output, input)

connectParam :: AudioNode from => from -> AudioParam -> IO ()
connectParam from to = invoke_ from "connect" [to]

connectOutputToParam :: AudioNode from => from -> Int -> AudioParam -> IO ()
connectOutputToParam from output to = invoke_ from "connect" (to, output)

disconnect :: AudioNode node => node -> IO ()
disconnect node = invoke_ node "disconnect" ()

disconnectFrom :: (AudioNode from, AudioNode to) => from -> to -> IO ()
disconnectFrom from to = invoke_ from "disconnect" [to]

disconnectOutput :: AudioNode node => node -> Int -> IO ()
disconnectOutput node output = invoke_ node "disconnect" output

disconnectPorts :: (AudioNode from, AudioNode to) => from -> Int -> to -> Int -> IO ()
disconnectPorts from output to input = invoke_ from "disconnect" (to, output, input)

disconnectParam :: AudioNode node => node -> AudioParam -> IO ()
disconnectParam node target = invoke_ node "disconnect" [target]

numberOfInputs :: AudioNode node => node -> IO Int
numberOfInputs node = readProperty node "numberOfInputs"

numberOfOutputs :: AudioNode node => node -> IO Int
numberOfOutputs node = readProperty node "numberOfOutputs"

channelCount :: AudioNode node => node -> IO Int
channelCount node = readProperty node "channelCount"

setChannelCount :: AudioNode node => node -> Int -> IO ()
setChannelCount node = setField node "channelCount"

setChannelCountMode :: AudioNode node => node -> ChannelCountMode -> IO ()
setChannelCountMode node = setField node "channelCountMode"

setChannelInterpretation :: AudioNode node => node -> ChannelInterpretation -> IO ()
setChannelInterpretation node = setField node "channelInterpretation"

maxChannelCount :: AudioDestinationNode -> IO Int
maxChannelCount node = readProperty node "maxChannelCount"
