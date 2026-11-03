module Miso.WebAudio.Node
  ( AudioContext (..)
  , OfflineAudioContext (..)
  , BaseAudioContext
  , LatencyHint (..)
  , ContextState (..)
  , newAudioContext
  , newAudioContextAtRate
  , newOfflineAudioContext
  , startRendering
  , onComplete
  , offlineLength
  , suspendOfflineAt
  , resumeOffline
  , resume
  , suspend
  , close
  , contextState
  , onStateChange
  , currentTime
  , sampleRate
  , baseLatency
  , outputLatency
  , OutputTimestamp (..)
  , outputTimestamp
  , hasSetSinkId
  , setSinkId
  , destination
  , maxChannelCount
  , AudioNode
  , AudioDestinationNode (..)
  , connect
  , connectPorts
  , connectParam
  , connectOutputToParam
  , disconnect
  , disconnectFrom
  , disconnectOutput
  , disconnectPorts
  , disconnectParam
  , numberOfInputs
  , numberOfOutputs
  , channelCount
  , setChannelCount
  , ChannelCountMode (..)
  , setChannelCountMode
  , ChannelInterpretation (..)
  , setChannelInterpretation
  , AudioParam (..)
  , setValue
  , setValueAt
  , linearRampTo
  , exponentialRampTo
  , setTargetAt
  , setValueCurveAt
  , cancelScheduled
  , cancelAndHoldAt
  , hasCancelAndHold
  , paramValue
  , paramDefault
  , paramMin
  , paramMax
  , AutomationRate (..)
  , setAutomationRate
  , AudioSource
  , startAt
  , stopAt
  , onEnded
  , HasGain
  , gain
  , HasFrequency
  , frequency
  , HasDetune
  , detune
  , HasFrequencyResponse
  , frequencyResponse
  , GainNode (..)
  , newGain
  , OscillatorNode (..)
  , newOscillator
  , setWave
  , PeriodicWave (..)
  , newPeriodicWave
  , setPeriodicWave
  , BiquadFilterNode (..)
  , FilterType (..)
  , newBiquadFilter
  , setFilterType
  , q
  , IIRFilterNode (..)
  , newIIRFilter
  , AudioBufferSourceNode (..)
  , newBufferSource
  , startAtOffset
  , startFor
  , setLoop
  , setLoopStart
  , setLoopEnd
  , playbackRate
  , ConstantSourceNode (..)
  , newConstantSource
  , offset
  , WaveShaperNode (..)
  , Oversample (..)
  , newWaveShaper
  , setCurve
  , setOversample
  , DynamicsCompressorNode (..)
  , newDynamicsCompressor
  , threshold
  , knee
  , ratio
  , attack
  , release
  , reduction
  , ConvolverNode (..)
  , newConvolver
  , setNormalize
  , HasBuffer
  , setBuffer
  , DelayNode (..)
  , newDelay
  , delayTime
  , StereoPannerNode (..)
  , newStereoPanner
  , pan
  , PannerNode (..)
  , PanningModel (..)
  , DistanceModel (..)
  , newPanner
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
  , HasPosition
  , positionX
  , positionY
  , positionZ
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
  , AnalyserNode (..)
  , newAnalyser
  , fftSize
  , setFftSize
  , frequencyBinCount
  , setMinDecibels
  , setMaxDecibels
  , setSmoothing
  , floatTimeDomainData
  , floatFrequencyData
  , byteTimeDomainData
  , byteFrequencyData
  , ChannelSplitterNode (..)
  , newChannelSplitter
  , ChannelMergerNode (..)
  , newChannelMerger
  , MediaElementAudioSourceNode (..)
  , newMediaElementSource
  , MediaStreamAudioSourceNode (..)
  , newMediaStreamSource
  , MediaStreamTrackAudioSourceNode (..)
  , newMediaStreamTrackSource
  , MediaStreamAudioDestinationNode (..)
  , newMediaStreamDestination
  , destinationStream
  , AudioWorkletNode (..)
  , addWorkletModule
  , newAudioWorkletNode
  , newAudioWorkletNodeWith
  , workletPort
  , AudioParamMap (..)
  , workletParameters
  , lookupParam
  , paramNames
  , AudioPlaybackStats (..)
  , playbackStats
  , averageLatency
  , minimumLatency
  , maximumLatency
  , totalDuration
  , underrunDuration
  , underrunEvents
  , resetLatency
  , AudioBuffer (..)
  , newBuffer
  , decodeAudioData
  , fetchAudioBuffer
  , writeChannel
  , readChannel
  , bufferLength
  , bufferChannels
  , bufferSampleRate
  , bufferDuration
  , releaseHandle
  ) where

