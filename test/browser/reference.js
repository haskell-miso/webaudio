globalThis.__sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
globalThis.__throwingConstructor = function () {
  throw new DOMException("no audio", "NotSupportedError");
};

const rate = 44100;
const seconds = (duration) => Math.ceil(duration * rate);

function* parkMiller(seed) {
  let x = seed;
  for (;;) {
    x = x * 16807 - 2147483647 * Math.floor((x * 16807) / 2147483647);
    yield x / 1073741823.5 - 1;
  }
}

const take = (n, gen) => {
  const out = new Array(n);
  for (let i = 0; i < n; i++) out[i] = gen.next().value;
  return out;
};

const noiseBuffer = (ctx, seed, duration) => {
  const n = seconds(duration);
  const buffer = ctx.createBuffer(1, n, rate);
  buffer.getChannelData(0).set(take(n, parkMiller(seed)));
  return buffer;
};

const shift = (notes, by) => notes.map((n) => [n[0], n[1] + by, ...n.slice(2)]);

const WAVES = ["sine", "triangle", "sawtooth", "square"];

const recipes = () => [
  ...shift([[0, 0, 400, 720, 0.08, 0.3, 0.12, 0.13]], 0),
  ...shift([[1, 0, 180, 110, 0.06, 0.12, 0.07, 0.08]], 0.2),
  ...shift(
    [
      [1, 0, 261.63, 274.7115, 0.1, 0.2, 0.35, 0.37],
      [1, 0, 261.63, 274.7115, 0.1, 0.16, 0.35, 0.37],
      [1, 0, 329.63, 346.1115, 0.1, 0.16, 0.35, 0.37],
    ],
    0.4
  ),
  ...shift([[2, 0, 293.66, 308.343, 0.1, 0.25, 0.12, 0.14]], 0.9),
  ...shift([[2, 0, 140, 30, 0.35, 0.4, 0.38, 0.4]], 1.1),
  ...shift([[0, 0, 120, 380, 0.25, 0.18, 0.28, 0.3]], 1.6),
  ...shift([[1, 0, 220, 880, 0.15, 0.25, 0.18, 0.2]], 2.0),
  ...shift([[0, 0, 450, 180, 0.2, 0.25, 0.22, 0.24]], 2.3),
  ...shift([[2, 0, 320, 80, 0.4, 0.3, 0.42, 0.45]], 2.6),
  ...shift([440, 554.37, 659.25, 880].map((f, i) => [0, i * 0.08, f, 0, 0, 0.2, 0.35, 0.38]), 3.1),
  ...shift([330, 311.13, 293.66, 261.63].map((f, i) => [0, i * 0.12, f, 0, 0, 0.22, 0.45, 0.48]), 3.8),
  ...shift([[0, 0, 620, 840, 0.04, 0.08, 0.05, 0.06]], 4.8),
  ...shift([[3, 0, 220, 110, 0.1, 0.1, 0.15, 0.2]], 5.0),
];

const renderNotes = async (mutate) => {
  const ctx = new OfflineAudioContext(1, seconds(5.5), rate);
  const master = ctx.createGain();
  master.gain.setValueAtTime(0.4, 0);
  master.connect(ctx.destination);
  const notes = recipes().flat();
  if (mutate) notes[2] = 500;
  const t0 = ctx.currentTime;
  for (let i = 0; i < notes.length; i += 8) {
    const start = t0 + notes[i + 1];
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = WAVES[notes[i]];
    osc.frequency.setValueAtTime(notes[i + 2], start);
    if (notes[i + 3] > 0) osc.frequency.exponentialRampToValueAtTime(notes[i + 3], start + notes[i + 4]);
    gain.gain.setValueAtTime(notes[i + 5], start);
    gain.gain.exponentialRampToValueAtTime(0.001, start + notes[i + 6]);
    osc.connect(gain);
    gain.connect(master);
    osc.start(start);
    osc.stop(start + notes[i + 7]);
  }
  return ctx.startRendering();
};

