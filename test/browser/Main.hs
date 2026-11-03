{-# LANGUAGE CPP #-}
module Main (main) where

import Control.Concurrent (forkIO, killThread)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (SomeException, displayException, evaluate, try)
import Control.Monad (forM_, replicateM_, void, when)
import Data.Either (isLeft, isRight)
import Data.Foldable (for_)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Maybe (isJust)
import Miso.DSL
  ( FromJSVal (fromJSValUnchecked)
  , JSVal
  , Object (unObject)
  , ToJSVal (..)
  , ToObject
  , asyncCallback
  , await
  , create
  , createWith
  , global
  , isUndefined
  , jsg
  , jsg0
  , jsg1
  , jsNull
  , new
  , now_ffi
  , setField
  , syncCallback
  , syncCallback1
  , (!)
  , (#)
  )
import Miso.DSL qualified as DSL ((!!))
import Miso.Effect (Effect, Schedule (..), Sink, mkComponentInfo, runEffect)
import Miso.FFI (ArrayBuffer (..))
import Miso.Media (Media (..))
import Miso.String (MisoString, fromMisoString, ms)
import Miso.WebAudio
  ( AnalyserNode
  , AudioBuffer
  , AudioContext (..)
  , AudioNode
  , AudioParam (..)
  , AutomationRate (..)
  , BaseAudioContext
  , BiquadFilterNode
  , ChannelCountMode (..)
  , ChannelInterpretation (..)
  , ContextState (..)
  , DistanceModel (..)
  , DynamicsCompressorNode
  , FilterType (..)
  , LatencyHint (..)
  , Note (..)
  , OfflineAudioContext (..)
  , OutputTimestamp (outputContextTime, outputPerformanceTime)
  , Oversample (..)
  , PanningModel (..)
  , Wave (..)
  , addModule
  , addModule_
  , attack
  , averageLatency
  , baseLatency
  , bufferDuration
  , bufferLength
  , bufferSampleRate
  , cancelAndHoldAtTime
  , cancelScheduledValues
  , channelCount
  , close
  , closePlayer
  , connect
  , connectOutputToParam
  , connectParam
  , connectPorts
  , contextState
  , contextStateSub
  , createAnalyser
  , createBiquadFilter
  , createBuffer
  , createBufferSource
  , createChannelMerger
  , createChannelSplitter
  , createConstantSource
  , createConvolver
  , createDelay
  , createDynamicsCompressor
  , createGain
  , createIIRFilter
  , createMediaElementSource
  , createMediaStreamDestination
  , createMediaStreamSource
  , createMediaStreamTrackSource
  , createOscillator
  , createPanner
  , createPeriodicWave
  , createStereoPanner
  , createWaveShaper
  , decodeAudioData
  , decodeAudioData_
  , defaultValue
  , delayTime
  , destination
  , destinationStream
  , detune
  , disconnect
  , disconnectFrom
  , disconnectOutput
  , disconnectParam
  , disconnectPorts
  , exponentialRampToValueAtTime
  , fetchAudioBuffer
  , fetchAudioBuffer_
  , fftSize
  , forwardX
  , forwardY
  , forwardZ
  , frequency
  , frequencyBinCount
  , gain
  , getByteFrequencyData
  , getByteTimeDomainData
  , getFloatFrequencyData
  , getFloatTimeDomainData
  , getFrequencyResponse
  , getOutputTimestamp
  , hasCancelAndHold
  , hasSetSinkId
  , knee
  , linearRampToValueAtTime
  , listener
  , lookupParam
  , maxChannelCount
  , maximumLatency
  , maxValue
  , minimumLatency
  , minValue
  , newAudioContext
  , newAudioContextAtRate
  , newAudioWorkletNode
  , newAudioWorkletNodeWith
  , newOfflineAudioContext
  , newPlayer
  , numberOfChannels
  , numberOfInputs
  , numberOfOutputs
  , offlineLength
  , offset
  , onComplete
  , onComplete_
  , onEnded
  , onEnded_
  , orientationX
  , orientationY
  , orientationZ
  , pan
  , paramNames
  , paramValue
  , playbackRate
  , playbackStats
  , playNotes
  , positionX
  , positionY
  , positionZ
  , q
  , ratio
  , readChannel
  , reduction
  , release
  , resetLatency
  , resume
  , resumeOffline
  , sampleRate
  , scheduleNotes
  , setAutomationRate
  , setBuffer
  , setChannelCount
  , setChannelCountMode
  , setChannelInterpretation
  , setConeInnerAngle
  , setConeOuterAngle
  , setConeOuterGain
  , setCurve
  , setDistanceModel
  , setFftSize
  , setFilterType
  , setListenerOrientation
  , setListenerPosition
  , setLoop
  , setLoopEnd
  , setLoopStart
  , setMaxDecibels
  , setMaxDistance
  , setMinDecibels
  , setMuted
  , setNormalize
  , setOscillatorType
  , setOversample
  , setPanningModel
  , setPeriodicWave
  , setRefDistance
  , setRolloffFactor
  , setSinkId
  , setSmoothingTimeConstant
  , setTargetAtTime
  , setValue
  , setValueAtTime
  , setValueCurveAtTime
  , start
  , startAtOffset
  , startFor
  , startRendering
  , startRendering_
  , stop
  , suspendOfflineAt
  , suspendOfflineAt_
  , threshold
  , totalDuration
  , underrunDuration
  , underrunEvents
  , upX
  , upY
  , upZ
  , workletParameters
  , workletPort
  , writeChannel
  )

#ifdef WASM
foreign export javascript "hs_start" main :: IO ()
#endif

rate :: Double
rate = 44100

must :: IO (Either MisoString result) -> IO result
must action = action >>= either (fail . fromMisoString) pure

runEffects :: Effect () () () action -> Sink action -> IO ()
runEffects effect sink = do
  mountPoint <- jsg "document"
  let (_, schedules) = runEffect effect (mkComponentInfo 0 0 mountPoint () ()) ()
  for_ schedules $ \case
    Schedule _ job -> void (forkIO (job sink))
    _ -> pure ()

captured :: ((result -> Either MisoString result) -> (MisoString -> Either MisoString result) -> Effect () () () (Either MisoString result)) -> IO (Either MisoString result)
captured effect = do
  slot <- newEmptyMVar
  runEffects (effect Right Left) (putMVar slot)
  takeMVar slot

capturedDone :: (Either MisoString () -> (MisoString -> Either MisoString ()) -> Effect () () () (Either MisoString ())) -> IO (Either MisoString ())
capturedDone effect = captured (\successful errorful -> effect (successful ()) errorful)

recipes :: [Note]
recipes =
  concat
    [ at 0.0 [Note Sine 0 400 (Just (720, 0.08)) 0.3 0.12 0.13]
    , at 0.2 [Note Triangle 0 180 (Just (110, 0.06)) 0.12 0.07 0.08]
    , at 0.4
        [ Note Triangle 0 261.63 (Just (274.7115, 0.1)) 0.2 0.35 0.37
        , Note Triangle 0 261.63 (Just (274.7115, 0.1)) 0.16 0.35 0.37
        , Note Triangle 0 329.63 (Just (346.1115, 0.1)) 0.16 0.35 0.37
        ]
    , at 0.9 [Note Sawtooth 0 293.66 (Just (308.343, 0.1)) 0.25 0.12 0.14]
    , at 1.1 [Note Sawtooth 0 140 (Just (30, 0.35)) 0.4 0.38 0.4]
    , at 1.6 [Note Sine 0 120 (Just (380, 0.25)) 0.18 0.28 0.3]
    , at 2.0 [Note Triangle 0 220 (Just (880, 0.15)) 0.25 0.18 0.2]
    , at 2.3 [Note Sine 0 450 (Just (180, 0.2)) 0.25 0.22 0.24]
    , at 2.6 [Note Sawtooth 0 320 (Just (80, 0.4)) 0.3 0.42 0.45]
    , at 3.1 [Note Sine (fromIntegral index * 0.08) freq Nothing 0.2 0.35 0.38 | (index, freq) <- zip [0 :: Int ..] [440, 554.37, 659.25, 880]]
    , at 3.8 [Note Sine (fromIntegral index * 0.12) freq Nothing 0.22 0.45 0.48 | (index, freq) <- zip [0 :: Int ..] [330, 311.13, 293.66, 261.63]]
    , at 4.8 [Note Sine 0 620 (Just (840, 0.04)) 0.08 0.05 0.06]
    , at 5.0 [Note Square 0 220 (Just (110, 0.1)) 0.1 0.15 0.2]
    ]
  where
    at shift = map (\note -> note { noteStart = noteStart note + shift })

renderNotes :: IO AudioBuffer
renderNotes = do
  context <- newOfflineAudioContext 1 (seconds 5.5) rate
  master <- createGain context
  masterLevel <- gain master
  setValueAtTime masterLevel 0.4 0
  connect master =<< destination context
  scheduleNotes context master 0 recipes
  must (startRendering_ context)

seconds :: Double -> Int
seconds duration = ceiling (duration * rate)

parkMiller :: Double -> [Double]
parkMiller seed =
  let next = (seed * 16807) - 2147483647 * fromIntegral (floor ((seed * 16807) / 2147483647) :: Int)
   in (next / 1073741823.5 - 1) : parkMiller next

noiseBuffer :: BaseAudioContext context => context -> Double -> Double -> IO AudioBuffer
noiseBuffer context seed duration = do
  buffer <- createBuffer context 1 (seconds duration) rate
  writeChannel buffer 0 (take (seconds duration) (parkMiller seed))
  pure buffer

setParam :: IO AudioParam -> Double -> IO ()
setParam getParam value = do
  target <- getParam
  setValue target value

newFilter :: BaseAudioContext context => context -> FilterType -> Double -> IO BiquadFilterNode
newFilter context kind hz = do
  node <- createBiquadFilter context
  setFilterType node kind
  setParam (frequency node) hz
  pure node

renderKnock :: IO AudioBuffer
renderKnock = do
  context <- newOfflineAudioContext 1 (seconds 0.5) rate
  master <- createGain context
  setParam (gain master) 0.5
  connect master =<< destination context
  let t0 = 0.01
      peak = 0.55
      bright = 2400
      low = 180
  burst <- createBufferSource context
  setBuffer burst =<< noiseBuffer context 42 0.06
  band <- newFilter context Bandpass bright
  bandFrequency <- frequency band
  setValueAtTime bandFrequency bright t0
  exponentialRampToValueAtTime bandFrequency (bright * 0.4) (t0 + 0.05)
  setParam (q band) 1.6
  burstLevel <- createGain context
  envelope burstLevel t0 0.003 peak 0.05
  connect burst band
  connect band burstLevel
  connect burstLevel master
  start burst t0
  thump <- createOscillator context
  setOscillatorType thump Sine
  thumpFrequency <- frequency thump
  setValueAtTime thumpFrequency low t0
  exponentialRampToValueAtTime thumpFrequency (low * 0.55) (t0 + 0.002 + 0.09)
  thumpLevel <- createGain context
  envelope thumpLevel t0 0.002 (peak * 0.9) 0.09
  connect thump thumpLevel
  connect thumpLevel master
  start thump t0
  stop thump (t0 + 0.002 + 0.09 + 0.05)
  must (startRendering_ context)
  where
    envelope node begin rise top fall = do
      level <- gain node
      setValueAtTime level 0 begin
      linearRampToValueAtTime level top (begin + rise)
      exponentialRampToValueAtTime level 0.0001 (begin + rise + fall)

saturationCurve :: Double -> [Double]
saturationCurve soil = map shape [0 .. n - 1]
  where
    n = 4096 :: Double
    k = 0.9 - 0.5 * soil
    shape index =
      let x = (index / (n - 1)) * 2 - 1
          a = abs x
          y = if a <= k then a else k + (1 - k) * tanh ((a - k) / (1 - k))
       in signum x * y

roomImpulse :: BaseAudioContext context => context -> IO AudioBuffer
roomImpulse context = do
  let duration = 0.4
      frames = seconds duration
      decay = log 1000 / duration
      channel seed = zipWith (\index sample -> sample * exp (-decay * (fromIntegral index / rate))) [0 :: Int ..] (take frames (parkMiller seed))
  buffer <- createBuffer context 2 frames rate
  writeChannel buffer 0 (channel 7)
  writeChannel buffer 1 (channel 11)
  pure buffer

newCompressor :: BaseAudioContext context => context -> Double -> Double -> Double -> Double -> Double -> IO DynamicsCompressorNode
newCompressor context limit bend steep rise fall = do
  node <- createDynamicsCompressor context
  setParam (threshold node) limit
  setParam (knee node) bend
  setParam (ratio node) steep
  setParam (attack node) rise
  setParam (release node) fall
  pure node

renderGarden :: IO AudioBuffer
renderGarden = do
  context <- newOfflineAudioContext 2 (seconds 2) rate
  output <- destination context
  master <- createGain context
  setParam (gain master) 0.5
  highpass <- newFilter context Highpass 30
  shelf <- newFilter context Highshelf 6000
  setParam (gain shelf) (-2.5)
  glue <- newCompressor context (-20) 12 2.5 0.02 0.25
  limiter <- newCompressor context (-3) 0 20 0.001 0.1
  post <- createGain context
  setParam (gain post) 0.63
  connect master highpass
  connect highpass shelf
  connect shelf glue
  connect glue limiter
  connect limiter post
  connect post output
  sendFilter <- newFilter context Highpass 200
  room <- createConvolver context
  setBuffer room =<< roomImpulse context
  returnFilter <- newFilter context Lowpass 7000
  connect sendFilter room
  connect room returnFilter
  connect returnFilter master
  lfo <- createOscillator context
  setParam (frequency lfo) 5.1
  start lfo 0
  noise <- noiseBuffer context 99 2
  input <- createGain context
  shaper <- createWaveShaper context
  setOversample shaper Oversample2x
  setCurve shaper (saturationCurve 0.5)
  lowpass <- newFilter context Lowpass 7000
  setParam (q lowpass) 0.7
  volume <- createGain context
  setParam (gain volume) 0.56
  duck <- createGain context
  send <- createGain context
  setParam (gain send) (40 / 127)
  connect input shaper
  connect shaper lowpass
  connect lowpass volume
  connect volume duck
  connect duck master
  connect duck send
  connect send sendFilter
  pitchBus <- createGain context
  bend <- createConstantSource context
  setParam (offset bend) 0
  connect bend pitchBus
  start bend 0
  vibrato <- createGain context
  setParam (gain vibrato) 12
  connect lfo vibrato
  connect vibrato pitchBus
  bendOffset <- offset bend
  setTargetAtTime bendOffset 40 0.3 0.02
  volumeLevel <- gain volume
  cancelScheduledValues volumeLevel 0.5
  setTargetAtTime volumeLevel 0.4 0.5 0.03
  duckLevel <- gain duck
  cancelAndHoldAtTime duckLevel 0.8
  setTargetAtTime duckLevel 0.5 0.8 0.02
  setTargetAtTime duckLevel 1 1.0 0.1
  let voiceOscillator wave hz begin target = do
        node <- createOscillator context
        setOscillatorType node wave
        nodeFrequency <- frequency node
        setValueAtTime nodeFrequency hz begin
        connectParam pitchBus =<< detune node
        connect node target
        start node begin
        pure node
      hold node t fade seconds' = do
        level <- gain node
        cancelAndHoldAtTime level t
        setTargetAtTime level 0 t (fade / 4)
        pure (t + seconds')
  moss <- createGain context
  connect moss input
  mossLevel <- gain moss
  setValueAtTime mossLevel 0 0.05
  linearRampToValueAtTime mossLevel 0.5 (0.05 + 0.004)
  setTargetAtTime mossLevel (0.5 * 0.25) (0.05 + 0.004) (0.5 / 3)
  overtone <- createGain context
  setParam (gain overtone) 0.35
  connect overtone moss
  clickLevel <- createGain context
  clickFilter <- newFilter context Lowpass 3500
  setParam (q clickFilter) 0.7
  connect clickFilter moss
  connect clickLevel clickFilter
  clickGain <- gain clickLevel
  setValueAtTime clickGain 0.35 0.05
  setTargetAtTime clickGain 0 0.05 0.006
  body <- voiceOscillator Sine 220 0.05 moss
  second <- voiceOscillator Sine 440 0.05 overtone
  click <- voiceOscillator Triangle 1320 0.05 clickLevel
  mossEnd <- hold moss 0.7 0.12 0.18
  for_ [body, second, click] (`stop` mossEnd)
  breath <- createGain context
  setParam (gain breath) 0.2
  connect breath input
  breathFilter <- newFilter context Bandpass 880
  setParam (q breathFilter) 1.2
  connect breathFilter breath
  air <- createBufferSource context
  setBuffer air noise
  setLoop air True
  connect air breathFilter
  startAtOffset air 0.2 0.5
  stop air 0.9
  stolen <- createGain context
  connect stolen input
  stolenLevel <- gain stolen
  setValueAtTime stolenLevel 0.3 0.3
  voice <- voiceOscillator Sawtooth 110 0.3 stolen
  cancelAndHoldAtTime stolenLevel 1.0
  linearRampToValueAtTime stolenLevel 0 (1.0 + 0.015)
  stop voice (1.0 + 0.015 + 0.005)
  must (startRendering_ context)

renderRouting :: IO AudioBuffer
renderRouting = do
  context <- newOfflineAudioContext 2 (seconds 1) rate
  output <- destination context
  a <- createOscillator context
  setParam (frequency a) 220
  b <- createOscillator context
  setOscillatorType b Triangle
  setParam (frequency b) 330
  inMerge <- createChannelMerger context 2
  connectPorts a 0 inMerge 0
  connectPorts b 0 inMerge 1
  splitter <- createChannelSplitter context 2
  connect inMerge splitter
  outMerge <- createChannelMerger context 2
  connectPorts splitter 0 outMerge 1
  connectPorts splitter 1 outMerge 0
  connect outMerge output
  delay <- createDelay context 0.5
  delayParam <- delayTime delay
  setValueAtTime delayParam 0.25 0
  feedback <- createGain context
  setParam (gain feedback) 0.5
  connectPorts splitter 0 delay 0
  connect delay feedback
  connect feedback delay
  connectPorts feedback 0 outMerge 0
  removed <- createGain context
  connect a removed
  connect removed output
  disconnectFrom a removed
  mono <- createGain context
  setChannelCount mono 1
  setChannelCountMode mono ChannelExplicit
  setChannelInterpretation mono Speakers
  setParam (gain mono) 0.3
  connect inMerge mono
  connect mono output
  monoLevel <- gain mono
  connectOutputToParam splitter 1 monoLevel
  discrete <- createGain context
  setChannelCount discrete 1
  setChannelCountMode discrete ChannelExplicit
  setChannelInterpretation discrete Discrete
  setParam (gain discrete) 0.2
  connect inMerge discrete
  connect discrete output
  second <- createChannelSplitter context 2
  connect inMerge second
  connectPorts second 0 output 0
  connectPorts second 1 output 0
  disconnectOutput second 1
  disconnectPorts second 0 output 0
  for_ [a, b] $ \node -> do
    start node 0
    stop node 1
  must (startRendering_ context)

renderSpace :: IO AudioBuffer
renderSpace = do
  context <- newOfflineAudioContext 2 (seconds 1) rate
  output <- destination context
  ears <- listener context
  setParam (positionX ears) 0.5
  setParam (positionY ears) 0.25
  setParam (positionZ ears) 0
  setParam (forwardX ears) 0
  setParam (forwardY ears) 0
  setParam (forwardZ ears) (-1)
  setParam (upX ears) 0
  setParam (upY ears) 1
  setParam (upZ ears) 0
  sweep <- createOscillator context
  setParam (frequency sweep) 440
  stereo <- createStereoPanner context
  panning <- pan stereo
  setValueAtTime panning (-1) 0
  linearRampToValueAtTime panning 1 0.5
  connect sweep stereo
  connect stereo output
  voice <- createOscillator context
  setParam (frequency voice) 660
  near <- createPanner context
  setPanningModel near EqualPower
  setDistanceModel near InverseDistance
  setRefDistance near 1
  setMaxDistance near 100
  setRolloffFactor near 1
  setConeInnerAngle near 60
  setConeOuterAngle near 120
  setConeOuterGain near 0.2
  setParam (positionZ near) (-2)
  nearX <- positionX near
  setValueAtTime nearX (-3) 0
  linearRampToValueAtTime nearX 3 1
  setParam (orientationX near) 1
  setParam (orientationY near) 0
  setParam (orientationZ near) 0
  connect voice near
  connect near output
  far <- createOscillator context
  setParam (frequency far) 880
  distant <- createPanner context
  setDistanceModel distant LinearDistance
  setParam (positionX distant) 4
  connect far distant
  connect distant output
  farther <- createOscillator context
  setParam (frequency farther) 990
  remote <- createPanner context
  setDistanceModel remote ExponentialDistance
  setParam (positionX remote) (-6)
  connect farther remote
  connect remote output
  for_ [sweep, voice, far, farther] $ \node -> do
    start node 0
    stop node 1
  must (startRendering_ context)

renderListener :: IO AudioBuffer
renderListener = do
  context <- newOfflineAudioContext 2 (seconds 0.5) rate
  output <- destination context
  ears <- listener context
  setListenerPosition ears 1 0 0
  setListenerOrientation ears 0 0 (-1) 0 1 0
  tone <- createOscillator context
  setParam (frequency tone) 500
  source <- createPanner context
  setParam (positionX source) (-2)
  connect tone source
  connect source output
  start tone 0
  stop tone 0.5
  must (startRendering_ context)

renderTimbre :: IO AudioBuffer
renderTimbre = do
  context <- newOfflineAudioContext 1 (seconds 1) rate
  output <- destination context
  wave <- createPeriodicWave context [0, 0.5, 0.25] [0, 1, 0.5] False
  custom <- createOscillator context
  setPeriodicWave custom wave
  setParam (frequency custom) 220
  iir <- createIIRFilter context [0.1, 0.2, 0.1] [1, -0.5, 0.2]
  shaped <- createGain context
  shapedLevel <- gain shaped
  setValueCurveAtTime shapedLevel [0, 1, 0.5, 0.75] 0.05 0.5
  connect custom iir
  connect iir shaped
  connect shaped output
  start custom 0
  stop custom 1
  noise <- noiseBuffer context 5 0.5
  looped <- createBufferSource context
  setBuffer looped noise
  setLoop looped True
  setLoopStart looped 0.1
  setLoopEnd looped 0.2
  setParam (playbackRate looped) 1.5
  filterNode <- newFilter context Lowpass 1200
  quiet <- createGain context
  quietLevel <- gain quiet
  setAutomationRate quietLevel KRate
  setValueAtTime quietLevel 0 0.1
  linearRampToValueAtTime quietLevel 0.4 0.5
  connect looped filterNode
  connect filterNode quiet
  connect quiet output
  startFor looped 0.1 0.1 0.6
  impulse <- createBuffer context 1 2205 rate
  writeChannel impulse 0 (take 2205 (parkMiller 77))
  room <- createConvolver context
  setNormalize room False
  setBuffer room impulse
  dry <- createOscillator context
  setOscillatorType dry Square
  setParam (frequency dry) 110
  wet <- createGain context
  setParam (gain wet) 0.02
  connect dry wet
  connect wet room
  connect room output
  start dry 0.2
  stop dry 0.6
  must (startRendering_ context)

renderSample :: IO AudioBuffer
renderSample = do
  context <- newOfflineAudioContext 1 (seconds 1) rate
  output <- destination context
  bytes <- ArrayBuffer <$> jsg0 "__wavBytes"
  decoded <- must (decodeAudioData_ context bytes)
  url <- fromJSValUnchecked =<< jsg0 "__wavUrl"
  fetched <- must (fetchAudioBuffer_ context url)
  first <- createBufferSource context
  setBuffer first decoded
  connect first output
  start first 0
  second <- createBufferSource context
  setBuffer second fetched
  setParam (detune second) 700
  connect second output
  start second 0.5
  must (startRendering_ context)

renderWorklet :: Object -> IO AudioBuffer
renderWorklet target = do
  context <- newOfflineAudioContext 1 (seconds 0.5) rate
  output <- destination context
  must (addModule_ context "worklet.js")
  counts <- toJSVal [1 :: Int]
  options <- createWith [("outputChannelCount" :: MisoString, counts)]
  node <- newAudioWorkletNodeWith context "half-gain" options
  plain <- newAudioWorkletNode context "half-gain"
  disconnect plain
  parameters <- workletParameters node
  names <- paramNames parameters
  setField target "workletParamNames" (names == ["level"])
  missing <- lookupParam parameters "absent"
  setField target "workletMissingParam" (not (isJust missing))
  port <- workletPort node
  portMissing <- isUndefined port
  setField target "workletPort" (not portMissing)
  lookupParam parameters "level" >>= \case
    Nothing -> setField target "workletLevelParam" False
    Just level -> do
      setField target "workletLevelParam" True
      setValueAtTime level 1 0
      linearRampToValueAtTime level 0.1 0.4
  tone <- createOscillator context
  setParam (frequency tone) 300
  connect tone node
  connect node output
  start tone 0
  stop tone 0.5
  must (startRendering_ context)

analysisReadings :: Object -> IO ()
analysisReadings target = do
  context <- newOfflineAudioContext 1 (seconds 1) rate
  output <- destination context
  tone <- createOscillator context
  setParam (frequency tone) 1000
  squeeze <- newCompressor context (-40) 0 20 0.001 0.1
  meter <- createAnalyser context
  setFftSize meter 1024
  setSmoothingTimeConstant meter 0
  setMinDecibels meter (-90)
  setMaxDecibels meter (-10)
  connect tone squeeze
  connect squeeze meter
  connect meter output
  start tone 0
  reached <- suspendOfflineAt_ context 0.5
  finished <- newEmptyMVar
  void . forkIO $ do
    must reached
    setField target "time" =<< getFloatTimeDomainData meter
    setField target "frequency" =<< getFloatFrequencyData meter
    setField target "byteTime" =<< getByteTimeDomainData meter
    setField target "byteFrequency" =<< getByteFrequencyData meter
    setField target "reduction" . (: []) =<< reduction squeeze
    resumeOffline context
    putMVar finished ()
  void (must (startRendering_ context))
  takeMVar finished
  biquad <- newFilter context Peaking 1000
  setParam (q biquad) 2
  setParam (gain biquad) 6
  iir <- createIIRFilter context [0.1, 0.2, 0.1] [1, -0.5, 0.2]
  let hertz = [100, 440, 1000, 4000]
  biquadResponse <- getFrequencyResponse biquad hertz
  iirResponse <- getFrequencyResponse iir hertz
  setField target "biquadMagnitude" (map fst biquadResponse)
  setField target "biquadPhase" (map snd biquadResponse)
  setField target "iirMagnitude" (map fst iirResponse)
  setField target "iirPhase" (map snd iirResponse)

newtype RawDelay = RawDelay JSVal
  deriving (ToJSVal, ToObject)

instance AudioNode RawDelay

timed :: IO () -> IO Double
timed action = do
  begin <- now_ffi
  action
  end <- now_ffi
  pure (end - begin)

benchmarks :: Object -> IO ()
benchmarks target = do
  let samples = take 96000 (parkMiller 3)
  void (evaluate (sum samples))
  context <- newOfflineAudioContext 1 44100 rate
  buffer <- createBuffer context 1 96000 rate
  writeTime <- timed (writeChannel buffer 0 samples)
  setField target "writeChannel96k" writeTime
  arrayTime <- timed $ do
    list <- toJSVal samples
    typed <- flip new [list] =<< jsg ("Float32Array" :: MisoString)
    void ((buffer # ("copyToChannel" :: MisoString)) (typed, 0 :: Int))
  setField target "viaArray96k" arrayTime
  master <- createGain context
  noteTime <- timed (replicateM_ 1000 (scheduleNotes context master 0 [Note Sine 0 440 (Just (880, 0.1)) 0.3 0.1 0.12]))
  setField target "schedule1000Notes" noteTime
  voiceContext <- newOfflineAudioContext 1 44100 rate
  voiceTime <- timed (replicateM_ 200 (benchVoice voiceContext))
  setField target "schedule200Voices" voiceTime

benchVoice :: OfflineAudioContext -> IO ()
benchVoice context = do
  out <- createGain context
  outLevel <- gain out
  setValueAtTime outLevel 0 0
  linearRampToValueAtTime outLevel 0.5 0.004
  setTargetAtTime outLevel 0.1 0.004 0.17
  overtone <- createGain context
  setParam (gain overtone) 0.35
  connect overtone out
  lowpass <- newFilter context Lowpass 3500
  connect lowpass out
  click <- createGain context
  connect click lowpass
  forM_ [(Sine, 220, out), (Sine, 440, overtone), (Triangle, 1320, click)] $ \(wave, hz, target) -> do
    node <- createOscillator context
    setOscillatorType node wave
    nodeFrequency <- frequency node
    setValueAtTime nodeFrequency hz 0
    connect node target
    start node 0
    stop node 0.5

-- XXX: Workaround for a GHC wasm bug that blows up compile times. Keep.
{-# NOINLINE checks #-}
checks :: Object -> IO ()
checks target = do
  context <- newOfflineAudioContext 1 4410 rate
  rateRead <- sampleRate context
  setField target "sampleRate" (rateRead == rate)
  stateName <- contextState context
  setField target "offlineStartsSuspended" (stateName == Suspended)
  buffer <- createBuffer context 2 4 rate
  writeChannel buffer 1 [0.5, -0.25, 0.125, 1]
  roundTrip <- readChannel buffer 1
  setField target "writeThenRead" (roundTrip == [0.5, -0.25, 0.125, 1])
  frames <- bufferLength buffer
  channels <- numberOfChannels buffer
  bufferRate <- bufferSampleRate buffer
  setField target "bufferShape" (frames == 4 && channels == 2 && bufferRate == rate)
  node <- createGain context
  other <- createGain context
  connected <- gain other
  connectParam node connected
  disconnectParam node connected
  setField target "disconnectParamConnected" True
  hasHold <- hasCancelAndHold connected
  setField target "cancelAndHoldDetected" hasHold
  glideResult <- try (scheduleNotes context node 0 [Note Sine 0 440 (Just (0, 0.1)) 0.3 0.1 0.12, Note Sine 0 440 (Just (-5, 0.1)) 0.3 0.1 0.12])
  setField target "glideToZeroAccepted" (either (\(_ :: SomeException) -> False) (const True) glideResult)
  negativeResult <- try (scheduleNotes context node 0 [Note Sine (-1) 440 (Just (880, -1)) 0.3 (-1) (-1)])
  setField target "negativeTimesAccepted" (either (\(_ :: SomeException) -> False) (const True) negativeResult)
  ended <- newIORef (0 :: Int)
  endContext <- newOfflineAudioContext 1 4410 rate
  endOutput <- destination endContext
  forM_ [0 .. 49 :: Int] $ \index -> do
    source <- createOscillator endContext
    connect source endOutput
    start source 0
    stop source (fromIntegral index * 0.001 + 0.001)
    onEnded_ source (modifyIORef' ended (+ 1))
  void (must (startRendering_ endContext))
  void (waitFor 2000 ((== 50) <$> readIORef ended))
  endedCount <- readIORef ended
  setField target "onEndedCount" endedCount
  paramContext <- newOfflineAudioContext 2 4410 rate
  level <- gain =<< createGain paramContext
  setValue level 0.5
  levelValue <- paramValue level
  levelDefault <- defaultValue level
  levelMin <- minValue level
  levelMax <- maxValue level
  setField target "paramReads" (levelValue == 0.5 && levelDefault == 1 && levelMin < 0 && levelMax > 1)
  splitter <- createChannelSplitter paramContext 3
  merger <- createChannelMerger paramContext 4
  splitterOutputs <- numberOfOutputs splitter
  mergerInputs <- numberOfInputs merger
  setField target "channelPorts" (splitterOutputs == 3 && mergerInputs == 4)
  countNode <- createGain paramContext
  setChannelCount countNode 1
  countRead <- channelCount countNode
  setField target "channelCount" (countRead == 1)
  offlineFrames <- offlineLength paramContext
  setField target "offlineLength" (offlineFrames == 4410)
  outputChannels <- maxChannelCount =<< destination paramContext
  setField target "maxChannelCount" (outputChannels == 2)
  duration <- bufferDuration buffer
  setField target "bufferDuration" (duration == 4 / rate)
  meter <- createAnalyser paramContext
  setFftSize meter 2048
  meterSize <- fftSize meter
  meterBins <- frequencyBinCount meter
  setField target "analyserSizes" (meterSize == 2048 && meterBins == 1024)
  hrtf <- createPanner paramContext
  setPanningModel hrtf HRTF
  model <- fromJSValUnchecked =<< (hrtf ! "panningModel")
  setField target "panningModelHrtf" ((model :: MisoString) == "HRTF")
  rawNode <- RawDelay <$> (paramContext # "createDelay") (0.5 :: Double)
  rawParam <- AudioParam <$> (rawNode ! "delayTime")
  setValueAtTime rawParam 0.25 0
  connect rawNode =<< destination paramContext
  disconnect rawNode
  setField target "customNodeAndParam" True
  garbage <- ArrayBuffer <$> jsg0 "__garbageBytes"
  badDecode <- decodeAudioData_ paramContext garbage
  setField target "badDecodeReportsError" (isLeft badDecode)
  states <- newIORef []
  stateContext <- newOfflineAudioContext 1 441 rate
  stateThread <- forkIO (contextStateSub stateContext id (\state -> modifyIORef' states (state :)) (pure ()))
  sleep 10
  void (must (startRendering_ stateContext))
  void (waitFor 2000 ((Closed `elem`) <$> readIORef states))
  seen <- readIORef states
  killThread stateThread
  setField target "stateChangeSeen" (Closed `elem` seen)
  silenced <- newIORef (0 :: Int)
  quietContext <- newOfflineAudioContext 1 441 rate
  quietThread <- forkIO (contextStateSub quietContext id (\_ -> modifyIORef' silenced (+ 1)) (pure ()))
  sleep 10
  killThread quietThread
  sleep 10
  void (must (startRendering_ quietContext))
  sleep 100
  silencedCount <- readIORef silenced
  setField target "stateChangeUnsubscribed" (silencedCount == 0)
  completed <- newIORef (0 :: Int)
  completeContext <- newOfflineAudioContext 1 441 rate
  onComplete_ completeContext $ \rendered -> do
    frames' <- bufferLength rendered
    modifyIORef' completed (+ frames')
  void (must (startRendering_ completeContext))
  void (waitFor 2000 ((== 441) <$> readIORef completed))
  completedFrames <- readIORef completed
  setField target "onCompleteBuffer" (completedFrames == 441)
  original <- jsg "AudioContext"
  legacy <- jsg "webkitAudioContext"
  setField global "AudioContext" jsNull
  setField global "webkitAudioContext" jsNull
  missing <- newAudioContext LatencyInteractive
#ifndef WASM
  thrower <- jsg "__throwingConstructor"
  setField global "AudioContext" thrower
  throwing <- newAudioContext LatencyInteractive
  setField target "throwingConstructorIsNothing" (null throwing)
#endif
  setField global "AudioContext" original
  setField global "webkitAudioContext" legacy
  setField target "noConstructorIsNothing" (null missing)

-- XXX: Workaround for a GHC wasm bug that blows up compile times. Keep.
{-# NOINLINE effectChecks #-}
effectChecks :: Object -> IO ()
effectChecks target = do
  renderContext <- newOfflineAudioContext 1 441 rate
  rendered <- captured (startRendering renderContext)
  setField target "effectStartRendering" (isRight rendered)
  loadContext <- newOfflineAudioContext 1 441 rate
  bytes <- ArrayBuffer <$> jsg0 "__wavBytes"
  decoded <- captured (decodeAudioData loadContext bytes)
  setField target "effectDecodeAudioData" (isRight decoded)
  garbage <- ArrayBuffer <$> jsg0 "__garbageBytes"
  badDecode <- captured (decodeAudioData loadContext garbage)
  setField target "effectDecodeAudioDataError" (either (/= "") (const False) badDecode)
  url <- fromJSValUnchecked =<< jsg0 "__wavUrl"
  fetched <- captured (fetchAudioBuffer loadContext url)
  setField target "effectFetchAudioBuffer" (isRight fetched)
  badFetch <- captured (fetchAudioBuffer loadContext "data:,not-audio")
  setField target "effectFetchAudioBufferError" (either (/= "") (const False) badFetch)
  missingFile <- captured (fetchAudioBuffer loadContext "absent.wav")
  setField target "effectFetchAudioBufferStatus" (either (== "absent.wav: HTTP 404") (const False) missingFile)
  moduleLoaded <- capturedDone (addModule loadContext "worklet.js")
  setField target "effectAddModule" (isRight moduleLoaded)
  bare <- unObject <$> create
  noWorklet <- capturedDone (addModule (OfflineAudioContext bare) "worklet.js")
  setField target "effectAddModuleUnavailable" (isLeft noWorklet)
  noSink <- capturedDone (setSinkId (AudioContext bare) "")
  setField target "effectSetSinkIdUnavailable" (isLeft noSink)
  noSuspend <- capturedDone (suspendOfflineAt (OfflineAudioContext bare) 0.05)
  setField target "effectSuspendOfflineAtUnavailable" (isLeft noSuspend)
  endContext <- newOfflineAudioContext 1 441 rate
  endOutput <- destination endContext
  source <- createOscillator endContext
  connect source endOutput
  start source 0
  stop source 0.001
  sourceEnded <- newEmptyMVar
  runEffects (onEnded source ()) (putMVar sourceEnded)
  sleep 10
  void (must (startRendering_ endContext))
  takeMVar sourceEnded
  setField target "effectOnEnded" True
  completeContext <- newOfflineAudioContext 1 441 rate
  completed <- newEmptyMVar
  runEffects (onComplete completeContext id) (putMVar completed)
  sleep 10
  void (must (startRendering_ completeContext))
  completedFrames <- bufferLength =<< takeMVar completed
  setField target "effectOnComplete" (completedFrames == 441)
  suspendContext <- newOfflineAudioContext 1 4410 rate
  reached <- newEmptyMVar
  runEffects (suspendOfflineAt suspendContext 0.05 True (const False)) (putMVar reached)
  sleep 10
  finished <- newEmptyMVar
  void . forkIO $ putMVar finished =<< startRendering_ suspendContext
  suspended <- takeMVar reached
  resumeOffline suspendContext
  resumed <- takeMVar finished
  setField target "effectSuspendOfflineAt" (suspended && isRight resumed)

waitFor :: Int -> IO Bool -> IO Bool
waitFor budget condition = do
  deadline <- (+ fromIntegral budget) <$> now_ffi
  let go = do
        done <- condition
        if done
          then pure True
          else do
            stamp <- now_ffi
            if stamp > deadline
              then pure False
              else do
                sleep 10
                go
  go

sleep :: Int -> IO ()
sleep ms' = do
  promise <- jsg1 "__sleep" ms'
  void (evaluate =<< await promise)

settledPeak :: AnalyserNode -> IO Double
settledPeak meter = do
  let peak = maximum . map abs <$> getFloatTimeDomainData meter
  void (waitFor 5000 ((> 0.1) <$> peak))
  peak

liveChecks :: Object -> IO ()
liveChecks target = do
  newAudioContextAtRate LatencyPlayback 22050 >>= \case
    Nothing -> setField target "contextAtRate" False
    Just atRate -> do
      rateRead <- sampleRate atRate
      setField target "contextAtRate" (rateRead == 22050)
      close atRate
  created <- newAudioContext (LatencySeconds 0.05)
  case created of
    Nothing -> setField target "contextCreated" False
    Just context -> do
      setField target "contextCreated" True
      resume context
      running <- waitFor 3000 ((== Running) <$> contextState context)
      setField target "contextRunning" running
      latency <- baseLatency context
      setField target "baseLatencyPositive" (latency > 0)
      sleep 100
      stamp <- getOutputTimestamp context
      setField target "outputTimestamp" (outputContextTime stamp >= 0 && outputPerformanceTime stamp >= 0)
      sinkAvailable <- hasSetSinkId context
      setField target "sinkAvailable" sinkAvailable
      when sinkAvailable $ do
        sinkSet <- capturedDone (setSinkId context "")
        setField target "sinkSet" (isRight sinkSet)
      playbackStats context >>= \case
        Nothing -> setField target "statsAvailable" False
        Just stats -> do
          setField target "statsAvailable" True
          total <- totalDuration stats
          underrun <- underrunDuration stats
          events <- underrunEvents stats
          lowest <- minimumLatency stats
          highest <- maximumLatency stats
          average <- averageLatency stats
          resetLatency stats
          setField target "statsRead" (total >= 0 && underrun >= 0 && events >= 0 && lowest >= 0 && highest >= lowest && average >= 0)
      sink <- createMediaStreamDestination context
      tone <- createOscillator context
      connect tone sink
      start tone 0
      stream <- destinationStream sink
      source <- createMediaStreamSource context stream
      streamMeter <- createAnalyser context
      connect source streamMeter
      setField target "streamPeak" =<< settledPeak streamMeter
      tracks <- (stream # "getAudioTracks") ()
      track <- tracks DSL.!! 0
      trackSource <- createMediaStreamTrackSource context track
      setField target "trackSourceAvailable" (isJust trackSource)
      element <- jsg0 "__wavAudio"
      mediaSource <- createMediaElementSource context (Media element)
      mediaMeter <- createAnalyser context
      connect mediaSource mediaMeter
      void (evaluate =<< await =<< (element # "play") ())
      setField target "mediaPeak" =<< settledPeak mediaMeter
      void ((element # "pause") ())
      close context

main :: IO ()
main = do
  state <- create
  rendered <- create
  results <- create
  bench <- create
  setField state "rendered" rendered
  setField state "checks" results
  setField state "bench" bench
  setField global "__webaudio" state
  player <- newPlayer 0.4
  let hook name action = do
        callback <- syncCallback action
        setField state name callback
      testNote = [Note Sine 0 440 Nothing 0.3 0.05 0.06]
  hook "play" (playNotes player testNote)
  hook "playLong" (playNotes player [Note Sine 0 440 Nothing 0.3 0.4 0.42])
  hook "mute" (setMuted player True)
  hook "unmute" (setMuted player False)
  hook "closePlayer" (closePlayer player)
  clickElement <- syncCallback1 (\element -> void ((element # "click") ()))
  setField state "clickElement" clickElement
  liveResults <- create
  setField state "liveResults" liveResults
  liveCallback <- asyncCallback $ do
    outcome <- try (liveChecks liveResults)
    case outcome of
      Left (failure :: SomeException) -> setField state "liveFailed" (ms (displayException failure))
      Right () -> pure ()
    setField state "liveDone" True
  setField state "live" liveCallback
  consoleObject <- jsg "console"
  void ((consoleObject # "log") ["webaudio-hooks-ready" :: MisoString])
  outcome <- try $ do
    forM_
      [ ("notes", renderNotes)
      , ("knock", renderKnock)
      , ("garden", renderGarden)
      , ("routing", renderRouting)
      , ("space", renderSpace)
      , ("listener", renderListener)
      , ("timbre", renderTimbre)
      , ("sample", renderSample)
      , ("worklet", renderWorklet results)
      ]
      $ \(name, render) -> do
        buffer <- render
        setField rendered (ms (name :: String)) buffer
    analysis <- create
    setField state "analysis" analysis
    analysisReadings analysis
    checks results
    effectChecks results
    benchmarks bench
  case outcome of
    Left (failure :: SomeException) -> setField state "failed" (ms (displayException failure))
    Right () -> pure ()
  setField state "ready" True