import Control.Exception (evaluate, finally, try)
import Control.Monad (void, when)
import Data.Foldable (for_, traverse_)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.Traversable (for)
import Miso.DSL
import Miso.DSL qualified as DSL
import Miso.String (MisoString)
import Miso.WebAudio.Note (Wave (..))

newtype AudioContext = AudioContext JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype OfflineAudioContext = OfflineAudioContext JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AudioDestinationNode = AudioDestinationNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AudioParam = AudioParam JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AudioBuffer = AudioBuffer JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype GainNode = GainNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype OscillatorNode = OscillatorNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype BiquadFilterNode = BiquadFilterNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AudioBufferSourceNode = AudioBufferSourceNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype ConstantSourceNode = ConstantSourceNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype WaveShaperNode = WaveShaperNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype DynamicsCompressorNode = DynamicsCompressorNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype ConvolverNode = ConvolverNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype DelayNode = DelayNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype StereoPannerNode = StereoPannerNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype PannerNode = PannerNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AudioListener = AudioListener JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AnalyserNode = AnalyserNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype IIRFilterNode = IIRFilterNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype PeriodicWave = PeriodicWave JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype ChannelSplitterNode = ChannelSplitterNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype ChannelMergerNode = ChannelMergerNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype MediaElementAudioSourceNode = MediaElementAudioSourceNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype MediaStreamAudioSourceNode = MediaStreamAudioSourceNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype MediaStreamTrackAudioSourceNode = MediaStreamTrackAudioSourceNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype MediaStreamAudioDestinationNode = MediaStreamAudioDestinationNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AudioWorkletNode = AudioWorkletNode JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AudioParamMap = AudioParamMap JSVal
  deriving (Eq, ToJSVal, ToObject)

newtype AudioPlaybackStats = AudioPlaybackStats JSVal
  deriving (Eq, ToJSVal, ToObject)

class (ToJSVal context, ToObject context) => BaseAudioContext context

instance BaseAudioContext AudioContext

instance BaseAudioContext OfflineAudioContext

class (ToJSVal node, ToObject node) => AudioNode node

instance AudioNode AudioDestinationNode

instance AudioNode GainNode

instance AudioNode OscillatorNode

instance AudioNode BiquadFilterNode

instance AudioNode AudioBufferSourceNode

instance AudioNode ConstantSourceNode

instance AudioNode WaveShaperNode

instance AudioNode DynamicsCompressorNode

instance AudioNode ConvolverNode

instance AudioNode DelayNode

instance AudioNode StereoPannerNode

instance AudioNode PannerNode

instance AudioNode AnalyserNode

instance AudioNode IIRFilterNode

instance AudioNode ChannelSplitterNode

instance AudioNode ChannelMergerNode

instance AudioNode MediaElementAudioSourceNode

instance AudioNode MediaStreamAudioSourceNode

instance AudioNode MediaStreamTrackAudioSourceNode

instance AudioNode MediaStreamAudioDestinationNode

instance AudioNode AudioWorkletNode

class AudioNode node => AudioSource node

instance AudioSource OscillatorNode

instance AudioSource AudioBufferSourceNode

instance AudioSource ConstantSourceNode

class ToObject node => HasGain node

instance HasGain GainNode

instance HasGain BiquadFilterNode

class ToObject node => HasFrequency node

instance HasFrequency OscillatorNode

instance HasFrequency BiquadFilterNode

class ToObject node => HasDetune node

instance HasDetune OscillatorNode

instance HasDetune BiquadFilterNode

instance HasDetune AudioBufferSourceNode

class ToObject node => HasBuffer node

instance HasBuffer AudioBufferSourceNode

instance HasBuffer ConvolverNode

class ToObject node => HasFrequencyResponse node

instance HasFrequencyResponse BiquadFilterNode

instance HasFrequencyResponse IIRFilterNode

class ToObject node => HasPosition node

instance HasPosition PannerNode

instance HasPosition AudioListener

data LatencyHint = LatencyInteractive | LatencyBalanced | LatencyPlayback | LatencySeconds Double
  deriving (Eq, Show)