const renderKnock = async (mutate) => {
  const ctx = new OfflineAudioContext(1, seconds(0.5), rate);
  const master = ctx.createGain();
  master.gain.value = 0.5;
  master.connect(ctx.destination);
  const env = (g, t0, a, peak, d) => {
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(peak, t0 + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + a + d);
  };
  const t0 = 0.01;
  const peak = 0.55;
  const bright = 2400;
  const low = mutate ? 240 : 180;
  const s = ctx.createBufferSource();
  s.buffer = noiseBuffer(ctx, 42, 0.06);
  const f = ctx.createBiquadFilter();
  f.type = "bandpass";
  f.frequency.value = bright;
  f.frequency.setValueAtTime(bright, t0);
  f.frequency.exponentialRampToValueAtTime(bright * 0.4, t0 + 0.05);
  f.Q.value = 1.6;
  const g = ctx.createGain();
  env(g, t0, 0.003, peak, 0.05);
  s.connect(f);
  f.connect(g);
  g.connect(master);
  s.start(t0);
  const o = ctx.createOscillator();
  o.type = "sine";
  o.frequency.setValueAtTime(low, t0);
  o.frequency.exponentialRampToValueAtTime(low * 0.55, t0 + 0.002 + 0.09);
  const tg = ctx.createGain();
  env(tg, t0, 0.002, peak * 0.9, 0.09);
  o.connect(tg);
  tg.connect(master);
  o.start(t0);
  o.stop(t0 + 0.002 + 0.09 + 0.05);
  return ctx.startRendering();
};

const saturationCurve = (soil, n = 4096) => {
  const k = 0.9 - 0.5 * soil;
  const curve = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const x = (i / (n - 1)) * 2 - 1;
    const a = Math.abs(x);
    const y = a <= k ? a : k + (1 - k) * Math.tanh((a - k) / (1 - k));
    curve[i] = Math.sign(x) * y;
  }
  return curve;
};

const roomImpulse = (ctx) => {
  const duration = 0.4;
  const frames = seconds(duration);
  const decay = Math.log(1000) / duration;
  const buffer = ctx.createBuffer(2, frames, rate);
  [7, 11].forEach((seed, channel) => {
    const noise = take(frames, parkMiller(seed));
    const data = buffer.getChannelData(channel);
    for (let i = 0; i < frames; i++) data[i] = noise[i] * Math.exp(-decay * (i / rate));
  });
  return buffer;
};

