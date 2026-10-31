'use strict';
const fs = require('fs');
const path = require('path');
const {spawnSync} = require('child_process');
const root = __dirname;
function loadConfig() {
  for (const name of ['config.json', 'config.json.default']) {
    try { return JSON.parse(fs.readFileSync(path.join(root, name), 'utf8')); } catch {}
  }
  return {};
}
function selectRuntime(base = process.env, probe = spawnSync, exists = fs.existsSync) {
  const config = loadConfig();
  const gpu = String(config.gpu ?? 0);
  const cuda = path.join(root, 'bin/crispasr/crispasr');
  const cpu = path.join(root, 'bin/crispasr-cpu/crispasr');
  const env = {...base, CUDA_DEVICE_ORDER: 'PCI_BUS_ID', CUDA_VISIBLE_DEVICES: gpu};
  env.PATH = `${root}/bin:${base.PATH || ''}`;
  env.LD_LIBRARY_PATH = [root+'/bin/crispasr', root+'/.cuda/nvidia/cuda_runtime/lib', root+'/.cuda/nvidia/cublas/lib', base.LD_LIBRARY_PATH].filter(Boolean).join(':');
  for (const name of ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','GOTO_NUM_THREADS','MKL_NUM_THREADS']) env[name] = '6';
  if (base.TRANSCRIPT_DEVICE !== 'cpu' && exists(cuda)) {
    const result = probe(cuda, ['--diagnostics'], {env, encoding: 'utf8', timeout: 15000, maxBuffer: 1024*1024});
    if (result.status === 0 && /gpu\s+name=CUDA0\b/.test((result.stdout || '') + (result.stderr || ''))) {
      return {binary: cuda, args: ['--gpu-backend','cuda','--device',gpu], env: {...env, CRISPASR_WESPEAKER_GPU:'1'}, label:`GPU ${gpu}`, speed:25};
    }
  }
  const binary = exists(cpu) ? cpu : cuda;
  if (!exists(binary)) throw new Error('Transcription runtime missing. Run ./install.sh first.');
  // Prefer the independent CPU build when CUDA libraries or its driver are missing.
  env.LD_LIBRARY_PATH = [path.dirname(binary), base.LD_LIBRARY_PATH].filter(Boolean).join(':');
  return {binary, args:['--no-gpu'], env:{...env, CRISPASR_WESPEAKER_GPU:'0'}, label:'CPU', speed:5};
}
module.exports = {selectRuntime, loadConfig};