data OutputTimestamp = OutputTimestamp
  { outputContextTime :: Double
  , outputPerformanceTime :: Double
  }
  deriving (Eq, Show)

data ChannelCountMode = ChannelMax | ChannelClampedMax | ChannelExplicit
  deriving (Eq, Show)

data ChannelInterpretation = Speakers | Discrete
  deriving (Eq, Show)

data AutomationRate = ARate | KRate
  deriving (Eq, Show)

data PanningModel = EqualPower | HRTF
  deriving (Eq, Show)

data DistanceModel = LinearDistance | InverseDistance | ExponentialDistance
  deriving (Eq, Show)

data ContextState = Suspended | Running | Closed | Interrupted
  deriving (Eq, Show)

data FilterType = Lowpass | Highpass | Bandpass | Lowshelf | Highshelf | Peaking | Notch | Allpass
  deriving (Eq, Show)

data Oversample = OversampleNone | Oversample2x | Oversample4x
  deriving (Eq, Show)

settled :: JSVal -> IO JSVal
settled promise = evaluate =<< await promise

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
  not <$> isUndefined method

listenOnce :: ToObject target => target -> MisoString -> (JSVal -> IO ()) -> IO ()
listenOnce target event action = do
  slot <- newIORef Nothing
  callback <- asyncCallback1 $ \fired -> action fired `finally` (readIORef slot >>= traverse_ freeFunction)
  writeIORef slot (Just (Function callback))
  options <- createWith [("once" :: MisoString, True)]
  invoke_ target "addEventListener" (event, callback, options)

assignNumber :: ToObject object => object -> MisoString -> Double -> IO ()
assignNumber object property value = do
  handle <- toJSVal value
  setField object property handle
  freeJSVal handle

param :: ToObject node => MisoString -> node -> IO AudioParam
param name node = AudioParam <$> node ! name

constructorNamed :: [MisoString] -> IO (Maybe JSVal)
constructorNamed = \case
  [] -> pure Nothing
  name : rest -> do
    found <- jsg name
    missing <- (||) <$> isUndefined found <*> isNull found
    if missing then constructorNamed rest else pure (Just found)

latencyValue :: LatencyHint -> IO JSVal
latencyValue = \case
  LatencyInteractive -> toJSVal ("interactive" :: MisoString)
  LatencyBalanced -> toJSVal ("balanced" :: MisoString)
  LatencyPlayback -> toJSVal ("playback" :: MisoString)
  LatencySeconds latency -> toJSVal latency

constructContext :: [(MisoString, JSVal)] -> IO (Maybe AudioContext)
constructContext settings =
  constructorNamed ["AudioContext", "webkitAudioContext"] >>= \case
    Nothing -> pure Nothing
    Just constructor -> do
      options <- createWith settings
      created <- try (new constructor [options])
      pure $ case created of
        Left (_ :: JSException) -> Nothing
        Right context -> Just (AudioContext context)

newAudioContext :: LatencyHint -> IO (Maybe AudioContext)
newAudioContext hint = do
  latency <- latencyValue hint
  constructContext [("latencyHint", latency)]

newAudioContextAtRate :: LatencyHint -> Double -> IO (Maybe AudioContext)
newAudioContextAtRate hint rate = do
  latency <- latencyValue hint
  sampling <- toJSVal rate
  constructContext [("latencyHint", latency), ("sampleRate", sampling)]

newOfflineAudioContext :: Int -> Int -> Double -> IO OfflineAudioContext
newOfflineAudioContext channels frames rate = do
  constructor <- jsg "OfflineAudioContext"
  OfflineAudioContext <$> new constructor (channels, frames, rate)

