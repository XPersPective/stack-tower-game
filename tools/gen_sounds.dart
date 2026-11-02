/// Stack Tower Game — deterministik ses varlığı üreteci (ADR-003).
/// game.js tone() sentezini birebir üretir: osilatör (sine/triangle/square/
/// sawtooth) + üstel zarf (0.012s attack) + üstel frekans rampası.
/// Kullanım: dart run tools/gen_sounds.dart [--check]
library;

// ignore_for_file: avoid_print — CLI aracı

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 44100;
const String outDir = 'assets/sounds';

/// game.js tone(): osc + gain zarfı.
/// freq→endFreq exponentialRamp; gain 0.0001→vol (0.012s)→0.0001 (dur).
List<double> tone({
  required double freq,
  double? endFreq,
  required double dur,
  required String type,
  required double vol,
  double delay = 0,
  int rate = sampleRate,
}) {
  final n = (dur * rate).round();
  final out = List<double>.filled(n, 0);
  final ef = endFreq ?? freq;
  final attackN = (0.012 * rate).round().clamp(1, n);
  var noiseState = 0x2545F491;
  double noise() {
    // deterministik beyaz gürültü (xorshift) — hi-hat için
    noiseState ^= (noiseState << 13) & 0xFFFFFFFF;
    noiseState ^= noiseState >> 17;
    noiseState ^= (noiseState << 5) & 0xFFFFFFFF;
    return (noiseState & 0xFFFF) / 32768.0 - 1.0;
  }

  for (var i = 0; i < n; i++) {
    final t = i / rate;
    final k = n > 1 ? i / (n - 1) : 0.0;
    // üstel frekans rampası
    final f = freq * math.pow(ef / freq, k);
    final phase = 2 * math.pi * f * t;
    double v;
    switch (type) {
      case 'sine':
        v = math.sin(phase);
      case 'triangle':
        v = 2 / math.pi * math.asin(math.sin(phase));
      case 'square':
        v = math.sin(phase) >= 0 ? 1.0 : -1.0;
      case 'sawtooth':
        v = 2 * (f * t % 1) - 1;
      case 'noise':
        v = noise();
      default:
        v = math.sin(phase);
    }
    // zarf: 0.0001 → vol (attackN) → 0.0001 (üstel düşüş)
    double env;
    if (i < attackN) {
      final a = 0.0001 * math.pow(vol / 0.0001, i / attackN);
      env = a;
    } else {
      final remain = (n - i).clamp(1, n);
      env = vol * math.pow(0.0001 / vol, (n - i) / (n - attackN).clamp(1, n));
      env = env * remain / remain; // (formsal)
    }
    out[i] = v * env;
  }
  return out;
}

/// Birkaç tonu gecikmeli olarak tek buffer'a karıştır.
List<double> mix(List<List<double>> parts) {
  var len = 0;
  for (final p in parts) {
    len = math.max(len, p.length);
  }
  final out = List<double>.filled(len, 0);
  for (final p in parts) {
    for (var i = 0; i < p.length; i++) {
      out[i] += p[i];
    }
  }
  return out;
}

List<double> toneDelayed(double delaySec, List<double> t) {
  final pad = (delaySec * sampleRate).round();
  if (pad <= 0) return t;
  return [...List<double>.filled(pad, 0), ...t];
}

void writeWav(String name, List<double> samples, {int rate = sampleRate}) {
  final bytes = BytesBuilder();
  final dataLen = samples.length * 2;
  // RIFF header
  bytes.add('RIFF'.codeUnits);
  bytes.add(_u32(36 + dataLen));
  bytes.add('WAVE'.codeUnits);
  bytes.add('fmt '.codeUnits);
  bytes.add(_u32(16));
  bytes.add(_u16(1)); // PCM
  bytes.add(_u16(1)); // mono
  bytes.add(_u32(rate));
  bytes.add(_u32(rate * 2));
  bytes.add(_u16(2));
  bytes.add(_u16(16));
  bytes.add('data'.codeUnits);
  bytes.add(_u32(dataLen));
  for (final s in samples) {
    final v = (s.clamp(-1.0, 1.0) * 32767).round();
    bytes.add(_u16(v & 0xFFFF));
  }
  File('$outDir/$name').writeAsBytesSync(bytes.toBytes());
  print('wrote $outDir/$name (${samples.length} samples)');
}

