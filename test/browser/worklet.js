class HalfGain extends AudioWorkletProcessor {
  static get parameterDescriptors() {
    return [{ name: "level", defaultValue: 0.5, automationRate: "a-rate" }];
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0][0];
    const output = outputs[0][0];
    const level = parameters.level;
    if (!input) return true;
    for (let i = 0; i < output.length; i++) {
      output[i] = input[i] * (level.length > 1 ? level[i] : level[0]);
    }
    return true;
  }
}

registerProcessor("half-gain", HalfGain);
