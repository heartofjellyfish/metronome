"""Audition CC0 Virtuosity rimshot highest velocity layers, without changing app assets.
Input: /tmp/rimshot-heavy/{snaremic,oh}-{11,12}.wav, decoded from pinned
sfzinstruments/virtuosity_drums 9f04cf9a734527edfbb0a4eee1f674e45bbf71bc.
"""
import array, math, pathlib, wave, json, hashlib
RATE=48000
OUT=pathlib.Path('Design/Audio/rimshot-heavy-v1')
OUT.mkdir(parents=True,exist_ok=True)
def read(path):
 with wave.open(str(path),'rb') as w:
  rate=w.getframerate(); channels=w.getnchannels()
  assert w.getsampwidth()==2
  raw=array.array('h',w.readframes(w.getnframes()))
 a=[sum(raw[i:i+channels])/channels/32768 for i in range(0,len(raw),channels)]
 mean=sum(a)/len(a); a=[v-mean for v in a]
 n=int((len(a)-1)*RATE/rate)
 return [a[int(i*rate/RATE)]*(1-i*rate/RATE%1)+a[int(i*rate/RATE)+1]*(i*rate/RATE%1) for i in range(n)]
def save(name,samples):
 assert max(map(abs,samples))<1
 with wave.open(str(OUT/name),'wb') as w:
  w.setparams((1,2,RATE,0,'NONE','not compressed'))
  w.writeframes(array.array('h',[round(x*32767) for x in samples]).tobytes())
 print(name,'peak',round(max(map(abs,samples)),3))
clips={}
for v in [11,12]:
 near=read(f'/tmp/rimshot-heavy/snaremic-{v}.wav')
 overhead=read(f'/tmp/rimshot-heavy/oh-{v}.wav')
 peak=max(map(abs,near)); onset=max(0,next(i for i,x in enumerate(near) if abs(x)>peak*.015)-48)
 for label,mix in [('a-close',0),('b-full',.35)]:
  # Keep both microphones on the original recording timeline.
  n=min(len(near),len(overhead),onset+int(RATE*.48))
  sound=[near[i]+mix*overhead[i] for i in range(onset,n)]
  rms=math.sqrt(sum(x*x for x in sound[:2400])/2400)
  gain=min(.14/rms,.65/max(map(abs,sound)))
  clips[label,v]=[x*gain*min(1,i/14)*min(1,(len(sound)-1-i)/960) for i,x in enumerate(sound)]
for label in ['a-close','b-full']:
 samples=[0.0]*int(RATE*10.65)
 for beat in range(16):
  strength=[1,.25,.34,.25][beat%4]
  hit=clips[label,12 if beat%2==0 else 11]
  start=int(beat*.625*RATE)
  for i,x in enumerate(hit):samples[start+i]+=x*strength
 save(label+'-4-4.wav',samples)
# Loudness-controlled comparison: old and close-heavy attacks at matching RMS,
# four old beats, pause, four heavy beats. This separates timbre from gain.
old=read('TheMetronome/AcousticSamples/ac-rimshot-1.wav')
new=clips['a-close',12]
pair=[0.0]*int(RATE*6.5)
for section,clip in enumerate([old,new]):
 rms=math.sqrt(sum(x*x for x in clip[:2400])/2400)
 gain=min(.08/rms,.6/max(map(abs,clip)))
 for beat in range(4):
  start=int((section*3.5+beat*.625)*RATE)
  for i,x in enumerate(clip):pair[start+i]+=x*gain*[1,.25,.34,.25][beat]
save('old-then-heavy-matched.wav',pair)
meta={'source':'https://github.com/sfzinstruments/virtuosity_drums','commit':'9f04cf9a734527edfbb0a4eee1f674e45bbf71bc','license':'CC0','layers':[11,12],'meter':'4/4','bpm':96,'gains':[1,.25,.34,.25],'fullOverheadMix':.35,'note':'Auditions only. App assets unchanged. Highest two velocity layers; not independent round robins.'}
(OUT/'provenance.json').write_text(json.dumps(meta,indent=2)+'\n')

# Explicit install flag keeps ordinary auditions free of app mutations.
if '--install' in __import__('sys').argv:
 target=pathlib.Path('TheMetronome/AcousticSamples')
 manifest=json.loads((target/'sources.json').read_text())
 for slot,layer in enumerate([12,11,12,11],1):
  name=f'ac-rimshot-{slot}.wav'
  clip=clips['a-close',layer]
  with wave.open(str(target/name),'wb') as w:
   w.setparams((1,2,RATE,0,'NONE','not compressed'))
   w.writeframes(array.array('h',[round(x*32767) for x in clip]).tobytes())
  source=f'Samples/snaremic/snare/snaremic_snare_rimshot_vl{layer}.flac'
  manifest=[x for x in manifest if x['file']!=name]
  manifest.append({'file':name,'source':source,'url':f"https://raw.githubusercontent.com/sfzinstruments/virtuosity_drums/{meta['commit']}/{source}", 'sourceSHA256':hashlib.sha256(pathlib.Path(f'/tmp/rimshot-heavy/snaremic-{layer}.flac').read_bytes()).hexdigest(),'outputRate':RATE,'outputFrames':len(clip),'processing':'A close audition: 0.14 attack RMS target, 0.65 peak ceiling, 0.48s tail; two velocity layers repeated across four legacy slots, not four independent takes.'})
 (target/'sources.json').write_text(json.dumps(manifest,indent=2)+'\n')
