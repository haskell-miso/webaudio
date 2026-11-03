module Miso.WebAudio.Spatial
  ( -- * Stereo panning
    StereoPannerNode (..)
  , createStereoPanner
  , pan
    -- * 3D panning
  , PannerNode (..)
  , PanningModel (..)
  , DistanceModel (..)
  , createPanner
  , setPanningModel
  , setDistanceModel
  , setRefDistance
  , setMaxDistance
  , setRolloffFactor
  , setConeInnerAngle
  , setConeOuterAngle
  , setConeOuterGain
  , orientationX
  , orientationY
  , orientationZ
    -- * Position
  , HasPosition
  , positionX
  , positionY
  , positionZ
    -- * Listener
  , AudioListener (..)
  , listener
  , forwardX
  , forwardY
  , forwardZ
  , upX
  , upY
  , upZ
  , setListenerPosition
  , setListenerOrientation
  ) where

import Miso.DSL (setField, (!), (#))
import Miso.WebAudio.Internal (assignNumber, invoke, param)
import Miso.WebAudio.Types
  ( AudioListener (..)
  , AudioParam
  , BaseAudioContext
  , DistanceModel (..)
  , HasPosition
  , PannerNode (..)
  , PanningModel (..)
  , StereoPannerNode (..)
  )

createStereoPanner :: BaseAudioContext context => context -> IO StereoPannerNode
createStereoPanner context = StereoPannerNode <$> (context # "createStereoPanner") ()

pan :: StereoPannerNode -> IO AudioParam
pan = param "pan"

createPanner :: BaseAudioContext context => context -> IO PannerNode
createPanner context = PannerNode <$> (context # "createPanner") ()

setPanningModel :: PannerNode -> PanningModel -> IO ()
setPanningModel node = setField node "panningModel"

setDistanceModel :: PannerNode -> DistanceModel -> IO ()
setDistanceModel node = setField node "distanceModel"

setRefDistance :: PannerNode -> Double -> IO ()
setRefDistance node = assignNumber node "refDistance"

setMaxDistance :: PannerNode -> Double -> IO ()
setMaxDistance node = assignNumber node "maxDistance"

setRolloffFactor :: PannerNode -> Double -> IO ()
setRolloffFactor node = assignNumber node "rolloffFactor"

setConeInnerAngle :: PannerNode -> Double -> IO ()
setConeInnerAngle node = assignNumber node "coneInnerAngle"

setConeOuterAngle :: PannerNode -> Double -> IO ()
setConeOuterAngle node = assignNumber node "coneOuterAngle"

setConeOuterGain :: PannerNode -> Double -> IO ()
setConeOuterGain node = assignNumber node "coneOuterGain"

orientationX :: PannerNode -> IO AudioParam
orientationX = param "orientationX"

orientationY :: PannerNode -> IO AudioParam
orientationY = param "orientationY"

orientationZ :: PannerNode -> IO AudioParam
orientationZ = param "orientationZ"

positionX :: HasPosition node => node -> IO AudioParam
positionX = param "positionX"

positionY :: HasPosition node => node -> IO AudioParam
positionY = param "positionY"

positionZ :: HasPosition node => node -> IO AudioParam
positionZ = param "positionZ"

listener :: BaseAudioContext context => context -> IO AudioListener
listener context = AudioListener <$> context ! "listener"

forwardX :: AudioListener -> IO AudioParam
forwardX = param "forwardX"

forwardY :: AudioListener -> IO AudioParam
forwardY = param "forwardY"

forwardZ :: AudioListener -> IO AudioParam
forwardZ = param "forwardZ"

upX :: AudioListener -> IO AudioParam
upX = param "upX"

upY :: AudioListener -> IO AudioParam
upY = param "upY"

upZ :: AudioListener -> IO AudioParam
upZ = param "upZ"

setListenerPosition :: AudioListener -> Double -> Double -> Double -> IO ()
setListenerPosition node x y z = invoke node "setPosition" [x, y, z]

setListenerOrientation :: AudioListener -> Double -> Double -> Double -> Double -> Double -> Double -> IO ()
setListenerOrientation node forwardx forwardy forwardz upx upy upz =
  invoke node "setOrientation" [forwardx, forwardy, forwardz, upx, upy, upz]
