{-# LANGUAGE CPP #-}
module Main (main) where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (SomeException, displayException, evaluate, try)
import Control.Monad (forM_, replicateM_, void, when)
import Data.Foldable (for_)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Maybe (isJust)
import Miso.DSL
import Miso.DSL qualified as DSL
import Miso.String (MisoString, ms)
import Miso.WebAudio

#ifdef WASM
foreign export javascript "hs_start" main :: IO ()
#endif

rate :: Double
rate = 44100

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
  master <- newGain context
  masterLevel <- gain master
  setValueAt masterLevel 0.4 0
  connect master =<< destination context
  scheduleNotes context master 0 recipes
  startRendering context

seconds :: Double -> Int
seconds duration = ceiling (duration * rate)

parkMiller :: Double -> [Double]
parkMiller seed =
  let next = (seed * 16807) - 2147483647 * fromIntegral (floor ((seed * 16807) / 2147483647) :: Int)
   in (next / 1073741823.5 - 1) : parkMiller next

noiseBuffer :: BaseAudioContext context => context -> Double -> Double -> IO AudioBuffer
noiseBuffer context seed duration = do
  buffer <- newBuffer context 1 (seconds duration) rate
  writeChannel buffer 0 (take (seconds duration) (parkMiller seed))
  pure buffer

setParam :: IO AudioParam -> Double -> IO ()
setParam getParam value = do
  target <- getParam
  setValue target value

newFilter :: BaseAudioContext context => context -> FilterType -> Double -> IO BiquadFilterNode
newFilter context kind hz = do
  node <- newBiquadFilter context
  setFilterType node kind
  setParam (frequency node) hz
  pure node

renderKnock :: IO AudioBuffer
renderKnock = do
  context <- newOfflineAudioContext 1 (seconds 0.5) rate
  master <- newGain context
  setParam (gain master) 0.5
  connect master =<< destination context
  let t0 = 0.01
      peak = 0.55
      bright = 2400
      low = 180
  burst <- newBufferSource context
  setBuffer burst =<< noiseBuffer context 42 0.06
  band <- newFilter context Bandpass bright
  bandFrequency <- frequency band
  setValueAt bandFrequency bright t0
  exponentialRampTo bandFrequency (bright * 0.4) (t0 + 0.05)
  setParam (q band) 1.6
  burstLevel <- newGain context
  envelope burstLevel t0 0.003 peak 0.05
  connect burst band
  connect band burstLevel
  connect burstLevel master
  startAt burst t0
  thump <- newOscillator context
  setWave thump Sine
  thumpFrequency <- frequency thump
  setValueAt thumpFrequency low t0
  exponentialRampTo thumpFrequency (low * 0.55) (t0 + 0.002 + 0.09)
  thumpLevel <- newGain context
  envelope thumpLevel t0 0.002 (peak * 0.9) 0.09
  connect thump thumpLevel
  connect thumpLevel master
  startAt thump t0
  stopAt thump (t0 + 0.002 + 0.09 + 0.05)
  startRendering context
  where
    envelope node start rise top fall = do
      level <- gain node
      setValueAt level 0 start
      linearRampTo level top (start + rise)
      exponentialRampTo level 0.0001 (start + rise + fall)

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
  buffer <- newBuffer context 2 frames rate
  writeChannel buffer 0 (channel 7)
  writeChannel buffer 1 (channel 11)
  pure buffer

newCompressor :: BaseAudioContext context => context -> Double -> Double -> Double -> Double -> Double -> IO DynamicsCompressorNode
newCompressor context limit bend steep rise fall = do
  node <- newDynamicsCompressor context
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
  master <- newGain context
  setParam (gain master) 0.5
  highpass <- newFilter context Highpass 30
  shelf <- newFilter context Highshelf 6000
  setParam (gain shelf) (-2.5)
  glue <- newCompressor context (-20) 12 2.5 0.02 0.25
  limiter <- newCompressor context (-3) 0 20 0.001 0.1
  post <- newGain context
  setParam (gain post) 0.63
  connect master highpass
  connect highpass shelf
  connect shelf glue
  connect glue limiter
  connect limiter post
  connect post output
  sendFilter <- newFilter context Highpass 200
  room <- newConvolver context
  setBuffer room =<< roomImpulse context
  returnFilter <- newFilter context Lowpass 7000
  connect sendFilter room
  connect room returnFilter
  connect returnFilter master
  lfo <- newOscillator context
  setParam (frequency lfo) 5.1
  startAt lfo 0
  noise <- noiseBuffer context 99 2
  input <- newGain context
  shaper <- newWaveShaper context
  setOversample shaper Oversample2x
  setCurve shaper (saturationCurve 0.5)
  lowpass <- newFilter context Lowpass 7000
  setParam (q lowpass) 0.7
  volume <- newGain context
  setParam (gain volume) 0.56
  duck <- newGain context
  send <- newGain context
  setParam (gain send) (40 / 127)
  connect input shaper
  connect shaper lowpass
  connect lowpass volume
  connect volume duck
  connect duck master
  connect duck send
  connect send sendFilter
  pitchBus <- newGain context
  bend <- newConstantSource context
  setParam (offset bend) 0
  connect bend pitchBus
  startAt bend 0
  vibrato <- newGain context
  setParam (gain vibrato) 12
  connect lfo vibrato
  connect vibrato pitchBus
  bendOffset <- offset bend
  setTargetAt bendOffset 40 0.3 0.02
  volumeLevel <- gain volume
  cancelScheduled volumeLevel 0.5
  setTargetAt volumeLevel 0.4 0.5 0.03
  duckLevel <- gain duck
  cancelAndHoldAt duckLevel 0.8
  setTargetAt duckLevel 0.5 0.8 0.02
  setTargetAt duckLevel 1 1.0 0.1
  let voiceOscillator wave hz start target = do
        node <- newOscillator context
        setWave node wave
        nodeFrequency <- frequency node
        setValueAt nodeFrequency hz start
        connectParam pitchBus =<< detune node
        connect node target
        startAt node start
        pure node
      hold node t fade seconds' = do
        level <- gain node
        cancelAndHoldAt level t
        setTargetAt level 0 t (fade / 4)
        pure (t + seconds')
  moss <- newGain context
  connect moss input
  mossLevel <- gain moss
  setValueAt mossLevel 0 0.05
  linearRampTo mossLevel 0.5 (0.05 + 0.004)
  setTargetAt mossLevel (0.5 * 0.25) (0.05 + 0.004) (0.5 / 3)
  overtone <- newGain context
  setParam (gain overtone) 0.35
  connect overtone moss
  clickLevel <- newGain context
  clickFilter <- newFilter context Lowpass 3500
  setParam (q clickFilter) 0.7
  connect clickFilter moss
  connect clickLevel clickFilter
  clickGain <- gain clickLevel
  setValueAt clickGain 0.35 0.05
  setTargetAt clickGain 0 0.05 0.006
  body <- voiceOscillator Sine 220 0.05 moss
  second <- voiceOscillator Sine 440 0.05 overtone
  click <- voiceOscillator Triangle 1320 0.05 clickLevel
  mossEnd <- hold moss 0.7 0.12 0.18
  for_ [body, second, click] (`stopAt` mossEnd)
  breath <- newGain context
  setParam (gain breath) 0.2
  connect breath input
  breathFilter <- newFilter context Bandpass 880
  setParam (q breathFilter) 1.2
  connect breathFilter breath
  air <- newBufferSource context
  setBuffer air noise
  setLoop air True
  connect air breathFilter
  startAtOffset air 0.2 0.5
  stopAt air 0.9
  stolen <- newGain context
  connect stolen input
  stolenLevel <- gain stolen
  setValueAt stolenLevel 0.3 0.3
  voice <- voiceOscillator Sawtooth 110 0.3 stolen
  cancelAndHoldAt stolenLevel 1.0
  linearRampTo stolenLevel 0 (1.0 + 0.015)
  stopAt voice (1.0 + 0.015 + 0.005)
  startRendering context

renderRouting :: IO AudioBuffer
renderRouting = do
  context <- newOfflineAudioContext 2 (seconds 1) rate
  output <- destination context
  a <- newOscillator context
  setParam (frequency a) 220
  b <- newOscillator context
  setWave b Triangle
  setParam (frequency b) 330
  inMerge <- newChannelMerger context 2
  connectPorts a 0 inMerge 0
  connectPorts b 0 inMerge 1
  splitter <- newChannelSplitter context 2
  connect inMerge splitter
  outMerge <- newChannelMerger context 2
  connectPorts splitter 0 outMerge 1
  connectPorts splitter 1 outMerge 0
  connect outMerge output
  delay <- newDelay context 0.5
  delayParam <- delayTime delay
  setValueAt delayParam 0.25 0
  feedback <- newGain context
  setParam (gain feedback) 0.5
  connectPorts splitter 0 delay 0
  connect delay feedback
  connect feedback delay
  connectPorts feedback 0 outMerge 0
  removed <- newGain context
  connect a removed
  connect removed output
  disconnectFrom a removed
  mono <- newGain context
  setChannelCount mono 1
  setChannelCountMode mono ChannelExplicit
  setChannelInterpretation mono Speakers
  setParam (gain mono) 0.3
  connect inMerge mono
  connect mono output
  monoLevel <- gain mono
  connectOutputToParam splitter 1 monoLevel
  discrete <- newGain context
  setChannelCount discrete 1
  setChannelCountMode discrete ChannelExplicit
  setChannelInterpretation discrete Discrete
  setParam (gain discrete) 0.2
  connect inMerge discrete
  connect discrete output
  second <- newChannelSplitter context 2
  connect inMerge second
  connectPorts second 0 output 0
  connectPorts second 1 output 0
  disconnectOutput second 1
  disconnectPorts second 0 output 0
  for_ [a, b] $ \node -> do
    startAt node 0
    stopAt node 1
  startRendering context

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
  sweep <- newOscillator context
  setParam (frequency sweep) 440
  stereo <- newStereoPanner context
  panning <- pan stereo
  setValueAt panning (-1) 0
  linearRampTo panning 1 0.5
  connect sweep stereo
  connect stereo output
  voice <- newOscillator context
  setParam (frequency voice) 660
  near <- newPanner context
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
  setValueAt nearX (-3) 0
  linearRampTo nearX 3 1
  setParam (orientationX near) 1
  setParam (orientationY near) 0
  setParam (orientationZ near) 0
  connect voice near
  connect near output
  far <- newOscillator context
  setParam (frequency far) 880
  distant <- newPanner context
  setDistanceModel distant LinearDistance
  setParam (positionX distant) 4
  connect far distant
  connect distant output
  farther <- newOscillator context
  setParam (frequency farther) 990
  remote <- newPanner context
  setDistanceModel remote ExponentialDistance
  setParam (positionX remote) (-6)
  connect farther remote
  connect remote output
  for_ [sweep, voice, far, farther] $ \node -> do
    startAt node 0
    stopAt node 1
  startRendering context

renderListener :: IO AudioBuffer
renderListener = do
  context <- newOfflineAudioContext 2 (seconds 0.5) rate
  output <- destination context
  ears <- listener context
  setListenerPosition ears 1 0 0
  setListenerOrientation ears 0 0 (-1) 0 1 0
  tone <- newOscillator context
  setParam (frequency tone) 500
  source <- newPanner context
  setParam (positionX source) (-2)
  connect tone source
  connect source output
  startAt tone 0
  stopAt tone 0.5
  startRendering context

renderTimbre :: IO AudioBuffer
renderTimbre = do
  context <- newOfflineAudioContext 1 (seconds 1) rate
  output <- destination context
  wave <- newPeriodicWave context [0, 0.5, 0.25] [0, 1, 0.5] False
  custom <- newOscillator context
  setPeriodicWave custom wave
  setParam (frequency custom) 220
  iir <- newIIRFilter context [0.1, 0.2, 0.1] [1, -0.5, 0.2]
  shaped <- newGain context
  shapedLevel <- gain shaped
  setValueCurveAt shapedLevel [0, 1, 0.5, 0.75] 0.05 0.5
  connect custom iir
  connect iir shaped
  connect shaped output
  startAt custom 0
  stopAt custom 1
  noise <- noiseBuffer context 5 0.5
  looped <- newBufferSource context
  setBuffer looped noise
  setLoop looped True
  setLoopStart looped 0.1
  setLoopEnd looped 0.2
  setParam (playbackRate looped) 1.5
  filterNode <- newFilter context Lowpass 1200
  quiet <- newGain context
  quietLevel <- gain quiet
  setAutomationRate quietLevel KRate
  setValueAt quietLevel 0 0.1
  linearRampTo quietLevel 0.4 0.5
  connect looped filterNode
  connect filterNode quiet
  connect quiet output
  startFor looped 0.1 0.1 0.6
  impulse <- newBuffer context 1 2205 rate
  writeChannel impulse 0 (take 2205 (parkMiller 77))
  room <- newConvolver context
  setNormalize room False
  setBuffer room impulse
  dry <- newOscillator context
  setWave dry Square
  setParam (frequency dry) 110
  wet <- newGain context
  setParam (gain wet) 0.02
  connect dry wet
  connect wet room
  connect room output
  startAt dry 0.2
  stopAt dry 0.6
  startRendering context

renderSample :: IO AudioBuffer
renderSample = do
  context <- newOfflineAudioContext 1 (seconds 1) rate
  output <- destination context
  bytes <- jsg0 "__wavBytes"
  decoded <- decodeAudioData context bytes
  url <- fromJSValUnchecked =<< jsg0 "__wavUrl"
  fetched <- fetchAudioBuffer context url
  first <- newBufferSource context
  setBuffer first decoded
  connect first output
  startAt first 0
  second <- newBufferSource context
  setBuffer second fetched
  setParam (detune second) 700
  connect second output
  startAt second 0.5
  startRendering context

renderWorklet :: Object -> IO AudioBuffer
renderWorklet target = do
  context <- newOfflineAudioContext 1 (seconds 0.5) rate
  output <- destination context
  addWorkletModule context "worklet.js"
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
      setValueAt level 1 0
      linearRampTo level 0.1 0.4
  tone <- newOscillator context
  setParam (frequency tone) 300
  connect tone node
  connect node output
  startAt tone 0
  stopAt tone 0.5
  startRendering context

analysisReadings :: Object -> IO ()
analysisReadings target = do
  context <- newOfflineAudioContext 1 (seconds 1) rate
  output <- destination context
  tone <- newOscillator context
  setParam (frequency tone) 1000
  squeeze <- newCompressor context (-40) 0 20 0.001 0.1
  meter <- newAnalyser context
  setFftSize meter 1024
  setSmoothing meter 0
  setMinDecibels meter (-90)
  setMaxDecibels meter (-10)
  connect tone squeeze
  connect squeeze meter
  connect meter output
  startAt tone 0
  reached <- suspendOfflineAt context 0.5
  finished <- newEmptyMVar
  void . forkIO $ do
    reached
    setField target "time" =<< floatTimeDomainData meter
    setField target "frequency" =<< floatFrequencyData meter
    setField target "byteTime" =<< byteTimeDomainData meter
    setField target "byteFrequency" =<< byteFrequencyData meter
    setField target "reduction" . (: []) =<< reduction squeeze
    resumeOffline context
    putMVar finished ()
  void (startRendering context)
  takeMVar finished
  biquad <- newFilter context Peaking 1000
  setParam (q biquad) 2
  setParam (gain biquad) 6
  iir <- newIIRFilter context [0.1, 0.2, 0.1] [1, -0.5, 0.2]
  let hertz = [100, 440, 1000, 4000]
  biquadResponse <- frequencyResponse biquad hertz
  iirResponse <- frequencyResponse iir hertz
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
  buffer <- newBuffer context 1 96000 rate
  writeTime <- timed (writeChannel buffer 0 samples)
  setField target "writeChannel96k" writeTime
  arrayTime <- timed $ do
    list <- toJSVal samples
    typed <- flip new [list] =<< jsg ("Float32Array" :: MisoString)
    void ((buffer # ("copyToChannel" :: MisoString)) (typed, 0 :: Int))
  setField target "viaArray96k" arrayTime
  master <- newGain context
  noteTime <- timed (replicateM_ 1000 (scheduleNotes context master 0 [Note Sine 0 440 (Just (880, 0.1)) 0.3 0.1 0.12]))
  setField target "schedule1000Notes" noteTime
  voiceContext <- newOfflineAudioContext 1 44100 rate
  voiceTime <- timed (replicateM_ 200 (benchVoice voiceContext))
  setField target "schedule200Voices" voiceTime

benchVoice :: OfflineAudioContext -> IO ()
benchVoice context = do
  out <- newGain context
  outLevel <- gain out
  setValueAt outLevel 0 0
  linearRampTo outLevel 0.5 0.004
  setTargetAt outLevel 0.1 0.004 0.17
  overtone <- newGain context
  setParam (gain overtone) 0.35
  connect overtone out
  lowpass <- newFilter context Lowpass 3500
  connect lowpass out
  click <- newGain context
  connect click lowpass
  forM_ [(Sine, 220, out), (Sine, 440, overtone), (Triangle, 1320, click)] $ \(wave, hz, target) -> do
    node <- newOscillator context
    setWave node wave
    nodeFrequency <- frequency node
    setValueAt nodeFrequency hz 0
    connect node target
    startAt node 0
    stopAt node 0.5

checks :: Object -> IO ()
checks target = do
  context <- newOfflineAudioContext 1 4410 rate
  rateRead <- sampleRate context
  setField target "sampleRate" (rateRead == rate)
  stateName <- contextState context
  setField target "offlineStartsSuspended" (stateName == Suspended)
  buffer <- newBuffer context 2 4 rate
  writeChannel buffer 1 [0.5, -0.25, 0.125, 1]
  roundTrip <- readChannel buffer 1
  setField target "writeThenRead" (roundTrip == [0.5, -0.25, 0.125, 1])
  frames <- bufferLength buffer
  channels <- bufferChannels buffer
  bufferRate <- bufferSampleRate buffer
  setField target "bufferShape" (frames == 4 && channels == 2 && bufferRate == rate)
  node <- newGain context
  other <- newGain context
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
    source <- newOscillator endContext
    connect source endOutput
    startAt source 0
    stopAt source (fromIntegral index * 0.001 + 0.001)
    onEnded source (modifyIORef' ended (+ 1))
  void (startRendering endContext)
  void (waitFor 2000 ((== 50) <$> readIORef ended))
  endedCount <- readIORef ended
  setField target "onEndedCount" endedCount
  paramContext <- newOfflineAudioContext 2 4410 rate
  level <- gain =<< newGain paramContext
  setValue level 0.5
  levelValue <- paramValue level
  levelDefault <- paramDefault level
  levelMin <- paramMin level
  levelMax <- paramMax level
  setField target "paramReads" (levelValue == 0.5 && levelDefault == 1 && levelMin < 0 && levelMax > 1)
  splitter <- newChannelSplitter paramContext 3
  merger <- newChannelMerger paramContext 4
  splitterOutputs <- numberOfOutputs splitter
  mergerInputs <- numberOfInputs merger
  setField target "channelPorts" (splitterOutputs == 3 && mergerInputs == 4)
  countNode <- newGain paramContext
  setChannelCount countNode 1
  countRead <- channelCount countNode
  setField target "channelCount" (countRead == 1)
  offlineFrames <- offlineLength paramContext
  setField target "offlineLength" (offlineFrames == 4410)
  outputChannels <- maxChannelCount =<< destination paramContext
  setField target "maxChannelCount" (outputChannels == 2)
  duration <- bufferDuration buffer
  setField target "bufferDuration" (duration == 4 / rate)
  meter <- newAnalyser paramContext
  setFftSize meter 2048
  meterSize <- fftSize meter
  meterBins <- frequencyBinCount meter
  setField target "analyserSizes" (meterSize == 2048 && meterBins == 1024)
  hrtf <- newPanner paramContext
  setPanningModel hrtf HRTF
  model <- fromJSValUnchecked =<< (hrtf ! "panningModel")
  setField target "panningModelHrtf" ((model :: MisoString) == "HRTF")
  rawNode <- RawDelay <$> (paramContext # "createDelay") (0.5 :: Double)
  rawParam <- AudioParam <$> (rawNode ! "delayTime")
  setValueAt rawParam 0.25 0
  connect rawNode =<< destination paramContext
  disconnect rawNode
  setField target "customNodeAndParam" True
  garbage <- jsg0 "__garbageBytes"
  badDecode <- try (decodeAudioData paramContext garbage)
  setField target "badDecodeThrows" (either (\(_ :: SomeException) -> True) (const False) badDecode)
  states <- newIORef []
  stateContext <- newOfflineAudioContext 1 441 rate
  stopListening <- onStateChange stateContext (\state -> modifyIORef' states (state :))
  void (startRendering stateContext)
  void (waitFor 2000 ((Closed `elem`) <$> readIORef states))
  seen <- readIORef states
  stopListening
  stopListening
  setField target "stateChangeSeen" (Closed `elem` seen)
  silenced <- newIORef (0 :: Int)
  quietContext <- newOfflineAudioContext 1 441 rate
  stopQuiet <- onStateChange quietContext (\_ -> modifyIORef' silenced (+ 1))
  stopQuiet
  void (startRendering quietContext)
  sleep 100
  silencedCount <- readIORef silenced
  setField target "stateChangeUnsubscribed" (silencedCount == 0)
  completed <- newIORef (0 :: Int)
  completeContext <- newOfflineAudioContext 1 441 rate
  onComplete completeContext $ \rendered -> do
    frames' <- bufferLength rendered
    modifyIORef' completed (+ frames')
  void (startRendering completeContext)
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
  let peak = maximum . map abs <$> floatTimeDomainData meter
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
      stamp <- outputTimestamp context
      setField target "outputTimestamp" (outputContextTime stamp >= 0 && outputPerformanceTime stamp >= 0)
      sinkAvailable <- hasSetSinkId context
      setField target "sinkAvailable" sinkAvailable
      when sinkAvailable $ do
        setSinkId context ""
        setField target "sinkSet" True
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
      sink <- newMediaStreamDestination context
      tone <- newOscillator context
      connect tone sink
      startAt tone 0
      stream <- destinationStream sink
      source <- newMediaStreamSource context stream
      streamMeter <- newAnalyser context
      connect source streamMeter
      setField target "streamPeak" =<< settledPeak streamMeter
      tracks <- (stream # "getAudioTracks") ()
      track <- tracks DSL.!! 0
      trackSource <- newMediaStreamTrackSource context track
      setField target "trackSourceAvailable" (isJust trackSource)
      element <- jsg0 "__wavAudio"
      mediaSource <- newMediaElementSource context element
      mediaMeter <- newAnalyser context
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
    benchmarks bench
  case outcome of
    Left (failure :: SomeException) -> setField state "failed" (ms (displayException failure))
    Right () -> pure ()
  setField state "ready" True