startRendering :: OfflineAudioContext -> IO AudioBuffer
startRendering context = AudioBuffer <$> (settled =<< (context # "startRendering") ())

onComplete :: OfflineAudioContext -> (AudioBuffer -> IO ()) -> IO ()
onComplete context action = listenOnce context "complete" $ \event ->
  action . AudioBuffer =<< event ! "renderedBuffer"

offlineLength :: OfflineAudioContext -> IO Int
offlineLength context = readProperty context "length"

suspendOfflineAt :: OfflineAudioContext -> Double -> IO (IO ())
suspendOfflineAt context at = do
  promise <- (context # "suspend") at
  pure (void (settled promise))

resumeOffline :: OfflineAudioContext -> IO ()
resumeOffline context = invoke_ context "resume" ()

resume :: AudioContext -> IO ()
resume context = invoke_ context "resume" ()

suspend :: AudioContext -> IO ()
suspend context = invoke_ context "suspend" ()

close :: AudioContext -> IO ()
close context = invoke_ context "close" ()

contextState :: BaseAudioContext context => context -> IO ContextState
contextState context = do
  name <- fromJSValUnchecked =<< (context ! "state")
  pure $ case name :: MisoString of
    "running" -> Running
    "closed" -> Closed
    "interrupted" -> Interrupted
    _ -> Suspended

onStateChange :: BaseAudioContext context => context -> (ContextState -> IO ()) -> IO (IO ())
onStateChange context action = do
  callback <- asyncCallback (action =<< contextState context)
  invoke_ context "addEventListener" ("statechange" :: MisoString, callback)
  listening <- newIORef True
  pure $ do
    active <- readIORef listening
    when active $ do
      writeIORef listening False
      invoke_ context "removeEventListener" ("statechange" :: MisoString, callback)
      freeFunction (Function callback)

currentTime :: BaseAudioContext context => context -> IO Double
currentTime context = readProperty context "currentTime"

sampleRate :: BaseAudioContext context => context -> IO Double
sampleRate context = readProperty context "sampleRate"

optionalNumber :: AudioContext -> MisoString -> IO Double
optionalNumber context property = do
  handle <- context ! property
  missing <- isUndefined handle
  value <- if missing then pure 0 else fromJSValUnchecked handle
  freeJSVal handle
  pure value

baseLatency :: AudioContext -> IO Double
baseLatency context = optionalNumber context "baseLatency"

outputLatency :: AudioContext -> IO Double
outputLatency context = optionalNumber context "outputLatency"

outputTimestamp :: AudioContext -> IO OutputTimestamp
outputTimestamp context = do
  stamp <- (context # "getOutputTimestamp") ()
  OutputTimestamp <$> readProperty stamp "contextTime" <*> readProperty stamp "performanceTime"

hasSetSinkId :: AudioContext -> IO Bool
hasSetSinkId context = hasMethod context "setSinkId"

setSinkId :: AudioContext -> MisoString -> IO ()
setSinkId context device = do
  promise <- (context # "setSinkId") device
  void (settled promise)

destination :: BaseAudioContext context => context -> IO AudioDestinationNode
destination context = AudioDestinationNode <$> context ! "destination"

maxChannelCount :: AudioDestinationNode -> IO Int
maxChannelCount node = readProperty node "maxChannelCount"

connect :: (AudioNode from, AudioNode to) => from -> to -> IO ()
connect from to = do
  target <- toJSVal to
  invoke_ from "connect" [target]

connectPorts :: (AudioNode from, AudioNode to) => from -> Int -> to -> Int -> IO ()
connectPorts from output to input = do
  target <- toJSVal to
  invoke_ from "connect" (target, output, input)

connectParam :: AudioNode from => from -> AudioParam -> IO ()
connectParam from to = do
  target <- toJSVal to
  invoke_ from "connect" [target]

connectOutputToParam :: AudioNode from => from -> Int -> AudioParam -> IO ()
connectOutputToParam from output to = do
  target <- toJSVal to
  invoke_ from "connect" (target, output)

disconnect :: AudioNode node => node -> IO ()
disconnect node = invoke_ node "disconnect" ()

disconnectFrom :: (AudioNode from, AudioNode to) => from -> to -> IO ()
disconnectFrom from to = do
  target <- toJSVal to
  invoke_ from "disconnect" [target]

disconnectOutput :: AudioNode node => node -> Int -> IO ()
disconnectOutput node output = invoke_ node "disconnect" output

disconnectPorts :: (AudioNode from, AudioNode to) => from -> Int -> to -> Int -> IO ()
disconnectPorts from output to input = do
  target <- toJSVal to
  invoke_ from "disconnect" (target, output, input)

numberOfInputs :: AudioNode node => node -> IO Int
numberOfInputs node = readProperty node "numberOfInputs"

numberOfOutputs :: AudioNode node => node -> IO Int
numberOfOutputs node = readProperty node "numberOfOutputs"

channelCount :: AudioNode node => node -> IO Int
channelCount node = readProperty node "channelCount"

setChannelCount :: AudioNode node => node -> Int -> IO ()
setChannelCount node = setField node "channelCount"

setChannelCountMode :: AudioNode node => node -> ChannelCountMode -> IO ()
setChannelCountMode node mode = setField node "channelCountMode" name
  where
    name :: MisoString
    name = case mode of
      ChannelMax -> "max"
      ChannelClampedMax -> "clamped-max"
      ChannelExplicit -> "explicit"

setChannelInterpretation :: AudioNode node => node -> ChannelInterpretation -> IO ()
setChannelInterpretation node interpretation = setField node "channelInterpretation" name
  where
    name :: MisoString
    name = case interpretation of
      Speakers -> "speakers"
      Discrete -> "discrete"

disconnectParam :: AudioNode node => node -> AudioParam -> IO ()
disconnectParam node target = do
  handle <- toJSVal target
  invoke_ node "disconnect" [handle]

setValue :: AudioParam -> Double -> IO ()
setValue target = assignNumber target "value"

setValueAt :: AudioParam -> Double -> Double -> IO ()
setValueAt target value at = invoke target "setValueAtTime" [value, at]

linearRampTo :: AudioParam -> Double -> Double -> IO ()
linearRampTo target value at = invoke target "linearRampToValueAtTime" [value, at]

exponentialRampTo :: AudioParam -> Double -> Double -> IO ()
exponentialRampTo target value at = invoke target "exponentialRampToValueAtTime" [value, at]

setTargetAt :: AudioParam -> Double -> Double -> Double -> IO ()
setTargetAt target value at constant = invoke target "setTargetAtTime" [value, at, constant]

setValueCurveAt :: AudioParam -> [Double] -> Double -> Double -> IO ()
setValueCurveAt target values at duration = do
  curve <- float32Of values
  invoke_ target "setValueCurveAtTime" (curve, at, duration)
  freeJSVal curve

cancelScheduled :: AudioParam -> Double -> IO ()
cancelScheduled target at = invoke target "cancelScheduledValues" [at]

cancelAndHoldAt :: AudioParam -> Double -> IO ()
cancelAndHoldAt target at = invoke target "cancelAndHoldAtTime" [at]

hasCancelAndHold :: AudioParam -> IO Bool
hasCancelAndHold target = hasMethod target "cancelAndHoldAtTime"

paramValue :: AudioParam -> IO Double
paramValue target = readProperty target "value"

paramDefault :: AudioParam -> IO Double
paramDefault target = readProperty target "defaultValue"

paramMin :: AudioParam -> IO Double
paramMin target = readProperty target "minValue"

paramMax :: AudioParam -> IO Double
paramMax target = readProperty target "maxValue"

setAutomationRate :: AudioParam -> AutomationRate -> IO ()
setAutomationRate target rate = setField target "automationRate" name
  where
    name :: MisoString
    name = case rate of
      ARate -> "a-rate"
      KRate -> "k-rate"

startAt :: AudioSource source => source -> Double -> IO ()
startAt source at = invoke source "start" [at]

stopAt :: AudioSource source => source -> Double -> IO ()
stopAt source at = invoke source "stop" [at]

onEnded :: AudioSource source => source -> IO () -> IO ()
onEnded source action = listenOnce source "ended" (const action)

frequencyResponse :: HasFrequencyResponse node => node -> [Double] -> IO [(Double, Double)]
frequencyResponse node frequencies = do
  hertz <- float32Of frequencies
  magnitudes <- freshFloat32 (length frequencies)
  phases <- freshFloat32 (length frequencies)
  invoke_ node "getFrequencyResponse" (hertz, magnitudes, phases)
  response <- zip <$> numbersOf magnitudes <*> numbersOf phases
  traverse_ freeJSVal [hertz, magnitudes, phases]
  pure response

gain :: HasGain node => node -> IO AudioParam
gain = param "gain"

frequency :: HasFrequency node => node -> IO AudioParam
frequency = param "frequency"

detune :: HasDetune node => node -> IO AudioParam
detune = param "detune"

newGain :: BaseAudioContext context => context -> IO GainNode
newGain context = GainNode <$> (context # "createGain") ()

newOscillator :: BaseAudioContext context => context -> IO OscillatorNode
newOscillator context = OscillatorNode <$> (context # "createOscillator") ()

setWave :: OscillatorNode -> Wave -> IO ()
setWave oscillator wave = setField oscillator "type" name
  where
    name :: MisoString
    name = case wave of
      Sine -> "sine"
      Square -> "square"
      Sawtooth -> "sawtooth"
      Triangle -> "triangle"

newPeriodicWave :: BaseAudioContext context => context -> [Double] -> [Double] -> Bool -> IO PeriodicWave
newPeriodicWave context real imaginary normalize = do
  realPart <- float32Of real
  imaginaryPart <- float32Of imaginary
  options <- createWith [("disableNormalization" :: MisoString, not normalize)]
  PeriodicWave <$> (context # "createPeriodicWave") (realPart, imaginaryPart, options)

setPeriodicWave :: OscillatorNode -> PeriodicWave -> IO ()
setPeriodicWave oscillator wave = do
  handle <- toJSVal wave
  invoke_ oscillator "setPeriodicWave" [handle]

newBiquadFilter :: BaseAudioContext context => context -> IO BiquadFilterNode
newBiquadFilter context = BiquadFilterNode <$> (context # "createBiquadFilter") ()

setFilterType :: BiquadFilterNode -> FilterType -> IO ()
setFilterType node kind = setField node "type" name
  where
    name :: MisoString
    name = case kind of
      Lowpass -> "lowpass"
      Highpass -> "highpass"
      Bandpass -> "bandpass"
      Lowshelf -> "lowshelf"
      Highshelf -> "highshelf"
      Peaking -> "peaking"
      Notch -> "notch"
      Allpass -> "allpass"

q :: BiquadFilterNode -> IO AudioParam
q = param "Q"

newIIRFilter :: BaseAudioContext context => context -> [Double] -> [Double] -> IO IIRFilterNode
newIIRFilter context feedforward feedback = IIRFilterNode <$> (context # "createIIRFilter") (feedforward, feedback)

newBufferSource :: BaseAudioContext context => context -> IO AudioBufferSourceNode
newBufferSource context = AudioBufferSourceNode <$> (context # "createBufferSource") ()

startAtOffset :: AudioBufferSourceNode -> Double -> Double -> IO ()
startAtOffset source at position = invoke source "start" [at, position]

startFor :: AudioBufferSourceNode -> Double -> Double -> Double -> IO ()
startFor source at position duration = invoke source "start" [at, position, duration]

setLoopStart :: AudioBufferSourceNode -> Double -> IO ()
setLoopStart source = assignNumber source "loopStart"

setLoopEnd :: AudioBufferSourceNode -> Double -> IO ()
setLoopEnd source = assignNumber source "loopEnd"

setLoop :: AudioBufferSourceNode -> Bool -> IO ()
setLoop source = setField source "loop"

playbackRate :: AudioBufferSourceNode -> IO AudioParam
playbackRate = param "playbackRate"

newConstantSource :: BaseAudioContext context => context -> IO ConstantSourceNode
newConstantSource context = ConstantSourceNode <$> (context # "createConstantSource") ()

offset :: ConstantSourceNode -> IO AudioParam
offset = param "offset"

newWaveShaper :: BaseAudioContext context => context -> IO WaveShaperNode
newWaveShaper context = WaveShaperNode <$> (context # "createWaveShaper") ()

setCurve :: WaveShaperNode -> [Double] -> IO ()
setCurve shaper samples = do
  curve <- float32Of samples
  setField shaper "curve" curve
  freeJSVal curve

setOversample :: WaveShaperNode -> Oversample -> IO ()
setOversample shaper amount = setField shaper "oversample" name
  where
    name :: MisoString
    name = case amount of
      OversampleNone -> "none"
      Oversample2x -> "2x"
      Oversample4x -> "4x"

newDynamicsCompressor :: BaseAudioContext context => context -> IO DynamicsCompressorNode
newDynamicsCompressor context = DynamicsCompressorNode <$> (context # "createDynamicsCompressor") ()

threshold :: DynamicsCompressorNode -> IO AudioParam
threshold = param "threshold"

knee :: DynamicsCompressorNode -> IO AudioParam
knee = param "knee"

ratio :: DynamicsCompressorNode -> IO AudioParam
ratio = param "ratio"

attack :: DynamicsCompressorNode -> IO AudioParam
attack = param "attack"

release :: DynamicsCompressorNode -> IO AudioParam
release = param "release"

reduction :: DynamicsCompressorNode -> IO Double
reduction node = readProperty node "reduction"

newConvolver :: BaseAudioContext context => context -> IO ConvolverNode
newConvolver context = ConvolverNode <$> (context # "createConvolver") ()

setNormalize :: ConvolverNode -> Bool -> IO ()
setNormalize node = setField node "normalize"

setBuffer :: HasBuffer node => node -> AudioBuffer -> IO ()
setBuffer node = setField node "buffer"

newDelay :: BaseAudioContext context => context -> Double -> IO DelayNode
newDelay context longest = DelayNode <$> (context # "createDelay") longest

delayTime :: DelayNode -> IO AudioParam
delayTime = param "delayTime"

newStereoPanner :: BaseAudioContext context => context -> IO StereoPannerNode
newStereoPanner context = StereoPannerNode <$> (context # "createStereoPanner") ()

pan :: StereoPannerNode -> IO AudioParam
pan = param "pan"

newPanner :: BaseAudioContext context => context -> IO PannerNode
newPanner context = PannerNode <$> (context # "createPanner") ()

setPanningModel :: PannerNode -> PanningModel -> IO ()
setPanningModel node model = setField node "panningModel" name
  where
    name :: MisoString
    name = case model of
      EqualPower -> "equalpower"
      HRTF -> "HRTF"

setDistanceModel :: PannerNode -> DistanceModel -> IO ()
setDistanceModel node model = setField node "distanceModel" name
  where
    name :: MisoString
    name = case model of
      LinearDistance -> "linear"
      InverseDistance -> "inverse"
      ExponentialDistance -> "exponential"

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

newAnalyser :: BaseAudioContext context => context -> IO AnalyserNode
newAnalyser context = AnalyserNode <$> (context # "createAnalyser") ()

fftSize :: AnalyserNode -> IO Int
fftSize node = readProperty node "fftSize"

setFftSize :: AnalyserNode -> Int -> IO ()
setFftSize node = setField node "fftSize"

frequencyBinCount :: AnalyserNode -> IO Int
frequencyBinCount node = readProperty node "frequencyBinCount"

setMinDecibels :: AnalyserNode -> Double -> IO ()
setMinDecibels node = assignNumber node "minDecibels"

setMaxDecibels :: AnalyserNode -> Double -> IO ()
setMaxDecibels node = assignNumber node "maxDecibels"

setSmoothing :: AnalyserNode -> Double -> IO ()
setSmoothing node = assignNumber node "smoothingTimeConstant"

analyserReading :: (Int -> IO JSVal) -> MisoString -> IO Int -> AnalyserNode -> IO [Double]
analyserReading freshArray method size node = do
  target <- freshArray =<< size
  invoke_ node method [target]
  values <- numbersOf target
  freeJSVal target
  pure values

floatTimeDomainData :: AnalyserNode -> IO [Double]
floatTimeDomainData node = analyserReading freshFloat32 "getFloatTimeDomainData" (fftSize node) node

floatFrequencyData :: AnalyserNode -> IO [Double]
floatFrequencyData node = analyserReading freshFloat32 "getFloatFrequencyData" (frequencyBinCount node) node

byteTimeDomainData :: AnalyserNode -> IO [Double]
byteTimeDomainData node = analyserReading freshUint8 "getByteTimeDomainData" (fftSize node) node

byteFrequencyData :: AnalyserNode -> IO [Double]
byteFrequencyData node = analyserReading freshUint8 "getByteFrequencyData" (frequencyBinCount node) node

newChannelSplitter :: BaseAudioContext context => context -> Int -> IO ChannelSplitterNode
newChannelSplitter context outputs = ChannelSplitterNode <$> (context # "createChannelSplitter") outputs

newChannelMerger :: BaseAudioContext context => context -> Int -> IO ChannelMergerNode
newChannelMerger context inputs = ChannelMergerNode <$> (context # "createChannelMerger") inputs

newMediaElementSource :: ToJSVal element => AudioContext -> element -> IO MediaElementAudioSourceNode
newMediaElementSource context element = do
  handle <- toJSVal element
  MediaElementAudioSourceNode <$> (context # "createMediaElementSource") [handle]

newMediaStreamSource :: ToJSVal stream => AudioContext -> stream -> IO MediaStreamAudioSourceNode
newMediaStreamSource context stream = do
  handle <- toJSVal stream
  MediaStreamAudioSourceNode <$> (context # "createMediaStreamSource") [handle]

newMediaStreamTrackSource :: ToJSVal track => AudioContext -> track -> IO (Maybe MediaStreamTrackAudioSourceNode)
newMediaStreamTrackSource context track = do
  available <- hasMethod context "createMediaStreamTrackSource"
  if available
    then do
      handle <- toJSVal track
      Just . MediaStreamTrackAudioSourceNode <$> (context # "createMediaStreamTrackSource") [handle]
    else pure Nothing

newMediaStreamDestination :: AudioContext -> IO MediaStreamAudioDestinationNode
newMediaStreamDestination context = MediaStreamAudioDestinationNode <$> (context # "createMediaStreamDestination") ()

destinationStream :: MediaStreamAudioDestinationNode -> IO JSVal
destinationStream node = node ! "stream"

addWorkletModule :: BaseAudioContext context => context -> MisoString -> IO ()
addWorkletModule context url = do
  worklet <- context ! "audioWorklet"
  promise <- (worklet # "addModule") url
  void (settled promise)

newAudioWorkletNode :: BaseAudioContext context => context -> MisoString -> IO AudioWorkletNode
newAudioWorkletNode context name = newAudioWorkletNodeWith context name =<< create

newAudioWorkletNodeWith :: (BaseAudioContext context, ToJSVal options) => context -> MisoString -> options -> IO AudioWorkletNode
newAudioWorkletNodeWith context name options = do
  constructor <- jsg "AudioWorkletNode"
  handle <- toJSVal context
  AudioWorkletNode <$> new constructor (handle, name, options)

workletPort :: AudioWorkletNode -> IO JSVal
workletPort node = node ! "port"

workletParameters :: AudioWorkletNode -> IO AudioParamMap
workletParameters node = AudioParamMap <$> node ! "parameters"

lookupParam :: AudioParamMap -> MisoString -> IO (Maybe AudioParam)
lookupParam parameters name = do
  found <- (parameters # "get") name
  missing <- isUndefined found
  pure (if missing then Nothing else Just (AudioParam found))

paramNames :: AudioParamMap -> IO [MisoString]
paramNames parameters = do
  keys <- (parameters # "keys") ()
  arrayClass <- jsg "Array"
  fromJSValUnchecked =<< (arrayClass # "from") [keys]

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

newBuffer :: BaseAudioContext context => context -> Int -> Int -> Double -> IO AudioBuffer
newBuffer context channels frames rate = AudioBuffer <$> (context # "createBuffer") (channels, frames, rate)

decodeAudioData :: (BaseAudioContext context, ToJSVal bytes) => context -> bytes -> IO AudioBuffer
decodeAudioData context bytes = do
  handle <- toJSVal bytes
  promise <- (context # "decodeAudioData") [handle]
  AudioBuffer <$> settled promise

fetchAudioBuffer :: BaseAudioContext context => context -> MisoString -> IO AudioBuffer
fetchAudioBuffer context url = do
  response <- settled =<< jsg1 "fetch" url
  bytes <- settled =<< (response # "arrayBuffer") ()
  decodeAudioData context bytes

freshFloat32 :: Int -> IO JSVal
freshFloat32 size = do
  constructor <- jsg "Float32Array"
  new constructor [size]

freshUint8 :: Int -> IO JSVal
freshUint8 size = do
  constructor <- jsg "Uint8Array"
  new constructor [size]

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

writeChannel :: AudioBuffer -> Int -> [Double] -> IO ()
writeChannel buffer channel samples = do
  target <- (buffer # "getChannelData") [channel]
  fill target samples
  freeJSVal target

readChannel :: AudioBuffer -> Int -> IO [Double]
readChannel buffer channel = do
  samples <- (buffer # "getChannelData") [channel]
  values <- numbersOf samples
  freeJSVal samples
  pure values

bufferLength :: AudioBuffer -> IO Int
bufferLength buffer = readProperty buffer "length"

bufferChannels :: AudioBuffer -> IO Int
bufferChannels buffer = readProperty buffer "numberOfChannels"

bufferSampleRate :: AudioBuffer -> IO Double
bufferSampleRate buffer = readProperty buffer "sampleRate"

bufferDuration :: AudioBuffer -> IO Double
bufferDuration buffer = readProperty buffer "duration"

releaseHandle :: ToJSVal handle => handle -> IO ()
releaseHandle handle = freeJSVal =<< toJSVal handle
