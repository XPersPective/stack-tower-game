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

const List<String> _expected = [
  'place.wav', 'crit.wav', 'fanfare.wav', 'mystery.wav',
  'layer1.wav', 'layer2.wav', 'layer3.wav',
  'perfect1.wav', 'perfect2.wav', 'perfect3.wav', 'perfect4.wav',
  'perfect5.wav', 'perfect6.wav', 'perfect7.wav', 'perfect8.wav',
  'win.wav', 'lose.wav', 'coin.wav', 'box.wav', 'shield.wav', 'start.wav',
];