const renderGarden = async (mutate) => {
  const ctx = new OfflineAudioContext(2, seconds(2), rate);
  const filter = (type, hz) => {
    const f = ctx.createBiquadFilter();
    f.type = type;
    f.frequency.value = hz;
    return f;
  };
  const compressor = (threshold, knee, ratio, attack, release) => {
    const c = ctx.createDynamicsCompressor();
    c.threshold.value = threshold;
    c.knee.value = knee;
    c.ratio.value = ratio;
    c.attack.value = attack;
    c.release.value = release;
    return c;
  };
  const master = ctx.createGain();
  master.gain.value = 0.5;
  const hp = filter("highpass", 30);
  const shelf = filter("highshelf", 6000);
  shelf.gain.value = -2.5;
  const glue = compressor(-20, 12, 2.5, 0.02, 0.25);
  const limiter = compressor(-3, 0, 20, 0.001, 0.1);
  const post = ctx.createGain();
  post.gain.value = 0.63;
  master.connect(hp).connect(shelf).connect(glue).connect(limiter).connect(post).connect(ctx.destination);
  const sendHp = filter("highpass", 200);
  const conv = ctx.createConvolver();
  conv.buffer = roomImpulse(ctx);
  const retLp = filter("lowpass", 7000);
  sendHp.connect(conv).connect(retLp).connect(master);
  const lfo = ctx.createOscillator();
  lfo.frequency.value = 5.1;
  lfo.start(0);
  const noise = noiseBuffer(ctx, 99, 2);
  const input = ctx.createGain();
  const shaper = ctx.createWaveShaper();
  shaper.oversample = "2x";
  shaper.curve = saturationCurve(0.5);
  const lowpass = filter("lowpass", 7000);
  lowpass.Q.value = 0.7;
  const volume = ctx.createGain();
  volume.gain.value = 0.56;
  const duck = ctx.createGain();
  const send = ctx.createGain();
  send.gain.value = 40 / 127;
  input.connect(shaper).connect(lowpass).connect(volume).connect(duck);
  duck.connect(master);
  duck.connect(send).connect(sendHp);
  const pitchBus = ctx.createGain();
  const bend = ctx.createConstantSource();
  bend.offset.value = 0;
  bend.connect(pitchBus);
  bend.start(0);
  const vibrato = ctx.createGain();
  vibrato.gain.value = 12;
  lfo.connect(vibrato).connect(pitchBus);
  bend.offset.setTargetAtTime(40, 0.3, 0.02);
  volume.gain.cancelScheduledValues(0.5);
  volume.gain.setTargetAtTime(0.4, 0.5, 0.03);
  duck.gain.cancelAndHoldAtTime(0.8);
  duck.gain.setTargetAtTime(0.5, 0.8, 0.02);
  duck.gain.setTargetAtTime(1, 1.0, 0.1);
  const voiceOsc = (wave, hz, start, target) => {
    const o = ctx.createOscillator();
    o.type = wave;
    o.frequency.setValueAtTime(hz, start);
    pitchBus.connect(o.detune);
    o.connect(target);
    o.start(start);
    return o;
  };
  const moss = ctx.createGain();
  moss.connect(input);
  moss.gain.setValueAtTime(0, 0.05);
  moss.gain.linearRampToValueAtTime(0.5, 0.05 + 0.004);
  moss.gain.setTargetAtTime(0.5 * 0.25, 0.05 + 0.004, 0.5 / 3);
  const overtone = ctx.createGain();
  overtone.gain.value = 0.35;
  overtone.connect(moss);
  const clickLevel = ctx.createGain();
  const clickFilter = filter("lowpass", 3500);
  clickFilter.Q.value = 0.7;
  clickFilter.connect(moss);
  clickLevel.connect(clickFilter);
  clickLevel.gain.setValueAtTime(0.35, 0.05);
  clickLevel.gain.setTargetAtTime(0, 0.05, 0.006);
  const oscs = [voiceOsc("sine", mutate ? 330 : 220, 0.05, moss), voiceOsc("sine", 440, 0.05, overtone), voiceOsc("triangle", 1320, 0.05, clickLevel)];
  moss.gain.cancelAndHoldAtTime(0.7);
  moss.gain.setTargetAtTime(0, 0.7, 0.12 / 4);
  for (const o of oscs) o.stop(0.7 + 0.18);
  const breath = ctx.createGain();
  breath.gain.value = 0.2;
  breath.connect(input);
  const breathFilter = filter("bandpass", 880);
  breathFilter.Q.value = 1.2;
  breathFilter.connect(breath);
  const air = ctx.createBufferSource();
  air.buffer = noise;
  air.loop = true;
  air.connect(breathFilter);
  air.start(0.2, 0.5);
  air.stop(0.9);
  const stolen = ctx.createGain();
  stolen.connect(input);
  stolen.gain.setValueAtTime(0.3, 0.3);
  const voice = voiceOsc("sawtooth", 110, 0.3, stolen);
  stolen.gain.cancelAndHoldAtTime(1.0);
  stolen.gain.linearRampToValueAtTime(0, 1.0 + 0.015);
  voice.stop(1.0 + 0.015 + 0.005);
  return ctx.startRendering();
};

const renderRouting = async (mutate) => {
  const ctx = new OfflineAudioContext(2, seconds(1), rate);
  const output = ctx.destination;
  const a = ctx.createOscillator();
  a.frequency.value = mutate ? 300 : 220;
  const b = ctx.createOscillator();
  b.type = "triangle";
  b.frequency.value = 330;
  const inMerge = ctx.createChannelMerger(2);
  a.connect(inMerge, 0, 0);
  b.connect(inMerge, 0, 1);
  const splitter = ctx.createChannelSplitter(2);
  inMerge.connect(splitter);
  const outMerge = ctx.createChannelMerger(2);
  splitter.connect(outMerge, 0, 1);
  splitter.connect(outMerge, 1, 0);
  outMerge.connect(output);
  const delay = ctx.createDelay(0.5);
  delay.delayTime.setValueAtTime(0.25, 0);
  const feedback = ctx.createGain();
  feedback.gain.value = 0.5;
  splitter.connect(delay, 0, 0);
  delay.connect(feedback);
  feedback.connect(delay);
  feedback.connect(outMerge, 0, 0);
  const removed = ctx.createGain();
  a.connect(removed);
  removed.connect(output);
  a.disconnect(removed);
  const mono = ctx.createGain();
  mono.channelCount = 1;
  mono.channelCountMode = "explicit";
  mono.channelInterpretation = "speakers";
  mono.gain.value = 0.3;
  inMerge.connect(mono);
  mono.connect(output);
  splitter.connect(mono.gain, 1);
  const discrete = ctx.createGain();
  discrete.channelCount = 1;
  discrete.channelCountMode = "explicit";
  discrete.channelInterpretation = "discrete";
  discrete.gain.value = 0.2;
  inMerge.connect(discrete);
  discrete.connect(output);
  const second = ctx.createChannelSplitter(2);
  inMerge.connect(second);
  second.connect(output, 0, 0);
  second.connect(output, 1, 0);
  second.disconnect(1);
  second.disconnect(output, 0, 0);
  for (const node of [a, b]) {
    node.start(0);
    node.stop(1);
  }
  return ctx.startRendering();
};

