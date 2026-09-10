#!/usr/bin/env node
'use strict';
const path = require('path');
const {spawn} = require('child_process');
const runtime = require('./runtime').selectRuntime();
const [audio, ...extra] = process.argv.slice(2);
if (!audio) {console.error('Usage: ./transcribe.sh AUDIO_FILE [CrispASR options...]');process.exit(2);}
console.error(`Transcription: ${runtime.label}`);
const child = spawn(runtime.binary, [...runtime.args, '--threads','6','--beam-size','1','--backend','canary','--model',path.resolve(__dirname,'models',process.env.TRANSCRIPT_MODEL || 'canary-1b-v2-q8_0.gguf'),'--file',audio,'--language','ro','--source-lang','ro','--target-lang','ro','--no-auto-aligner',...extra], {env:runtime.env, stdio:'inherit'});
child.on('error', error => {console.error(error.message);process.exitCode=1;});
child.on('exit', (code, signal) => {process.exitCode=code ?? (signal ? 1 : 0);});
for (const signal of ['SIGINT','SIGTERM']) process.on(signal, () => child.kill(signal));
