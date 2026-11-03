module Miso.WebAudio.Types
  ( -- * Contexts
    BaseAudioContext
  , AudioContext (..)
  , OfflineAudioContext (..)
  , LatencyHint (..)
  , ContextState (..)
  , OutputTimestamp (..)
    -- * Graph
  , AudioNode
  , AudioDestinationNode (..)
  , ChannelCountMode (..)
  , ChannelInterpretation (..)
    -- * Parameters
  , AudioParam (..)
  , AudioParamMap (..)
  , AutomationRate (..)
    -- * Shared capabilities
  , AudioSource
  , HasGain
  , HasFrequency
  , HasDetune
  , HasBuffer
  , HasFrequencyResponse
  , HasPosition
    -- * Sources
  , OscillatorNode (..)
  , PeriodicWave (..)
  , AudioBuffer (..)
  , AudioBufferSourceNode (..)
  , ConstantSourceNode (..)
    -- * Filters
  , GainNode (..)
  , BiquadFilterNode (..)
  , FilterType (..)
  , IIRFilterNode (..)
  , WaveShaperNode (..)
  , Oversample (..)
  , DynamicsCompressorNode (..)
  , ConvolverNode (..)
  , DelayNode (..)
    -- * Analysis
  , AnalyserNode (..)
  , AudioPlaybackStats (..)
    -- * Channels
  , ChannelSplitterNode (..)
  , ChannelMergerNode (..)
    -- * Spatial
  , StereoPannerNode (..)
  , PannerNode (..)
  , PanningModel (..)
  , DistanceModel (..)
  , AudioListener (..)
    -- * Media
  , MediaElementAudioSourceNode (..)
  , MediaStreamAudioSourceNode (..)
  , MediaStreamTrackAudioSourceNode (..)
  , MediaStreamAudioDestinationNode (..)
    -- * Worklets
  , AudioWorkletNode (..)
    -- * Handles
  , releaseHandle
  ) where

import Miso.DSL (FromJSVal (fromJSVal), JSVal, ToJSVal (..), ToObject, freeJSVal)
import Miso.String (MisoString)

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

instance ToJSVal LatencyHint where
  toJSVal = \case
    LatencyInteractive -> toJSVal @MisoString "interactive"
    LatencyBalanced -> toJSVal @MisoString "balanced"
    LatencyPlayback -> toJSVal @MisoString "playback"
    LatencySeconds latency -> toJSVal latency

data OutputTimestamp = OutputTimestamp
  { outputContextTime :: Double
  , outputPerformanceTime :: Double
  }
  deriving (Eq, Show)

data ChannelCountMode = ChannelMax | ChannelClampedMax | ChannelExplicit
  deriving (Eq, Show)

instance ToJSVal ChannelCountMode where
  toJSVal mode = toJSVal @MisoString $ case mode of
    ChannelMax -> "max"
    ChannelClampedMax -> "clamped-max"
    ChannelExplicit -> "explicit"

data ChannelInterpretation = Speakers | Discrete
  deriving (Eq, Show)

instance ToJSVal ChannelInterpretation where
  toJSVal interpretation = toJSVal @MisoString $ case interpretation of
    Speakers -> "speakers"
    Discrete -> "discrete"

data AutomationRate = ARate | KRate
  deriving (Eq, Show)

instance ToJSVal AutomationRate where
  toJSVal rate = toJSVal @MisoString $ case rate of
    ARate -> "a-rate"
    KRate -> "k-rate"

data PanningModel = EqualPower | HRTF
  deriving (Eq, Show)

instance ToJSVal PanningModel where
  toJSVal model = toJSVal @MisoString $ case model of
    EqualPower -> "equalpower"
    HRTF -> "HRTF"

data DistanceModel = LinearDistance | InverseDistance | ExponentialDistance
  deriving (Eq, Show)

instance ToJSVal DistanceModel where
  toJSVal model = toJSVal @MisoString $ case model of
    LinearDistance -> "linear"
    InverseDistance -> "inverse"
    ExponentialDistance -> "exponential"

data ContextState = Suspended | Running | Closed | Interrupted
  deriving (Eq, Show)

instance FromJSVal ContextState where
  fromJSVal handle = fmap stateNamed <$> fromJSVal handle
    where
      stateNamed :: MisoString -> ContextState
      stateNamed = \case
        "running" -> Running
        "closed" -> Closed
        "interrupted" -> Interrupted
        _ -> Suspended

data FilterType = Lowpass | Highpass | Bandpass | Lowshelf | Highshelf | Peaking | Notch | Allpass
  deriving (Eq, Show)

instance ToJSVal FilterType where
  toJSVal kind = toJSVal @MisoString $ case kind of
    Lowpass -> "lowpass"
    Highpass -> "highpass"
    Bandpass -> "bandpass"
    Lowshelf -> "lowshelf"
    Highshelf -> "highshelf"
    Peaking -> "peaking"
    Notch -> "notch"
    Allpass -> "allpass"

data Oversample = OversampleNone | Oversample2x | Oversample4x
  deriving (Eq, Show)

instance ToJSVal Oversample where
  toJSVal amount = toJSVal @MisoString $ case amount of
    OversampleNone -> "none"
    Oversample2x -> "2x"
    Oversample4x -> "4x"

releaseHandle :: ToJSVal handle => handle -> IO ()
releaseHandle handle = freeJSVal =<< toJSVal handle