const renderSpace = async (mutate) => {
  const ctx = new OfflineAudioContext(2, seconds(1), rate);
  const output = ctx.destination;
  const ears = ctx.listener;
  ears.positionX.value = 0.5;
  ears.positionY.value = 0.25;
  ears.positionZ.value = 0;
  ears.forwardX.value = 0;
  ears.forwardY.value = 0;
  ears.forwardZ.value = -1;
  ears.upX.value = 0;
  ears.upY.value = 1;
  ears.upZ.value = 0;
  const tone = (hz) => {
    const o = ctx.createOscillator();
    o.frequency.value = hz;
    return o;
  };
  const sweep = tone(440);
  const stereo = ctx.createStereoPanner();
  stereo.pan.setValueAtTime(mutate ? 1 : -1, 0);
  stereo.pan.linearRampToValueAtTime(mutate ? -1 : 1, 0.5);
  sweep.connect(stereo);
  stereo.connect(output);
  const voice = tone(660);
  const near = ctx.createPanner();
  near.panningModel = "equalpower";
  near.distanceModel = "inverse";
  near.refDistance = 1;
  near.maxDistance = 100;
  near.rolloffFactor = 1;
  near.coneInnerAngle = 60;
  near.coneOuterAngle = 120;
  near.coneOuterGain = 0.2;
  near.positionZ.value = -2;
  near.positionX.setValueAtTime(-3, 0);
  near.positionX.linearRampToValueAtTime(3, 1);
  near.orientationX.value = 1;
  near.orientationY.value = 0;
  near.orientationZ.value = 0;
  voice.connect(near);
  near.connect(output);
  const far = tone(880);
  const distant = ctx.createPanner();
  distant.distanceModel = "linear";
  distant.positionX.value = 4;
  far.connect(distant);
  distant.connect(output);
  const farther = tone(990);
  const remote = ctx.createPanner();
  remote.distanceModel = "exponential";
  remote.positionX.value = -6;
  farther.connect(remote);
  remote.connect(output);
  for (const node of [sweep, voice, far, farther]) {
    node.start(0);
    node.stop(1);
  }
  return ctx.startRendering();
};

const renderListener = async (mutate) => {
  const ctx = new OfflineAudioContext(2, seconds(0.5), rate);
  ctx.listener.setPosition(mutate ? -5 : 1, 0, 0);
  ctx.listener.setOrientation(0, 0, -1, 0, 1, 0);
  const tone = ctx.createOscillator();
  tone.frequency.value = 500;
  const source = ctx.createPanner();
  source.positionX.value = -2;
  tone.connect(source);
  source.connect(ctx.destination);
  tone.start(0);
  tone.stop(0.5);
  return ctx.startRendering();
};

