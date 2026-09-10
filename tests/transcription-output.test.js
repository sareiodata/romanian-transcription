'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'web-server.js'), 'utf8');
// Exercise the actual formatting functions without starting the HTTP listener.
const functions = source.slice(source.indexOf('function wordsOf('), source.indexOf('function release('));
const context = {};
vm.createContext(context);
vm.runInContext(functions, context);
const fixture = {transcription: [
  {speaker: '(speaker 0)', text: 'Hello.', offsets: {from: 1000, to: 2000}, words: [{text: 'Hello.', offsets: {from: 1000, to: 2000}}]},
  {speaker: '(speaker 1)', text: 'Welcome.', offsets: {from: 3000, to: 4000}, words: [{text: 'Welcome.', offsets: {from: 3000, to: 4000}}]}
]};
assert.equal(context.paragraphs(fixture).text, 'Speaker A [0:01]\nHello.\n\nSpeaker B [0:03]\nWelcome.');
assert.throws(() => context.paragraphs({transcription:[{text:'Broken beam output',offsets:{from:0,to:0},words:[{text:'Broken',offsets:{from:0,to:0}}]}]}), /missing speaker labels or usable timestamps/);
const missingTimes = JSON.parse(JSON.stringify(fixture));
for (const s of missingTimes.transcription) {s.offsets = {from: 0, to: 0};for (const w of s.words) w.offsets = {from: 0, to: 0};}
assert.throws(() => context.paragraphs(missingTimes), /usable timestamps/);
assert.equal(context.paragraphs({transcription: []}).paragraphs.length, 0);
console.log('Speaker labels, paragraph boundaries, timestamps, and beam regression checks passed.');
