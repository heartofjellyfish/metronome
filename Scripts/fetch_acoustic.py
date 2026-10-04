import concurrent.futures, hashlib, json, pathlib, urllib.request
revision='9f04cf9a734527edfbb0a4eee1f674e45bbf71bc'
root=pathlib.Path('/tmp/metronome-acoustic-source');root.mkdir(exist_ok=True)
files=[]
for group,stem,layers in [('closed','oh_hh_closed',[2,3]),('half','oh_hh_half',[2]),('pedal','oh_hh_pedal',[2])]:
 for layer in layers:
  for rr in range(1,5):
   files.append((f'{group}-v{layer}-{rr}', f'Samples/oh/hh/{stem}_vl{layer}_rr{rr}.flac'))
for n,layer in enumerate([6,7,8,9],1): files.append((f'stick-{n}',f'Samples/snaremic/snare/snaremic_snare_crossstick_vl{layer}.flac'))
for rr in range(1,5): files.append((f'shaker-{rr}',f'Samples/perc/close/shaker/LShaker_Shake1D_rr{rr}_Close.wav'))
def fetch(item):
 name,path=item; url=f'https://raw.githubusercontent.com/sfzinstruments/virtuosity_drums/{revision}/{path}'
 data=urllib.request.urlopen(url,timeout=60).read(); dest=root/(name+pathlib.Path(path).suffix);dest.write_bytes(data)
 return dict(name=name,source=path,url=url,sha256=hashlib.sha256(data).hexdigest(),local=str(dest))
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool: manifest=list(pool.map(fetch,files))
(root/'manifest.json').write_text(json.dumps(manifest,indent=2))
license=urllib.request.urlopen(f'https://raw.githubusercontent.com/sfzinstruments/virtuosity_drums/{revision}/LICENSE',timeout=60).read()
pathlib.Path('TheMetronome/AcousticSamples/Virtuosity-LICENSE.txt').write_bytes(license)
print(f'Downloaded {len(manifest)} samples; source commit {revision}; license saved.')
