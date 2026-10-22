"""
Nusa Vale - Additional Cozy Background Music Generator
Generates 4 distinct cozy BGM tracks:
1. town_friendly_breeze.wav (Town / Village Theme - Upbeat, friendly, accordion + flute + marimba)
2. deep_forest_enchanted.wav (Deep Forest / Ancient Woods Theme - Dreamy, mystical, kalimba + rhodes + ocarina)
3. cozy_shop_warung.wav (Shop / Warung / Market Theme - Quirky, charming, ragtime acoustic + pizzicato)
4. rainy_day_solitude.wav (Rainy Day Farm / Peaceful Retreat Theme - Soft piano + gentle nylon guitar + flute)
"""

import math
import struct
import wave
import array
import random
import os

SAMPLE_RATE = 44100
TWO_PI = 2.0 * math.pi

def midi_to_freq(midi_note):
    return 440.0 * (2.0 ** ((midi_note - 69.0) / 12.0))

class ExtraSynth:
    def __init__(self, sample_rate=44100):
        self.sr = sample_rate

    def render_guitar_pluck(self, midi_note, duration, volume=0.65):
        """Karplus-Strong acoustic string with wooden pluck."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        period = int(self.sr / freq)
        if period < 2:
            return out
        buf = [0.0] * period
        for i in range(period):
            t = i / period
            tri = (2.0 * t if t < 0.5 else 2.0 * (1.0 - t)) - 0.5
            noise = (random.random() * 2.0 - 1.0) * 0.35
            buf[i] = (tri * 0.65 + noise * 0.35)
        decay = 0.993 if midi_note < 60 else 0.986
        last_val = 0.0
        buf_idx = 0
        for n in range(total_samples):
            val = 0.5 * (buf[buf_idx] + last_val) * decay
            last_val = buf[buf_idx]
            buf[buf_idx] = val
            buf_idx = (buf_idx + 1) % period
            fade = 1.0
            if n > total_samples - 200:
                fade = (total_samples - n) / 200.0
            out[n] = val * volume * fade
        return out

    def render_pizzicato(self, midi_note, duration=0.4, volume=0.55):
        """Cute, tight pizzicato string pluck."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        for n in range(total_samples):
            t = n / self.sr
            s1 = math.sin(TWO_PI * freq * t)
            s2 = math.sin(TWO_PI * freq * 2.0 * t) * 0.4
            s3 = math.sin(TWO_PI * freq * 3.0 * t) * 0.15
            env = math.exp(-t / 0.12)
            snap = math.exp(-t / 0.005) * 0.3
            sample = (s1 + s2 + s3 + snap) * env
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_marimba(self, midi_note, duration, volume=0.52):
        """Warm wooden marimba mallet tone."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        tau_fund = 0.42
        tau_over = 0.05
        over_ratio = 3.92
        attack_samples = int(0.003 * self.sr)
        for n in range(total_samples):
            t = n / self.sr
            env_att = (n / attack_samples) if n < attack_samples else 1.0
            env_fund = math.exp(-t / tau_fund)
            env_over = math.exp(-t / tau_over)
            s_fund = math.sin(TWO_PI * freq * t)
            s_over = math.sin(TWO_PI * freq * over_ratio * t)
            sample = (s_fund * 0.85 * env_fund + s_over * 0.35 * env_over) * env_att
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_flute(self, midi_note, duration, volume=0.48, vibrato_delay=0.12):
        """Pastoral wooden flute / ocarina with breath."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        attack_samples = int(0.04 * self.sr)
        release_samples = int(0.08 * self.sr)
        sustain_samples = max(0, total_samples - attack_samples - release_samples)
        vib_rate = 5.3
        phase = 0.0
        for n in range(total_samples):
            t = n / self.sr
            if n < attack_samples:
                env = (n / attack_samples) ** 1.4
            elif n < attack_samples + sustain_samples:
                env = 1.0
            else:
                rel_idx = n - (attack_samples + sustain_samples)
                env = max(0.0, 1.0 - (rel_idx / release_samples))
            vib = 0.0
            if t > vibrato_delay:
                vib_amount = min(1.0, (t - vibrato_delay) / 0.22) * 0.009
                vib = math.sin(TWO_PI * vib_rate * t) * vib_amount
            current_freq = freq * (1.0 + vib)
            phase += TWO_PI * current_freq / self.sr
            if phase > TWO_PI:
                phase -= TWO_PI
            h1 = math.sin(phase)
            h2 = math.sin(phase * 2.0) * 0.22
            h3 = math.sin(phase * 3.0) * 0.08
            breath = (random.random() * 2.0 - 1.0) * 0.025 * env
            sample = (h1 + h2 + h3 + breath) * env
            out[n] = sample * volume
        return out

    def render_accordion(self, midi_note, duration, volume=0.42):
        """Warm folk accordion / melodica with twin reeds."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        detune = 0.45 # Hz slight chorus
        f1 = freq - detune
        f2 = freq + detune
        att_samples = int(0.035 * self.sr)
        rel_samples = int(0.06 * self.sr)
        sust_samples = max(0, total_samples - att_samples - rel_samples)
        p1, p2 = 0.0, 0.0
        for n in range(total_samples):
            t = n / self.sr
            if n < att_samples:
                env = (n / att_samples) ** 1.2
            elif n < att_samples + sust_samples:
                env = 1.0
            else:
                rel_idx = n - (att_samples + sust_samples)
                env = max(0.0, 1.0 - (rel_idx / rel_samples))
            p1 += TWO_PI * f1 / self.sr
            p2 += TWO_PI * f2 / self.sr
            # Reed harmonics
            r1 = (math.sin(p1) + 0.35 * math.sin(2.0 * p1) + 0.2 * math.sin(3.0 * p1) + 0.1 * math.sin(4.0 * p1))
            r2 = (math.sin(p2) + 0.35 * math.sin(2.0 * p2) + 0.2 * math.sin(3.0 * p2) + 0.1 * math.sin(4.0 * p2))
            sample = 0.5 * (r1 + r2) * env
            out[n] = sample * volume
        return out

    def render_piano(self, midi_note, duration, volume=0.55):
        """Soft, warm upright piano."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        tau = 0.9 if midi_note > 60 else 1.4
        for n in range(total_samples):
            t = n / self.sr
            att = min(1.0, n / (0.006 * self.sr))
            s1 = math.sin(TWO_PI * freq * t) * math.exp(-t / tau)
            s2 = math.sin(TWO_PI * freq * 2.003 * t) * 0.3 * math.exp(-t / (tau * 0.7))
            s3 = math.sin(TWO_PI * freq * 3.007 * t) * 0.12 * math.exp(-t / (tau * 0.5))
            sample = (s1 + s2 + s3) * att
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_rhodes(self, midi_note, duration, volume=0.42):
        """Lush electric piano / bell tines."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        for n in range(total_samples):
            t = n / self.sr
            mod_env = math.exp(-t / 0.18) * 1.5
            mod = math.sin(TWO_PI * (freq * 2.0) * t) * mod_env
            carrier = math.sin(TWO_PI * freq * t + mod)
            body = math.sin(TWO_PI * freq * t) * math.exp(-t / 1.1)
            env = math.exp(-t / 0.85)
            sample = (carrier * 0.6 + body * 0.4) * env
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_bell(self, midi_note, duration=1.2, volume=0.35):
        """Crystalline magical chime / kalimba bell."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        for n in range(total_samples):
            t = n / self.sr
            s1 = math.sin(TWO_PI * freq * t) * math.exp(-t / 0.6)
            s2 = math.sin(TWO_PI * freq * 2.76 * t) * 0.4 * math.exp(-t / 0.25)
            s3 = math.sin(TWO_PI * freq * 5.40 * t) * 0.2 * math.exp(-t / 0.12)
            sample = s1 + s2 + s3
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_bass(self, midi_note, duration, volume=0.62):
        """Warm upright bass."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        for n in range(total_samples):
            t = n / self.sr
            s1 = math.sin(TWO_PI * freq * t)
            s2 = math.sin(TWO_PI * freq * 2.0 * t) * 0.25
            att = min(1.0, n / (0.015 * self.sr))
            decay = math.exp(-t / 0.95)
            sample = (s1 + s2) * att * decay
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_shaker(self, duration=0.08, volume=0.16):
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        last_in, last_out = 0.0, 0.0
        for n in range(total_samples):
            noise = random.random() * 2.0 - 1.0
            hp = noise - last_in + 0.82 * last_out
            last_in = noise
            last_out = hp
            env = math.sin(math.pi * (n / total_samples)) ** 1.3
            out[n] = hp * env * volume
        return out

    def render_woodblock(self, midi_note=76, volume=0.22):
        freq = midi_to_freq(midi_note)
        duration = 0.06
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        for n in range(total_samples):
            t = n / self.sr
            s = math.sin(TWO_PI * freq * t) + math.sin(TWO_PI * freq * 2.5 * t) * 0.3
            env = math.exp(-t / 0.012)
            out[n] = s * env * volume
        return out


class ScoreMixer:
    def __init__(self, bpm=102, total_bars=32, sample_rate=44100):
        self.bpm = bpm
        self.sr = sample_rate
        self.beat_dur = 60.0 / bpm
        self.bar_dur = self.beat_dur * 4.0
        self.total_duration = total_bars * self.bar_dur
        self.total_samples = int(self.total_duration * self.sr)
        self.left = [0.0] * self.total_samples
        self.right = [0.0] * self.total_samples
        self.synth = ExtraSynth(sample_rate)

    def add_note(self, start_bar, beat_offset, instrument, note, duration_beats, volume=1.0, pan=0.0):
        start_sec = start_bar * self.bar_dur + beat_offset * self.beat_dur
        start_sample = int(start_sec * self.sr)
        dur_sec = duration_beats * self.beat_dur
        
        s = self.synth
        if instrument == 'guitar':      samples = s.render_guitar_pluck(note, dur_sec, volume)
        elif instrument == 'pizzicato': samples = s.render_pizzicato(note, dur_sec, volume)
        elif instrument == 'marimba':   samples = s.render_marimba(note, dur_sec, volume)
        elif instrument == 'flute':     samples = s.render_flute(note, dur_sec, volume)
        elif instrument == 'accordion': samples = s.render_accordion(note, dur_sec, volume)
        elif instrument == 'piano':     samples = s.render_piano(note, dur_sec, volume)
        elif instrument == 'rhodes':    samples = s.render_rhodes(note, dur_sec, volume)
        elif instrument == 'bell':      samples = s.render_bell(note, dur_sec, volume)
        elif instrument == 'bass':      samples = s.render_bass(note, dur_sec, volume)
        elif instrument == 'woodblock': samples = s.render_woodblock(note, volume)
        else: return
            
        pan = max(-1.0, min(1.0, pan))
        angle = (pan + 1.0) * (math.pi / 4.0)
        gain_l = math.cos(angle)
        gain_r = math.sin(angle)
        
        for i, val in enumerate(samples):
            idx = start_sample + i
            if idx >= self.total_samples:
                break
            self.left[idx] += val * gain_l
            self.right[idx] += val * gain_r

    def add_shaker(self, start_bar, beat_offset, volume=0.16, pan=0.2):
        start_sec = start_bar * self.bar_dur + beat_offset * self.beat_dur
        start_sample = int(start_sec * self.sr)
        samples = self.synth.render_shaker(0.08, volume)
        angle = (pan + 1.0) * (math.pi / 4.0)
        gain_l = math.cos(angle)
        gain_r = math.sin(angle)
        for i, val in enumerate(samples):
            idx = start_sample + i
            if idx >= self.total_samples:
                break
            self.left[idx] += val * gain_l
            self.right[idx] += val * gain_r

    def apply_reverb_and_limiter(self, wet_mix=0.22, feedback=0.38):
        delay_times_l = [int(0.029 * self.sr), int(0.037 * self.sr), int(0.043 * self.sr)]
        delay_times_r = [int(0.031 * self.sr), int(0.039 * self.sr), int(0.047 * self.sr)]
        rev_l = [0.0] * self.total_samples
        rev_r = [0.0] * self.total_samples
        for dt in delay_times_l:
            for i in range(dt, self.total_samples):
                rev_l[i] += (self.left[i - dt] + rev_l[i - dt] * feedback) / len(delay_times_l)
        for dt in delay_times_r:
            for i in range(dt, self.total_samples):
                rev_r[i] += (self.right[i - dt] + rev_r[i - dt] * feedback) / len(delay_times_r)
        max_peak = 0.0001
        for i in range(self.total_samples):
            self.left[i] = self.left[i] * (1.0 - wet_mix * 0.5) + rev_l[i] * wet_mix
            self.right[i] = self.right[i] * (1.0 - wet_mix * 0.5) + rev_r[i] * wet_mix
            if abs(self.left[i]) > max_peak: max_peak = abs(self.left[i])
            if abs(self.right[i]) > max_peak: max_peak = abs(self.right[i])
        norm_factor = 0.88 / max_peak if max_peak > 0 else 1.0
        for i in range(self.total_samples):
            l = self.left[i] * norm_factor
            r = self.right[i] * norm_factor
            self.left[i] = math.tanh(l) if abs(l) > 0.8 else l
            self.right[i] = math.tanh(r) if abs(r) > 0.8 else r

    def save_wav(self, filepath):
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        raw_shorts = array.array('h')
        for i in range(self.total_samples):
            l = int(max(-32767, min(32767, self.left[i] * 32767.0)))
            r = int(max(-32767, min(32767, self.right[i] * 32767.0)))
            raw_shorts.append(l)
            raw_shorts.append(r)
        with wave.open(filepath, 'w') as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(self.sr)
            wf.writeframes(raw_shorts.tobytes())
        print(f"Exported {filepath}: {self.total_duration:.2f}s")


# =====================================================================
# TRACK 1: Town Friendly Breeze (Town / Village Theme - 110 BPM, F Major)
# =====================================================================
def compose_town_theme():
    """Lively village & town square theme: Accordion, flute, marimba, bouncy bass."""
    mixer = ScoreMixer(bpm=110, total_bars=24)
    # MIDI constants in F Major
    F2, C3, D3, E3, F3, G3, A3, Bb3, C4, D4, E4, F4, G4, A4, Bb4, C5, D5, E5, F5, G5, A5, Bb5, C6 = (
        41, 48, 50, 52, 53, 55, 57, 58, 60, 62, 64, 65, 67, 69, 70, 72, 74, 76, 77, 79, 81, 82, 84
    )
    D6, E6, F6, G6 = 86, 88, 89, 91

    # Shaker & Woodblocks
    for bar in range(24):
        for b in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]:
            mixer.add_shaker(bar, b, volume=0.14 if b in [1.0, 3.0] else 0.09, pan=0.25)
        if bar % 2 == 1:
            mixer.add_note(bar, 1.5, 'woodblock', 77, 0.2, volume=0.20, pan=-0.3)
            mixer.add_note(bar, 3.5, 'woodblock', 74, 0.2, volume=0.18, pan=-0.3)

    # Chords (F - C - Dm - Bb, F - C - Bb - C)
    town_chords = [
        # Intro (0..3)
        (F3, [A3, C4, F4], F2, C3), (C4, [G3, C4, E4], C3, G3), (Bb3, [D4, F4, Bb4], Bb3-12, F3), (C4, [G3, C4, E4], C3, G3),
        # Section 1 (4..11)
        (F3, [A3, C4, F4], F2, C3), (C4, [G3, C4, E4], C3, G3), (D3, [F3, A3, D4], D3, A3), (Bb3, [D4, F4, Bb4], Bb3-12, F3),
        (F3, [A3, C4, F4], F2, C3), (C4, [G3, C4, E4], C3, G3), (Bb3, [D4, F4, Bb4], Bb3-12, F3), (C4, [G3, C4, E4], C3, G3),
        # Section 2 (12..19 - Cheerful Festival)
        (Bb3, [D4, F4, Bb4], Bb3-12, F3), (C4, [G3, C4, E4], C3, G3), (A3, [C4, E4, A4], A3-12, E3), (D3, [F3, A3, D4], D3, A3),
        (Bb3, [D4, F4, Bb4], Bb3-12, F3), (C4, [G3, C4, E4], C3, G3), (F3, [A3, C4, F4], F2, C3), (C4, [G3, Bb3, E4], C3, G3),
        # Outro loop (20..23)
        (Bb3, [D4, F4, Bb4], Bb3-12, F3), (C4, [G3, C4, E4], C3, G3), (F3, [A3, C4, F4], F2, C3), (C4, [G3, C4, E4], C3, G3),
    ]

    for bar, (g_root, g_notes, b_root, b_fifth) in enumerate(town_chords):
        # Bouncy guitar strumming
        mixer.add_note(bar, 0.0, 'guitar', g_root, 1.2, volume=0.55, pan=-0.25)
        mixer.add_note(bar, 1.0, 'guitar', g_notes[0], 0.8, volume=0.48, pan=-0.2)
        mixer.add_note(bar, 1.5, 'guitar', g_notes[1], 0.8, volume=0.45, pan=-0.25)
        mixer.add_note(bar, 2.0, 'guitar', g_notes[2], 1.0, volume=0.50, pan=-0.2)
        mixer.add_note(bar, 3.0, 'guitar', g_notes[1], 0.8, volume=0.45, pan=-0.25)
        # Upright bass walk
        mixer.add_note(bar, 0.0, 'bass', b_root, 1.0, volume=0.68, pan=0.0)
        mixer.add_note(bar, 2.0, 'bass', b_fifth, 0.9, volume=0.60, pan=0.0)
        mixer.add_note(bar, 3.5, 'bass', b_root, 0.5, volume=0.50, pan=0.0)

    # Accordion warm pad swells (bars 4..19)
    for bar in range(4, 20):
        chord_data = town_chords[bar][1]
        for note in chord_data:
            mixer.add_note(bar, 0.0, 'accordion', note, 3.8, volume=0.28, pan=0.22)

    # Flute Main Melody (Bars 4..19)
    flute_melody = [
        # Bar 4 (F): A4 - C5 - F5
        (4, 0.0, A4, 1.0), (4, 1.0, C5, 1.0), (4, 2.0, F5, 1.5), (4, 3.5, E5, 0.5),
        # Bar 5 (C): G5 - E5
        (5, 0.0, G5, 2.0), (5, 2.0, E5, 1.0), (5, 3.0, C5, 1.0),
        # Bar 6 (Dm): D5 - F5 - A5
        (6, 0.0, D5, 1.0), (6, 1.0, F5, 1.0), (6, 2.0, A5, 2.0),
        # Bar 7 (Bb): G5 - F5
        (7, 0.0, G5, 1.5), (7, 1.5, F5, 0.5), (7, 2.0, D5, 2.0),
        # Bar 8 (F): C5 - D5 - F5
        (8, 0.0, C5, 1.0), (8, 1.0, D5, 1.0), (8, 2.0, F5, 1.5), (8, 3.5, G5, 0.5),
        # Bar 9 (C): A5 - G5
        (9, 0.0, A5, 2.0), (9, 2.0, G5, 2.0),
        # Bar 10 (Bb): F5 - G5 - F5 - D5
        (10, 0.0, F5, 1.0), (10, 1.0, G5, 1.0), (10, 2.0, F5, 1.0), (10, 3.0, D5, 1.0),
        # Bar 11 (C): C5 sustained
        (11, 0.0, C5, 3.5),
        # Section 2 (Festival / Happy)
        # Bar 12 (Bb): D5 - F5 - Bb5
        (12, 0.0, D5, 1.0), (12, 1.0, F5, 1.0), (12, 2.0, Bb5, 1.5), (12, 3.5, A5, 0.5),
        # Bar 13 (C): G5 - C6
        (13, 0.0, G5, 2.0), (13, 2.0, C6, 2.0),
        # Bar 14 (Am): A5 - C6 - E6
        (14, 0.0, A5, 1.5), (14, 1.5, G5, 0.5), (14, 2.0, F5, 1.0), (14, 3.0, E5, 1.0),
        # Bar 15 (Dm): D5
        (15, 0.0, D5, 3.0),
        # Bar 16 (Bb): F5 - A5 - D6
        (16, 0.0, F5, 1.0), (16, 1.0, A5, 1.0), (16, 2.0, D6, 1.5), (16, 3.5, C6, 0.5),
        # Bar 17 (C): Bb5 - G5 - C6
        (17, 0.0, Bb5, 1.5), (17, 1.5, A5, 0.5), (17, 2.0, G5, 2.0),
        # Bar 18 (F): F5 sustained with joyful trill
        (18, 0.0, F5, 3.0),
        # Bar 19 (C): G5
        (19, 0.0, G5, 3.0),
    ]
    for bar, beat, note, dur in flute_melody:
        mixer.add_note(bar, beat, 'flute', note, dur, volume=0.52, pan=-0.05)

    # Marimba accents (playful counter-melody)
    marimba_hits = [
        (4, 2.5, C6), (4, 3.0, A5), (6, 2.5, F5), (6, 3.0, D5),
        (8, 2.5, A5), (8, 3.0, F5), (10, 2.5, D5), (10, 3.0, C5),
        (12, 1.5, Bb5), (12, 2.5, D6), (14, 1.5, A5), (14, 2.5, C6),
        (16, 1.5, D6), (16, 2.5, F6 if 'F6' in locals() else 89), (18, 1.5, C6), (18, 2.5, A5),
        (20, 1.0, F5), (20, 2.0, A5), (21, 1.0, G5), (21, 2.0, C6), (22, 1.0, F5)
    ]
    for bar, beat, note in marimba_hits:
        mixer.add_note(bar, beat, 'marimba', note, 0.4, volume=0.45, pan=0.3)

    mixer.apply_reverb_and_limiter()
    target = os.path.abspath("assets/audio/music/town_friendly_breeze.wav")
    mixer.save_wav(target)
    return target


# =====================================================================
# TRACK 2: Deep Forest Enchanted (Mystic Woods / Nature - 90 BPM, D Dorian)
# =====================================================================
def compose_deep_forest_theme():
    """Mystical, peaceful forest theme: Rhodes, Kalimba bell, wooden flute, ambient bass."""
    mixer = ScoreMixer(bpm=90, total_bars=24)
    C3, D3, E3, F3, G3, A3, B3, C4, D4, E4, F4, G4, A4, B4, C5, D5, E5, F5, G5, A5, B5, C6, D6 = (
        48, 50, 52, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84, 86
    )

    # Chords (Dm9 - G6 - Dm9 - Am7, Bbmaj7 - C - Dm)
    forest_chords = [
        # Intro
        (D3, [F3, A3, C4, E4], D3-12), (G3, [B3, D4, G4], G3-12),
        (D3, [F3, A3, C4, E4], D3-12), (A3, [C4, E4, G4], A3-12),
        # Theme 1
        (D3, [F3, A3, C4, E4], D3-12), (G3, [B3, D4, G4], G3-12),
        (D3, [F3, A3, C4, E4], D3-12), (A3, [C4, E4, G4], A3-12),
        (D3, [F3, A3, C4, E4], D3-12), (G3, [B3, D4, G4], G3-12),
        (58-12, [D4, F4, A4], 58-24),  (C4, [E4, G4, C5], C3), # Bbmaj7 - C
        # Theme 2 (Emotional deep woods)
        (58-12, [D4, F4, A4], 58-24),  (C4, [E4, G4, C5], C3),
        (D3, [F3, A3, C4, E4], D3-12), (A3, [C4, E4, G4], A3-12),
        (58-12, [D4, F4, A4], 58-24),  (C4, [E4, G4, C5], C3),
        (D3, [F3, A3, C4, E4], D3-12), (D3, [F3, A3, D4], D3-12),
        # Outro loop
        (58-12, [D4, F4, A4], 58-24),  (C4, [E4, G4, C5], C3),
        (D3, [F3, A3, C4, E4], D3-12), (D3, [F3, A3, D4], D3-12),
    ]

    for bar, (root, notes, b_root) in enumerate(forest_chords):
        # Deep warm bass
        mixer.add_note(bar, 0.0, 'bass', b_root, 3.5, volume=0.65, pan=0.0)
        # Lush Rhodes chords
        for n in notes:
            mixer.add_note(bar, 0.0, 'rhodes', n, 3.8, volume=0.34, pan=0.15)
            mixer.add_note(bar, 2.0, 'rhodes', n, 1.8, volume=0.22, pan=0.15)

    # Twinkling Kalimba / Bell (Forest Spirits)
    forest_bells = [
        (1, 1.0, A5), (1, 2.5, D6), (3, 1.0, G5), (3, 2.5, C6),
        (5, 1.0, E5), (5, 2.5, A5), (7, 1.0, G5), (7, 2.5, B5),
        (9, 1.0, F5), (9, 2.5, D6), (11, 1.0, E5), (11, 2.5, C6),
        (13, 1.0, D5), (13, 2.5, F5), (15, 1.0, A5), (15, 2.5, D6),
        (17, 1.0, F5), (17, 2.5, C6), (19, 1.0, D6), (19, 2.0, A5), (19, 3.0, F5),
        (21, 1.0, E5), (21, 2.5, G5), (22, 1.0, A5), (22, 2.0, D6), (23, 1.0, F5)
    ]
    for bar, beat, note in forest_bells:
        mixer.add_note(bar, beat, 'bell', note, 1.5, volume=0.38, pan=0.32)

    # Flute mysterious ocarina theme (Bars 4..19)
    forest_flute = [
        # Bar 4 (Dm): D5 - E5 - F5 - A5
        (4, 0.0, D5, 1.5), (4, 1.5, E5, 0.5), (4, 2.0, F5, 1.5), (4, 3.5, A5, 0.5),
        # Bar 5 (G): B5 - G5
        (5, 0.0, B5, 2.5), (5, 3.0, G5, 1.0),
        # Bar 6 (Dm): A5 - F5 - E5 - D5
        (6, 0.0, A5, 2.0), (6, 2.0, F5, 1.0), (6, 3.0, E5, 1.0),
        # Bar 7 (Am): D5 - C5
        (7, 0.0, D5, 1.5), (7, 1.5, C5, 2.5),
        # Bar 8 (Dm): D5 - F5 - A5 - C6
        (8, 0.0, D5, 1.0), (8, 1.0, F5, 1.0), (8, 2.0, A5, 1.5), (8, 3.5, C6, 0.5),
        # Bar 9 (G): B5 - D6
        (9, 0.0, B5, 2.0), (9, 2.0, D6, 2.0),
        # Bar 10 (Bb): C6 - A5 - F5
        (10, 0.0, C6, 2.0), (10, 2.0, A5, 1.0), (10, 3.0, F5, 1.0),
        # Bar 11 (C): G5 sustained
        (11, 0.0, G5, 3.5),
        # Section 2 (Deep Ancient Canopy)
        # Bar 12 (Bb): D6 - C6 - A5
        (12, 0.0, D6, 2.0), (12, 2.0, C6, 1.0), (12, 3.0, A5, 1.0),
        # Bar 13 (C): G5 - E5
        (13, 0.0, G5, 2.0), (13, 2.0, E5, 2.0),
        # Bar 14 (Dm): F5 - A5 - D6
        (14, 0.0, F5, 1.5), (14, 1.5, A5, 0.5), (14, 2.0, D6, 2.0),
        # Bar 15 (Am): C6
        (15, 0.0, C6, 3.5),
        # Bar 16 (Bb): Bb5 - A5 - F5
        (16, 0.0, 82, 2.0), (16, 2.0, A5, 1.0), (16, 3.0, F5, 1.0),
        # Bar 17 (C): G5 - E5 - C5
        (17, 0.0, G5, 2.0), (17, 2.0, E5, 1.0), (17, 3.0, C5, 1.0),
        # Bar 18 (Dm): D5
        (18, 0.0, D5, 3.5),
        # Bar 19 (Dm)
        (19, 0.0, D5, 3.0),
    ]
    for bar, beat, note, dur in forest_flute:
        mixer.add_note(bar, beat, 'flute', note, dur, volume=0.50, pan=-0.08)

    mixer.apply_reverb_and_limiter(wet_mix=0.28, feedback=0.45)
    target = os.path.abspath("assets/audio/music/deep_forest_enchanted.wav")
    mixer.save_wav(target)
    return target


# =====================================================================
# TRACK 3: Cozy Shop & Warung (Market / Blacksmith / Shop - 106 BPM, G Major)
# =====================================================================
def compose_shop_warung_theme():
    """Charming, quirky, ragtime acoustic & pizzicato merchant theme."""
    mixer = ScoreMixer(bpm=106, total_bars=24)
    G2, B2, C3, D3, E3, Fs3, G3, A3, B3, C4, D4, E4, Fs4, G4, A4, B4, C5, D5, E5, Fs5, G5, A5, B5 = (
        43, 47, 48, 50, 52, 54, 55, 57, 59, 60, 62, 64, 66, 67, 69, 71, 72, 74, 76, 78, 79, 81, 83
    )
    A2 = 45
    C6, D6, E6 = 84, 86, 88

    # Shaker & Woodblock rhythm
    for bar in range(24):
        mixer.add_shaker(bar, 1.0, volume=0.15, pan=0.2)
        mixer.add_shaker(bar, 3.0, volume=0.15, pan=0.2)
        if bar % 2 == 0:
            mixer.add_note(bar, 0.5, 'woodblock', 79, 0.2, volume=0.18, pan=-0.25)
            mixer.add_note(bar, 2.5, 'woodblock', 74, 0.2, volume=0.18, pan=-0.25)

    # Chords (G - E7 - Am7 - D7, G - Bm7 - C - D7)
    shop_chords = [
        # Intro
        (G3, [B3, D4, G4], G2, D3), (52, [56, B3, E4], 52-12, B2), (A3, [C4, E4, A4], A3-12, E3), (D3, [Fs4, A4, D5], D3, A3),
        # Theme 1
        (G3, [B3, D4, G4], G2, D3), (52, [56, B3, E4], 52-12, B2), (A3, [C4, E4, A4], A3-12, E3), (D3, [Fs4, A4, D5], D3, A3),
        (G3, [B3, D4, G4], G2, D3), (B3-12, [D4, Fs4, B4], B2, Fs3), (C3, [E4, G4, C5], C3, G3), (D3, [Fs4, A4, D5], D3, A3),
        # Theme 2 (Playful Merchant)
        (C3, [E4, G4, C5], C3, G3), (D3, [Fs4, A4, D5], D3, A3), (B3-12, [D4, Fs4, B4], B2, Fs3), (E3, [G4, B4, E5], E3, B3),
        (A3-12, [C4, E4, A4], A2, E3), (D3, [Fs4, A4, D5], D3, A3), (G3, [B3, D4, G4], G2, D3), (D3, [Fs4, A4, C5], D3, A3),
        # Outro loop
        (C3, [E4, G4, C5], C3, G3), (D3, [Fs4, A4, D5], D3, A3), (G3, [B3, D4, G4], G2, D3), (D3, [Fs4, A4, D5], D3, A3),
    ]

    for bar, (g_root, g_notes, b_root, b_fifth) in enumerate(shop_chords):
        # Ragtime walking bass
        mixer.add_note(bar, 0.0, 'bass', b_root, 0.8, volume=0.70, pan=0.0)
        mixer.add_note(bar, 2.0, 'bass', b_fifth, 0.8, volume=0.62, pan=0.0)
        # Strumming guitar offbeats (oom-pah)
        mixer.add_note(bar, 1.0, 'guitar', g_notes[0], 0.6, volume=0.55, pan=-0.2)
        mixer.add_note(bar, 1.0, 'guitar', g_notes[1], 0.6, volume=0.52, pan=-0.25)
        mixer.add_note(bar, 3.0, 'guitar', g_notes[1], 0.6, volume=0.55, pan=-0.2)
        mixer.add_note(bar, 3.0, 'guitar', g_notes[2], 0.6, volume=0.52, pan=-0.25)

    # Pizzicato String Plucks (cheeky accents)
    for bar in range(4, 20):
        if bar % 2 == 1:
            mixer.add_note(bar, 0.5, 'pizzicato', G4, 0.4, volume=0.52, pan=0.25)
            mixer.add_note(bar, 1.5, 'pizzicato', B4, 0.4, volume=0.52, pan=0.25)
            mixer.add_note(bar, 2.5, 'pizzicato', D5, 0.4, volume=0.55, pan=0.25)

    # Marimba Main Lead (Bars 4..19 - catchy & bouncy)
    marimba_theme = [
        # Bar 4 (G): D5 - E5 - G5 - B5
        (4, 0.0, D5, 0.5), (4, 0.5, E5, 0.5), (4, 1.0, G5, 1.0), (4, 2.0, B5, 1.5), (4, 3.5, A5, 0.5),
        # Bar 5 (E7): G#5 - E5
        (5, 0.0, 80, 1.5), (5, 1.5, B5, 0.5), (5, 2.0, E5, 2.0), # 80 = G#5
        # Bar 6 (Am): C5 - D5 - E5 - A5
        (6, 0.0, C5, 0.5), (6, 0.5, D5, 0.5), (6, 1.0, E5, 1.0), (6, 2.0, A5, 1.5), (6, 3.5, G5, 0.5),
        # Bar 7 (D7): F#5 - D5
        (7, 0.0, Fs5, 1.5), (7, 1.5, A5, 0.5), (7, 2.0, D5, 2.0),
        # Bar 8 (G): B4 - D5 - G5 - A5
        (8, 0.0, B4, 0.5), (8, 0.5, D5, 0.5), (8, 1.0, G5, 1.0), (8, 2.0, A5, 1.5), (8, 3.5, B5, 0.5),
        # Bar 9 (Bm): D6 - B5
        (9, 0.0, D6, 2.0), (9, 2.0, B5, 2.0),
        # Bar 10 (C): C6 - B5 - A5 - G5
        (10, 0.0, C6, 1.0), (10, 1.0, B5, 1.0), (10, 2.0, A5, 1.0), (10, 3.0, G5, 1.0),
        # Bar 11 (D7): A5 sustained
        (11, 0.0, A5, 3.0),
        # Section 2 (Bustling Counter)
        (12, 0.0, E5, 1.0), (12, 1.0, G5, 1.0), (12, 2.0, C6, 2.0),
        (13, 0.0, Fs5, 1.0), (13, 1.0, A5, 1.0), (13, 2.0, D6, 2.0),
        (14, 0.0, D5, 1.0), (14, 1.0, Fs5, 1.0), (14, 2.0, B5, 2.0),
        (15, 0.0, E5, 1.0), (15, 1.0, G5, 1.0), (15, 2.0, B5, 2.0),
        (16, 0.0, C5, 1.0), (16, 1.0, E5, 1.0), (16, 2.0, A5, 2.0),
        (17, 0.0, D5, 1.0), (17, 1.0, Fs5, 1.0), (17, 2.0, C6, 1.0), (17, 3.0, B5, 1.0),
        (18, 0.0, G5, 3.0),
        (19, 0.0, D5, 3.0),
    ]
    for bar, beat, note, dur in marimba_theme:
        mixer.add_note(bar, beat, 'marimba', note, dur, volume=0.55, pan=-0.05)

    mixer.apply_reverb_and_limiter()
    target = os.path.abspath("assets/audio/music/cozy_shop_warung.wav")
    mixer.save_wav(target)
    return target


# =====================================================================
# TRACK 4: Rainy Day Solitude (Rainy Farm / Melancholy Cozy - 76 BPM, C Major)
# =====================================================================
def compose_rainy_day_theme():
    """Peaceful rainy day retreat: Soft piano, nylon acoustic guitar, breathy flute."""
    mixer = ScoreMixer(bpm=76, total_bars=24)
    C3, D3, E3, F3, G3, A3, B3, C4, D4, E4, F4, G4, A4, B4, C5, D5, E5, F5, G5, A5, B5, C6 = (
        48, 50, 52, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84
    )
    D6, E6, G6 = 86, 88, 91

    # Chords (Am - Fmaj7 - C - G, Dm7 - Em7 - Fmaj7 - Gsus4)
    rain_chords = [
        # Intro
        (A3-12, [C4, E4, A4], A3-24), (F3, [C4, F4, A4], F3-12),
        (C3, [G3, C4, E4], C3-12),    (G3, [B3, D4, G4], G3-12),
        # Theme 1
        (A3-12, [C4, E4, A4], A3-24), (F3, [C4, F4, A4], F3-12),
        (C3, [G3, C4, E4], C3-12),    (G3, [B3, D4, G4], G3-12),
        (A3-12, [C4, E4, A4], A3-24), (F3, [C4, F4, A4], F3-12),
        (D3, [F3, A3, C4], D3-12),    (G3, [C4, D4, G4], G3-12),
        # Theme 2 (Tender warmth)
        (F3, [A3, C4, E4], F3-12),    (G3, [B3, D4, G4], G3-12),
        (E3, [G3, B3, E4], E3-12),    (A3-12, [C4, E4, A4], A3-24),
        (D3, [F3, A3, C4], D3-12),    (G3, [B3, D4, F4], G3-12),
        (C3, [G3, C4, E4], C3-12),    (C3, [G3, C4, E4], C3-12),
        # Outro loop
        (F3, [A3, C4, E4], F3-12),    (G3, [B3, D4, G4], G3-12),
        (C3, [G3, C4, E4], C3-12),    (C3, [G3, C4, E4], C3-12),
    ]

    for bar, (root, notes, b_root) in enumerate(rain_chords):
        # Soft deep bass
        mixer.add_note(bar, 0.0, 'bass', b_root, 3.8, volume=0.55, pan=0.0)
        # Upright piano gentle arpeggio
        mixer.add_note(bar, 0.0, 'piano', root, 3.0, volume=0.52, pan=-0.2)
        mixer.add_note(bar, 1.0, 'piano', notes[0], 2.0, volume=0.45, pan=-0.15)
        mixer.add_note(bar, 2.0, 'piano', notes[1], 2.5, volume=0.48, pan=-0.2)
        mixer.add_note(bar, 3.0, 'piano', notes[2], 2.0, volume=0.42, pan=-0.15)
        # Nylon guitar delicate echoes
        mixer.add_note(bar, 1.5, 'guitar', notes[1], 1.5, volume=0.38, pan=0.25)
        mixer.add_note(bar, 2.5, 'guitar', notes[2], 1.5, volume=0.40, pan=0.25)

    # Flute tender, melancholic melody (Bars 4..19)
    rain_flute = [
        # Bar 4 (Am): E5 - G5 - A5
        (4, 0.0, E5, 2.0), (4, 2.0, G5, 1.0), (4, 3.0, A5, 1.0),
        # Bar 5 (F): C6 - B5 - A5
        (5, 0.0, C6, 2.5), (5, 2.5, B5, 0.5), (5, 3.0, A5, 1.0),
        # Bar 6 (C): G5 - E5
        (6, 0.0, G5, 2.5), (6, 3.0, E5, 1.0),
        # Bar 7 (G): D5
        (7, 0.0, D5, 3.5),
        # Bar 8 (Am): C5 - D5 - E5 - G5
        (8, 0.0, C5, 1.5), (8, 1.5, D5, 0.5), (8, 2.0, E5, 1.5), (8, 3.5, G5, 0.5),
        # Bar 9 (F): A5 - C6
        (9, 0.0, A5, 2.0), (9, 2.0, C6, 2.0),
        # Bar 10 (Dm): F5 - A5 - D6
        (10, 0.0, F5, 1.5), (10, 1.5, A5, 0.5), (10, 2.0, D6, 2.0),
        # Bar 11 (Gsus): G5 sustained
        (11, 0.0, G5, 3.5),
        # Section 2 (Warm Nostalgia)
        # Bar 12 (F): A5 - C6 - E6
        (12, 0.0, A5, 1.5), (12, 1.5, C6, 0.5), (12, 2.0, E6, 2.0),
        # Bar 13 (G): D6 - B5
        (13, 0.0, D6, 2.0), (13, 2.0, B5, 2.0),
        # Bar 14 (Em): G5 - B5 - E6
        (14, 0.0, G5, 1.5), (14, 1.5, B5, 0.5), (14, 2.0, E6, 2.0),
        # Bar 15 (Am): C6
        (15, 0.0, C6, 3.5),
        # Bar 16 (Dm): D6 - C6 - A5
        (16, 0.0, D6, 2.0), (16, 2.0, C6, 1.0), (16, 3.0, A5, 1.0),
        # Bar 17 (G7): B5 - G5
        (17, 0.0, B5, 2.0), (17, 2.0, G5, 2.0),
        # Bar 18 (C): C6
        (18, 0.0, C6, 3.5),
        # Bar 19 (C)
        (19, 0.0, C6, 3.0),
    ]
    for bar, beat, note, dur in rain_flute:
        mixer.add_note(bar, beat, 'flute', note, dur, volume=0.48, pan=-0.05)

    # Ambient soft bell chimes (raindrops falling)
    rain_drops = [
        (1, 2.0, E6), (3, 1.5, G6 if 'G6' in locals() else 91),
        (5, 2.0, C6), (7, 1.5, D6),
        (9, 2.0, E6), (11, 1.5, G5),
        (13, 2.0, B5), (15, 1.5, C6),
        (17, 2.0, D6), (19, 1.5, C6),
        (21, 2.0, E6), (23, 1.5, C6)
    ]
    for bar, beat, note in rain_drops:
        mixer.add_note(bar, beat, 'bell', note, 1.0, volume=0.25, pan=0.35)

    mixer.apply_reverb_and_limiter(wet_mix=0.26, feedback=0.42)
    target = os.path.abspath("assets/audio/music/rainy_day_solitude.wav")
    mixer.save_wav(target)
    return target


if __name__ == '__main__':
    print("=== Composing Nusa Vale Extended BGM Suite ===")
    t1 = compose_town_theme()
    print("Town Theme finished:", t1)
    t2 = compose_deep_forest_theme()
    print("Deep Forest Theme finished:", t2)
    t3 = compose_shop_warung_theme()
    print("Shop/Warung Theme finished:", t3)
    t4 = compose_rainy_day_theme()
    print("Rainy Day Theme finished:", t4)
    print("=== All 4 Extended BGM Tracks Created Successfully! ===")
