"""Build compact CC0 real SNAP/CLAP/RIDE/CROSS-STICK samples. Requires ffmpeg/numpy.
Downloads pinned source recordings only when absent from the temporary cache.
"""
import concurrent.futures, hashlib, json, pathlib, subprocess, urllib.request, wave
import numpy as np
ROOT=pathlib.Path(__file__).resolve().parents[1]
CACHE=pathlib.Path('/tmp/metronome-new-sounds'); CACHE.mkdir(exist_ok=True)
OUT=ROOT/'TheMetronome/AcousticSamples'
VCSL='https://raw.githubusercontent.com/sgossner/VCSL/c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e/'
VD='https://raw.githubusercontent.com/sfzinstruments/virtuosity_drums/9f04cf9a734527edfbb0a4eee1f674e45bbf71bc/'
items=[]
for i in range(1,5):
 items.extend([(f'ride-{i}.flac',VD+f'Samples/oh/ride/oh_ride_ride_vl2_rr{i}.flac'),
 (f'cross-{i}.flac',VD+f'Samples/snaremic/snare/snaremic_snare_crossstick_vl{i+7}.flac')])
items.extend((f'Clap_rr{i}.wav',VCSL+f'Idiophones/Struck%20Idiophones/Claps/Clap_rr{i}.wav') for i in range(1,7))
items.append(('snap.mp3','https://bigsoundbank.com/UPLOAD/mp3/0483.mp3'))
def source(item):
 name,url=item;p=CACHE/name
 if not p.exists():p.write_bytes(urllib.request.urlopen(url,timeout=45).read())
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ac','1','-ar','44100','-'])
 return name,(np.frombuffer(raw,dtype='<f4').astype(float),url,hashlib.sha256(p.read_bytes()).hexdigest())
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: originals=dict(pool.map(source,items))
manifest=json.loads((OUT/'sources.json').read_text())
import sys
for group,duration in [('snap',.11),('clap',.14),('ride',.35),('cross',.13)]:
 if '--snap-only' in sys.argv and group!='snap': continue
 if '--clap-only' in sys.argv and group!='clap': continue
 for i in range(1,9 if group=='snap' else 7 if group=='clap' else 5):
  name='snap.mp3' if group=='snap' else f'Clap_rr{i}.wav' if group=='clap' else f'{group}-{i}.flac'
  full,url,digest=originals[name]
  offset=round([1.10,2.26,3.34,4.08,.09,5.08,6.06,8.10][i-1]*44100) if group=='snap' else 0
  x=full[offset:offset+round(.3*44100)].copy() if group=='snap' else full.copy()
  x-=np.mean(x)
  onset=int(np.flatnonzero(abs(x)>=max(abs(x))*.06)[0]);start=max(0,onset-9)
  if group=='snap':
   # Align the actual snap, excluding quiet finger movement before the main impact.
   peak=int(np.argmax(abs(x))); window=max(0,peak-88)
   onset=window+int(np.flatnonzero(abs(x[window:peak+1])>=max(abs(x))*.08)[0])
   start=max(0,onset-9)
  x=x[start:start+round(duration*44100)].copy()
  t=np.arange(len(x))/44100
  if group=='ride': x*=np.exp(-np.maximum(0,t-.045)/.10)
  fade=round(.02*44100)
  x[-fade:]*=np.linspace(1,0,fade)
  x[:9]*=np.linspace(0,1,9)
  rms=np.sqrt(np.mean(x[:2205]**2))
  gain=min((.055 if group=='ride' else .07)/rms,(.65 if group=='snap' else .55)/max(abs(x)))
  x*=gain
  filename=f'ac-{group}-{i}.wav'
  with wave.open(str(OUT/filename),'wb') as w:
   w.setparams((1,2,44100,len(x),'NONE','not compressed'));w.writeframes(np.round(x*32767).astype('<i2').tobytes())
  manifest=[m for m in manifest if m['file']!=filename]
  manifest.append(dict(file=filename,url=url,source=name,sourceSHA256=digest,license='CC0 1.0',sourceOffsetSeconds=offset/44100,removedLeadingFrames=start,outputRate=44100,outputFrames=len(x),gain=float(gain),processing='Mono, DC removal, attack alignment, 0.2 ms entrance fade, 20 ms release fade, attack RMS matching; ride additionally has a gentle 100 ms decay after first 45 ms. Real recordings, no synthesized layers.'))
  print(filename, 'ms',round(len(x)/44.1),'attackRMS',round(float(np.sqrt(np.mean(x[:2205]**2))),4))
(OUT/'sources.json').write_text(json.dumps(manifest,indent=2)+'\n')