const renderTimbre = async (mutate) => {
  const ctx = new OfflineAudioContext(1, seconds(1), rate);
  const output = ctx.destination;
  const wave = ctx.createPeriodicWave(new Float32Array([0, 0.5, 0.25]), new Float32Array([0, 1, 0.5]), { disableNormalization: true });
  const custom = ctx.createOscillator();
  custom.setPeriodicWave(wave);
  custom.frequency.value = 220;
  const iir = ctx.createIIRFilter(mutate ? [0.4, 0.2, 0.1] : [0.1, 0.2, 0.1], [1, -0.5, 0.2]);
  const shaped = ctx.createGain();
  shaped.gain.setValueCurveAtTime(new Float32Array([0, 1, 0.5, 0.75]), 0.05, 0.5);
  custom.connect(iir);
  iir.connect(shaped);
  shaped.connect(output);
  custom.start(0);
  custom.stop(1);
  const looped = ctx.createBufferSource();
  looped.buffer = noiseBuffer(ctx, 5, 0.5);
  looped.loop = true;
  looped.loopStart = 0.1;
  looped.loopEnd = 0.2;
  looped.playbackRate.value = 1.5;
  const lowpass = ctx.createBiquadFilter();
  lowpass.type = "lowpass";
  lowpass.frequency.value = 1200;
  const quiet = ctx.createGain();
  quiet.gain.automationRate = "k-rate";
  quiet.gain.setValueAtTime(0, 0.1);
  quiet.gain.linearRampToValueAtTime(0.4, 0.5);
  looped.connect(lowpass);
  lowpass.connect(quiet);
  quiet.connect(output);
  looped.start(0.1, 0.1, 0.6);
  const impulse = ctx.createBuffer(1, 2205, rate);
  impulse.getChannelData(0).set(take(2205, parkMiller(77)));
  const room = ctx.createConvolver();
  room.normalize = false;
  room.buffer = impulse;
  const dry = ctx.createOscillator();
  dry.type = "square";
  dry.frequency.value = 110;
  const wet = ctx.createGain();
  wet.gain.value = 0.02;
  dry.connect(wet);
  wet.connect(room);
  room.connect(output);
  dry.start(0.2);
  dry.stop(0.6);
  return ctx.startRendering();
};

globalThis.__wavBytes = () => {
  const frames = seconds(0.25);
  const bytes = new ArrayBuffer(44 + frames * 2);
  const view = new DataView(bytes);
  const text = (at, value) => {
    for (let i = 0; i < value.length; i++) view.setUint8(at + i, value.charCodeAt(i));
  };
  text(0, "RIFF");
  view.setUint32(4, 36 + frames * 2, true);
  text(8, "WAVE");
  text(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, rate, true);
  view.setUint32(28, rate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  text(36, "data");
  view.setUint32(40, frames * 2, true);
  for (let i = 0; i < frames; i++) {
    const t = i / rate;
    const sample = 0.5 * Math.sin(2 * Math.PI * 300 * t) + 0.25 * Math.sin(2 * Math.PI * 900 * t);
    view.setInt16(44 + i * 2, Math.round(sample * 32767), true);
  }
  return bytes;
};

globalThis.__garbageBytes = () => new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]).buffer;

let wavUrl = null;
globalThis.__wavUrl = () => {
  wavUrl ??= URL.createObjectURL(new Blob([globalThis.__wavBytes()], { type: "audio/wav" }));
  return wavUrl;
};

globalThis.__wavAudio = () => {
  const element = new Audio(globalThis.__wavUrl());
  element.loop = true;
  return element;
};

const renderSample = async (mutate) => {
  const ctx = new OfflineAudioContext(1, seconds(1), rate);
  const decoded = await ctx.decodeAudioData(globalThis.__wavBytes());
  const response = await fetch(globalThis.__wavUrl());
  const fetched = await ctx.decodeAudioData(await response.arrayBuffer());
  const first = ctx.createBufferSource();
  first.buffer = decoded;
  first.connect(ctx.destination);
  first.start(mutate ? 0.1 : 0);
  const second = ctx.createBufferSource();
  second.buffer = fetched;
  second.detune.value = 700;
  second.connect(ctx.destination);
  second.start(0.5);
  return ctx.startRendering();
};

const renderWorklet = async (mutate) => {
  const ctx = new OfflineAudioContext(1, seconds(0.5), rate);
  await ctx.audioWorklet.addModule("worklet.js");
  const node = new AudioWorkletNode(ctx, "half-gain", { outputChannelCount: [1] });
  const level = node.parameters.get("level");
  level.setValueAtTime(mutate ? 0.5 : 1, 0);
  level.linearRampToValueAtTime(0.1, 0.4);
  const tone = ctx.createOscillator();
  tone.frequency.value = 300;
  tone.connect(node);
  node.connect(ctx.destination);
  tone.start(0);
  tone.stop(0.5);
  return ctx.startRendering();
};

