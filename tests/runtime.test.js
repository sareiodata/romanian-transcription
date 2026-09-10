const {test} = require('node:test');
const assert = require('node:assert/strict');
const {selectRuntime} = require('../runtime');
const exists = () => true;
test('CUDA device detected: both ASR and speaker embedder use GPU', () => {
  const r=selectRuntime({},()=>({status:0,stdout:'[0] gpu    name=CUDA0 desc=NVIDIA'}),exists);
  assert.equal(r.label,'GPU 0');assert.equal(r.env.CRISPASR_WESPEAKER_GPU,'1');
});
for (const [name,result] of [['missing driver',{status:0,stdout:'[0] cpu name=CPU'}],['missing shared libraries',{status:127,stderr:'error loading shared libraries'}],['probe timeout',{status:null,error:new Error('timeout')}]]) {
  test(name+': selects independent CPU build',()=>{
    const r=selectRuntime({},()=>result,exists);
    assert.equal(r.label,'CPU');assert(r.binary.endsWith('crispasr-cpu/crispasr'));
    assert.deepEqual(r.args,['--no-gpu']);assert.equal(r.env.CRISPASR_WESPEAKER_GPU,'0');
  });
}
test('forced CPU avoids GPU probing',()=>{
  const r=selectRuntime({TRANSCRIPT_DEVICE:'cpu'},()=>{throw Error('should not probe');},exists);
  assert.equal(r.label,'CPU');
});
test('missing installation gives actionable error',()=>assert.throws(()=>selectRuntime({},()=>{},()=>false),/install.sh/));
