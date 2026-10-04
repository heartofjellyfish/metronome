"""Replace the wood voice with two real VCSL takes, alternating A/B/A/B.
Requires numpy. Source recordings are CC0; no synthesized hits or added reverb.
"""
import hashlib, json, pathlib, urllib.request, wave
import numpy as np
ROOT = pathlib.Path(__file__).resolve().parents[1]
DEST = ROOT / 'TheMetronome/AcousticSamples'
REV = 'c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e'
CACHE = pathlib.Path('/tmp/metronome-dry-wood')
CACHE.mkdir(exist_ok=True)
manifest = json.loads((DEST / 'sources.json').read_text())
for take in (1, 2):
    name = f'wood_click_f_rr{take}.wav'
    source = 'Idiophones/Struck Idiophones/Woodblock/' + name
    url = f'https://raw.githubusercontent.com/sgossner/VCSL/{REV}/' + source.replace(' ', '%20')
    path = CACHE / name
    if not path.exists(): path.write_bytes(urllib.request.urlopen(url).read())
    data = path.read_bytes()
    with wave.open(str(path)) as w:
        assert w.getsampwidth() == 3 and w.getframerate() == 44100
        b = np.frombuffer(w.readframes(w.getnframes()), dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        x = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        x = ((x ^ 0x800000) - 0x800000).reshape(-1, w.getnchannels()).mean(axis=1) / 8388608
    x -= np.mean(x)
    # Retain 0.25 ms before the first substantial attack; suppress recorded room tail.
    onset = int(np.flatnonzero(np.abs(x) >= np.max(np.abs(x)) * .08)[0])
    start = max(0, onset - 11)
    x = x[start:start + 3969].copy()  # 90 ms total, formerly ~300–350 ms.
    t = np.arange(len(x)) / 44100
    envelope = np.exp(-np.maximum(0, t - .008) / .018)
    envelope *= np.clip((.09 - t) / .01, 0, 1)
    x *= envelope
    gain = .55 / np.max(np.abs(x))
    x *= gain
    for slot in (take, take + 2):
        filename = f'ac-wood-{slot}.wav'
        with wave.open(str(DEST / filename), 'wb') as w:
            w.setparams((1, 2, 44100, len(x), 'NONE', 'not compressed'))
            w.writeframes(np.round(x * 32767).astype('<i2').tobytes())
        entry = next(e for e in manifest if e['file'] == filename)
        entry.clear()
        entry.update(file=filename, source=source, url=url, sourceSHA256=hashlib.sha256(data).hexdigest(), license='CC0 1.0', inputRate=44100, outputRate=44100, outputFrames=len(x), removedLeadingFrames=start, gain=float(gain), processing='Mono; DC removal; 0.25 ms pre-attack; decay after 8 ms with 18 ms time constant; 90 ms tail; final 10 ms fade; peak 0.55. Two real takes alternate A/B/A/B.')
    print(f'{name}: onset {start} frames; output {len(x)/44.1:.0f} ms; peak {max(abs(x)):.3f}')
(DEST / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