Uint8List _u32(int v) => Uint8List(4)..[0] = v & 0xFF..[1] = (v >> 8) & 0xFF..[2] = (v >> 16) & 0xFF..[3] = (v >> 24) & 0xFF;
Uint8List _u16(int v) => Uint8List(2)..[0] = v & 0xFF..[1] = (v >> 8) & 0xFF;

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  if (!checkOnly) {
    Directory(outDir).createSync(recursive: true);
  } else {
    var ok = true;
    for (final f in _expected) {
      final exists = File('$outDir/$f').existsSync();
      if (!exists) {
        stderr.writeln('MISSING $outDir/$f');
        ok = false;
      }
    }
    exit(ok ? 0 : 1);
  }

  // place: tone(240, 110, 0.12, triangle, 0.22)
  writeWav('place.wav', tone(freq: 240, endFreq: 110, dur: 0.12, type: 'triangle', vol: 0.22));

  // perfect1..8: b = min(1200, 640 + c*45); b + b*1.5 (+0.07s)
  for (var c = 1; c <= 8; c++) {
    final b = math.min(1200.0, 640.0 + c * 45);
    writeWav('perfect$c.wav', mix([
      tone(freq: b, dur: 0.08, type: 'sine', vol: 0.20),
      toneDelayed(0.07, tone(freq: b * 1.5, dur: 0.12, type: 'sine', vol: 0.17)),
    ]));
  }

  // win: 523/659/784/1047 sırayla (0.11s aralık)
  writeWav('win.wav', mix([
    for (var i = 0; i < 4; i++)
      toneDelayed(
        i * 0.11,
        tone(freq: [523.0, 659.0, 784.0, 1047.0][i], dur: 0.16, type: 'triangle', vol: 0.22),
      ),
  ]));

  // lose: tone(340, 70, 0.55, sawtooth, 0.22)
  writeWav('lose.wav', tone(freq: 340, endFreq: 70, dur: 0.55, type: 'sawtooth', vol: 0.22));

  // coin: tone(1180, 1560, 0.09, square, 0.10)
  writeWav('coin.wav', tone(freq: 1180, endFreq: 1560, dur: 0.09, type: 'square', vol: 0.10));

  // box: 420 + 660/880/1320 (0.12s sonra ardışık)
  writeWav('box.wav', mix([
    tone(freq: 420, dur: 0.1, type: 'sine', vol: 0.18),
    for (var i = 0; i < 3; i++)
      toneDelayed(
        0.12 + i * 0.1,
        tone(freq: [660.0, 880.0, 1320.0][i], dur: 0.14, type: 'sine', vol: 0.2),
      ),
  ]));

  // shield: tone(320, 960, 0.22, triangle, 0.22)
  writeWav('shield.wav', tone(freq: 320, endFreq: 960, dur: 0.22, type: 'triangle', vol: 0.22));

  // start: tone(480, 900, 0.16, triangle, 0.18)
  writeWav('start.wav', tone(freq: 480, endFreq: 900, dur: 0.16, type: 'triangle', vol: 0.18));

  /* ---------------- PB-017: kombo katmanları + kritik/gizem ---------------- */

  // crit: çift oktav arpej (660 → 1320 → 990 → 1980), kısa ve parlak
  writeWav('crit.wav', mix([
    for (var i = 0; i < 4; i++)
      toneDelayed(
        i * 0.055,
        tone(
          freq: [660.0, 1320.0, 990.0, 1980.0][i],
          dur: 0.14,
          type: 'square',
          vol: 0.12,
        ),
      ),
  ]));

  // fanfare: kombo ×10 kilometre taşı — yükselen beşli + final akoru
  writeWav('fanfare.wav', mix([
    for (var i = 0; i < 5; i++)
      toneDelayed(
        i * 0.09,
        tone(freq: [523.0, 659.0, 784.0, 1047.0, 1319.0][i],
            dur: 0.18, type: 'triangle', vol: 0.18),
      ),
    toneDelayed(0.5, tone(freq: 1047, dur: 0.5, type: 'sine', vol: 0.12)),
    toneDelayed(0.5, tone(freq: 1319, dur: 0.5, type: 'sine', vol: 0.10)),
  ]));

  // mystery: sandık gizemi — alçak tremololu sürüklenme + parıltı
  writeWav('mystery.wav', mix([
    tone(freq: 220, endFreq: 330, dur: 1.2, type: 'sine', vol: 0.14),
    toneDelayed(0.25, tone(freq: 440, endFreq: 660, dur: 0.9, type: 'triangle', vol: 0.07)),
    toneDelayed(0.6, tone(freq: 880, dur: 0.5, type: 'sine', vol: 0.05)),
  ]));

  // Ritim katmanları: 4 bar × 120 BPM = 8.0s, 22.05kHz (dosya boyutu/parlaklık dengesi)
  const layerRate = 22050;
  const bpm = 120.0;
  const beat = 60.0 / bpm; // 0.5s
  const bars = 4;
  const total = beat * 4 * bars; // 8s

  // layer1: kick (her vuruş) + yumuşak bas vurgusu
  final l1 = <double>[];
  for (var b = 0; b < 4 * bars; b++) {
    final at = b * beat;
    final start = (at * layerRate).round();
    final hit = tone(freq: 95, endFreq: 45, dur: 0.16, type: 'sine', vol: 0.30, rate: layerRate);
    for (var i = 0; i < hit.length; i++) {
      final idx = start + i;
      if (idx < l1.length) {
        l1[idx] += hit[i];
      } else {
        l1.add(hit[i]);
      }
    }
    while (l1.length < start + hit.length) {
      l1.add(0);
    }
  }
  writeWav('layer1.wav', _fit(l1, (total * layerRate).round()), rate: layerRate);

  // layer2: hi-hat (sekizlik) — yüksek gürültü, kısa
  final l2 = List<double>.filled((total * layerRate).round(), 0);
  for (var i = 0; i < 8 * bars * 4; i++) {
    final at = i * beat / 2;
    final start = (at * layerRate).round();
    final hat = tone(freq: 9000, dur: 0.035, type: 'noise', vol: 0.05, rate: layerRate);
    for (var k = 0; k < hat.length && start + k < l2.length; k++) {
      l2[start + k] += hat[k];
    }
  }
  writeWav('layer2.wav', l2, rate: layerRate);

  // layer3: bas arpej (çeyrek notalar) — 110/110/146.8/98 döngüsü
  final l3 = List<double>.filled((total * layerRate).round(), 0);
  const bassNotes = [110.0, 110.0, 146.8, 98.0];
  for (var i = 0; i < 4 * bars; i++) {
    final at = i * beat;
    final start = (at * layerRate).round();
    final note = tone(
        freq: bassNotes[i % 4], dur: 0.42, type: 'triangle', vol: 0.12, rate: layerRate);
    for (var k = 0; k < note.length && start + k < l3.length; k++) {
      l3[start + k] += note[k];
    }
  }
  writeWav('layer3.wav', l3, rate: layerRate);

  /* ---------------- PB-032: arayüz sesleri (premium dokunsal geri bildirim) ---------------- */

  // tap: kısa, yumuşak tık — her düğme/panelde çalar (çok kısa, sıcak)
  writeWav('tap.wav', mix([
    tone(freq: 880, endFreq: 620, dur: 0.045, type: 'sine', vol: 0.10),
    toneDelayed(0.012, tone(freq: 1760, dur: 0.035, type: 'sine', vol: 0.045)),
  ]));

  // whoosh: sayfa geçişi — süpürme benzeri gürültü süzülüşü
  writeWav('whoosh.wav', mix([
    tone(freq: 400, endFreq: 2600, dur: 0.26, type: 'noise', vol: 0.055),
    tone(freq: 300, endFreq: 1500, dur: 0.24, type: 'sine', vol: 0.045),
  ]));

  // reward: ödül kazanımı — yükselen üçlü akor (parlak, "kazandın" hissi)
  writeWav('reward.wav', mix([
    for (var i = 0; i < 3; i++)
      toneDelayed(
        i * 0.075,
        tone(freq: [784.0, 1047.0, 1568.0][i], dur: 0.24, type: 'sine', vol: 0.14),
      ),
    toneDelayed(0.16, tone(freq: 392.0, dur: 0.42, type: 'triangle', vol: 0.09)),
  ]));

  // unlock: kilit açılışı — aşağı süpürme + parlak çıngı
  writeWav('unlock.wav', mix([
    tone(freq: 1200, endFreq: 520, dur: 0.28, type: 'triangle', vol: 0.12),
    toneDelayed(0.10, tone(freq: 1568, dur: 0.30, type: 'sine', vol: 0.10)),
    toneDelayed(0.18, tone(freq: 2093, dur: 0.28, type: 'sine', vol: 0.07)),
  ]));

  // error: yetersiz kaynak / geçersiz işlem — kısa alçak iki nota
  writeWav('error.wav', mix([
    tone(freq: 200, dur: 0.10, type: 'square', vol: 0.09),
    toneDelayed(0.11, tone(freq: 150, dur: 0.16, type: 'square', vol: 0.09)),
  ]));

  // pop: yıldız/rozet kazanımı — tek parlak nota + üst harmonik
  writeWav('pop.wav', mix([
    tone(freq: 1320, dur: 0.10, type: 'sine', vol: 0.14),
    toneDelayed(0.03, tone(freq: 2640, dur: 0.09, type: 'sine', vol: 0.06)),
  ]));

  // PB-033/034: arka plan müzik döngüsü (dikişsiz, 22050 Hz mono)
  writeWav('music_loop.wav', musicLoop(), rate: 22050);
}