globalThis.__referenceAnalysis = async () => {
  const ctx = new OfflineAudioContext(1, seconds(1), rate);
  const tone = ctx.createOscillator();
  tone.frequency.value = 1000;
  const squeeze = ctx.createDynamicsCompressor();
  squeeze.threshold.value = -40;
  squeeze.knee.value = 0;
  squeeze.ratio.value = 20;
  squeeze.attack.value = 0.001;
  squeeze.release.value = 0.1;
  const meter = ctx.createAnalyser();
  meter.fftSize = 1024;
  meter.smoothingTimeConstant = 0;
  meter.minDecibels = -90;
  meter.maxDecibels = -10;
  tone.connect(squeeze);
  squeeze.connect(meter);
  meter.connect(ctx.destination);
  tone.start(0);
  const out = {};
  ctx.suspend(0.5).then(() => {
    const float = (size, read) => {
      const a = new Float32Array(size);
      read(a);
      return Array.from(a);
    };
    const byte = (size, read) => {
      const a = new Uint8Array(size);
      read(a);
      return Array.from(a);
    };
    out.time = float(meter.fftSize, (a) => meter.getFloatTimeDomainData(a));
    out.frequency = float(meter.frequencyBinCount, (a) => meter.getFloatFrequencyData(a));
    out.byteTime = byte(meter.fftSize, (a) => meter.getByteTimeDomainData(a));
    out.byteFrequency = byte(meter.frequencyBinCount, (a) => meter.getByteFrequencyData(a));
    out.reduction = [squeeze.reduction];
    ctx.resume();
  });
  await ctx.startRendering();
  const responseOf = (node) => {
    const hertz = new Float32Array([100, 440, 1000, 4000]);
    const magnitude = new Float32Array(4);
    const phase = new Float32Array(4);
    node.getFrequencyResponse(hertz, magnitude, phase);
    return [Array.from(magnitude), Array.from(phase)];
  };
  const biquad = ctx.createBiquadFilter();
  biquad.type = "peaking";
  biquad.frequency.value = 1000;
  biquad.Q.value = 2;
  biquad.gain.value = 6;
  [out.biquadMagnitude, out.biquadPhase] = responseOf(biquad);
  [out.iirMagnitude, out.iirPhase] = responseOf(ctx.createIIRFilter([0.1, 0.2, 0.1], [1, -0.5, 0.2]));
  return out;
};

globalThis.__compareAnalysis = async () => {
  const expected = await globalThis.__referenceAnalysis();
  const actual = globalThis.__webaudio.analysis;
  const results = {};
  for (const key of Object.keys(expected)) {
    const a = Array.from(actual[key]);
    const b = expected[key];
    let maxDiff = a.length === b.length ? 0 : Infinity;
    let spread = 0;
    for (let i = 0; i < Math.min(a.length, b.length); i++) {
      if (a[i] !== b[i]) maxDiff = Math.max(maxDiff, Math.abs(a[i] - b[i]));
      if (Number.isFinite(b[i])) spread = Math.max(spread, Math.abs(b[i]));
    }
    results[key] = { maxDiff, spread, length: b.length };
  }
  return results;
};

globalThis.__reference = {
  notes: renderNotes,
  knock: renderKnock,
  garden: renderGarden,
  routing: renderRouting,
  space: renderSpace,
  listener: renderListener,
  timbre: renderTimbre,
  sample: renderSample,
  worklet: renderWorklet,
};

globalThis.__compare = async (name, mutate) => {
  const expected = await globalThis.__reference[name](mutate);
  const actual = globalThis.__webaudio.rendered[name];
  let maxDiff = 0;
  let peak = 0;
  for (let c = 0; c < expected.numberOfChannels; c++) {
    const a = actual.getChannelData(c);
    const b = expected.getChannelData(c);
    if (a.length !== b.length) return { maxDiff: Infinity, peak, length: [a.length, b.length] };
    for (let i = 0; i < a.length; i++) {
      maxDiff = Math.max(maxDiff, Math.abs(a[i] - b[i]));
      peak = Math.max(peak, Math.abs(b[i]));
    }
  }
  return { maxDiff, peak };
};