/// Loop uzunluğunu tam örnek sayısına sabitle (sondaki kuyruk kırpılır).
List<double> _fit(List<double> src, int n) {
  if (src.length == n) return src;
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n && i < src.length; i++) {
    out[i] = src[i];
  }
  return out;
}

/// PB-033/034 — arka plan müzik döngüsü (dikişsiz): 84 BPM, I–V–vi–IV
/// (Cmaj9 · G/B · Am7 · Fmaj7), 8 bar ≈ 22.86 sn @22050 Hz mono (~1 MB).
/// Katmanlar: yavaş saldırılı detune pad + sekizlik arp pluck + yumuşak bas +
/// dört barda bir çan parıltısı. Baş/son 0.4 sn nefes fade'i döngü dikişini
/// yumuşatır; tüm zarflar bar sınırında biter.
List<double> musicLoop() {
  const rate = 22050;
  const bpm = 84.0;
  const beat = 60 / bpm;
  const bar = 4 * beat;
  const bars = 8;
  final n = (bar * bars * rate).round();
  final out = List<double>.filled(n, 0.0);

  void padVoice(double start, double dur, double f, double vol) {
    final s0 = (start * rate).round();
    final len = (dur * rate).round();
    final att = (0.9 * rate).round();
    final rel = (1.1 * rate).round();
    for (var i = 0; i < len; i++) {
      final idx = s0 + i;
      if (idx < 0 || idx >= n) continue;
      double env;
      if (i < att) {
        env = i / att;
      } else if (i > len - rel) {
        env = (len - i) / rel;
      } else {
        env = 1.0;
      }
      env = env * env * (3 - 2 * env); // smoothstep
      final t = i / rate;
      final v = math.sin(2 * math.pi * f * t) * 0.60 +
          math.sin(2 * math.pi * f * 1.0035 * t) * 0.25 +
          math.sin(2 * math.pi * f * 0.9965 * t) * 0.25;
      out[idx] += v * env * vol;
    }
  }

  void pluck(double start, double f, double vol) {
    final s0 = (start * rate).round();
    final len = (0.30 * rate).round();
    for (var i = 0; i < len; i++) {
      final idx = s0 + i;
      if (idx < 0 || idx >= n) break;
      final t = i / rate;
      final env = math.exp(-t * 9) * (i < 40 ? i / 40 : 1.0);
      out[idx] += math.sin(2 * math.pi * f * t) * env * vol;
    }
  }

  void bassNote(double start, double f, double vol, double dur) {
    final s0 = (start * rate).round();
    final len = (dur * rate).round();
    final att = (0.02 * rate).round();
    for (var i = 0; i < len; i++) {
      final idx = s0 + i;
      if (idx < 0 || idx >= n) break;
      final t = i / rate;
      final env = i < att ? i / att : math.exp(-(t - 0.02) * 2.2);
      out[idx] += math.sin(2 * math.pi * f * t) * env * vol;
    }
  }

  const padC = [130.81, 164.81, 196.00, 246.94, 293.66]; // Cmaj9
  const padG = [123.47, 196.00, 246.94, 293.66]; // G/B
  const padAm = [110.00, 130.81, 164.81, 196.00]; // Am7
  const padF = [87.31, 110.00, 130.81, 164.81]; // Fmaj7
  const chords = [
    {'pad': padC, 'bass': 65.41, 'arp': [329.63, 392.00, 493.88, 587.33, 659.26]},
    {'pad': padG, 'bass': 61.74, 'arp': [293.66, 392.00, 493.88, 587.33, 739.99]},
    {'pad': padAm, 'bass': 55.00, 'arp': [261.63, 329.63, 392.00, 523.25, 659.26]},
    {'pad': padF, 'bass': 87.31, 'arp': [349.23, 440.00, 523.25, 659.26, 698.46]},
  ];
  const pat = [0, 2, 1, 3, 2, 4, 3, 1];
  const eighth = beat / 2;

  for (var c = 0; c < 4; c++) {
    final t0 = c * 2 * bar;
    final pad = (chords[c]['pad'] as List<double>);
    final arp = (chords[c]['arp'] as List<double>);
    final bass = chords[c]['bass'] as double;
    for (final f in pad) {
      padVoice(t0, bar * 2 + 1.0, f, 0.082);
    }
    for (var b = 0; b < 2; b++) {
      bassNote(t0 + b * bar, bass, 0.15, 1.2);
      bassNote(t0 + b * bar + 2 * beat, bass, 0.09, 0.8);
    }
    for (var e = 0; e < 16; e++) {
      final tone = arp[pat[e % pat.length] % arp.length] * (e % 8 >= 4 ? 1.0 : 2.0);
      pluck(t0 + e * eighth, tone, e % 2 == 0 ? 0.070 : 0.048);
    }
    // dört barda bir çan parıltısı
    if (c % 2 == 0) {
      pluck(t0 + bar * 1.5, arp.last * 2, 0.030);
    }
  }

  // dikişsiz döngü: nefes fade + tepe normalizasyonu (%85)
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    final te = (n - i) / rate;
    if (t < 0.4) out[i] *= t / 0.4;
    if (te < 0.4) out[i] *= te / 0.4;
  }
  var peak = 0.0;
  for (final v in out) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  final gain = peak > 0 ? 0.85 / peak : 1.0;
  for (var i = 0; i < n; i++) {
    out[i] *= gain;
  }
  return out;
}

const List<String> _expected = [
  'place.wav', 'crit.wav', 'fanfare.wav', 'mystery.wav',
  'layer1.wav', 'layer2.wav', 'layer3.wav',
  'perfect1.wav', 'perfect2.wav', 'perfect3.wav', 'perfect4.wav',
  'perfect5.wav', 'perfect6.wav', 'perfect7.wav', 'perfect8.wav',
  'win.wav', 'lose.wav', 'coin.wav', 'box.wav', 'shield.wav', 'start.wav',
  // PB-032: arayüz sesleri
  'tap.wav', 'whoosh.wav', 'reward.wav', 'unlock.wav', 'error.wav', 'pop.wav',
  // PB-033/034: arka plan müzik döngüsü
  'music_loop.wav',
];
