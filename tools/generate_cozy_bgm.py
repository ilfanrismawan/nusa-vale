"""
Nusa Vale - Cozy Background Music Generator
Style: Stardew Valley & Harvest Moon (Acoustic Guitar, Flute, Marimba, Rhodes, Upright Bass)
Outputs a clean 16-bit 44.1kHz stereo WAV file.
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

class CozySynth:
    def __init__(self, sample_rate=44100):
        self.sr = sample_rate

    def render_guitar_pluck(self, midi_note, duration, volume=0.7):
        """Karplus-Strong plucked acoustic string with wooden warmth."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        period = int(self.sr / freq)
        if period < 2:
            return out
        
        # Initial excitation: triangular pluck with softened noise
        buf = [0.0] * period
        for i in range(period):
            t = i / period
            # Pluck shape (soft triangle) + light random noise
            tri = (2.0 * t if t < 0.5 else 2.0 * (1.0 - t)) - 0.5
            noise = (random.random() * 2.0 - 1.0) * 0.4
            buf[i] = (tri * 0.6 + noise * 0.4)
        
        decay = 0.992 if midi_note < 60 else 0.985
        last_val = 0.0
        buf_idx = 0
        
        # Karplus-Strong loop
        for n in range(total_samples):
            val = 0.5 * (buf[buf_idx] + last_val) * decay
            last_val = buf[buf_idx]
            buf[buf_idx] = val
            buf_idx = (buf_idx + 1) % period
            
            # Smooth fadeout near end to avoid clicks
            fade = 1.0
            if n > total_samples - 200:
                fade = (total_samples - n) / 200.0
            out[n] = val * volume * fade
            
        return out

    def render_marimba(self, midi_note, duration, volume=0.55):
        """Warm wooden marimba/kalimba mallet tone."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        # Marimba has prominent fundamental and ~3.9x overtone that decays quickly
        tau_fund = 0.45
        tau_over = 0.06
        over_ratio = 3.92
        attack_s = 0.003
        attack_samples = int(attack_s * self.sr)
        
        for n in range(total_samples):
            t = n / self.sr
            # Attack envelope
            env_att = (n / attack_samples) if n < attack_samples else 1.0
            
            # Envelopes
            env_fund = math.exp(-t / tau_fund)
            env_over = math.exp(-t / tau_over)
            
            # Sine wave components
            s_fund = math.sin(TWO_PI * freq * t)
            s_over = math.sin(TWO_PI * freq * over_ratio * t)
            # Light click at start
            click = math.exp(-t / 0.005) * 0.2 * (random.random() * 2.0 - 1.0)
            
            sample = (s_fund * 0.8 * env_fund + s_over * 0.35 * env_over + click) * env_att
            
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_flute(self, midi_note, duration, volume=0.5, vibrato_delay=0.15):
        """Soft, warm wooden flute / ocarina with gentle breath and vibrato."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        attack_samples = int(0.045 * self.sr)
        release_samples = int(0.08 * self.sr)
        sustain_samples = max(0, total_samples - attack_samples - release_samples)
        
        vib_rate = 5.2 # Hz
        phase = 0.0
        
        for n in range(total_samples):
            t = n / self.sr
            
            # Envelope
            if n < attack_samples:
                env = (n / attack_samples) ** 1.5
            elif n < attack_samples + sustain_samples:
                env = 1.0
            else:
                rel_idx = n - (attack_samples + sustain_samples)
                env = max(0.0, 1.0 - (rel_idx / release_samples))
            
            # Vibrato
            vib = 0.0
            if t > vibrato_delay:
                vib_amount = min(1.0, (t - vibrato_delay) / 0.25) * 0.009
                vib = math.sin(TWO_PI * vib_rate * t) * vib_amount
            
            current_freq = freq * (1.0 + vib)
            phase += TWO_PI * current_freq / self.sr
            if phase > TWO_PI:
                phase -= TWO_PI
                
            # Flute harmonics: rich fundamental + mellow 2nd & 3rd
            h1 = math.sin(phase)
            h2 = math.sin(phase * 2.0) * 0.22
            h3 = math.sin(phase * 3.0) * 0.09
            
            # Breath noise (low amplitude pinkish/filtered noise)
            breath = (random.random() * 2.0 - 1.0) * 0.03 * env
            
            sample = (h1 + h2 + h3 + breath) * env
            out[n] = sample * volume
        return out

    def render_rhodes(self, midi_note, duration, volume=0.45):
        """Warm electric piano / Rhodes chords."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        for n in range(total_samples):
            t = n / self.sr
            # FM bell tine
            mod_env = math.exp(-t / 0.18) * 1.5
            mod = math.sin(TWO_PI * (freq * 2.0) * t) * mod_env
            carrier = math.sin(TWO_PI * freq * t + mod)
            
            # Warm fundamental body
            body = math.sin(TWO_PI * freq * t) * math.exp(-t / 1.1)
            
            env = math.exp(-t / 0.85)
            sample = (carrier * 0.6 + body * 0.4) * env
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_bass(self, midi_note, duration, volume=0.65):
        """Warm acoustic / upright bass note."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        for n in range(total_samples):
            t = n / self.sr
            # Fundamental sine + 2nd harmonic warmth
            s1 = math.sin(TWO_PI * freq * t)
            s2 = math.sin(TWO_PI * freq * 2.0 * t) * 0.28
            s3 = math.sin(TWO_PI * freq * 3.0 * t) * 0.08
            
            # Attack and decay
            att = min(1.0, n / (0.015 * self.sr))
            decay = math.exp(-t / 0.95)
            sample = (s1 + s2 + s3) * att * decay
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_shaker(self, duration=0.08, volume=0.18):
        """Gentle maraca/shaker stroke."""
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        # Highpass filtered white noise burst
        last_in = 0.0
        last_out = 0.0
        for n in range(total_samples):
            t = n / self.sr
            noise = random.random() * 2.0 - 1.0
            # simple high pass
            hp = noise - last_in + 0.82 * last_out
            last_in = noise
            last_out = hp
            env = math.sin(math.pi * (n / total_samples)) ** 1.3
            out[n] = hp * env * volume
        return out

    def render_woodblock(self, midi_note=76, volume=0.22):
        """Crisp soft woodblock/clave tap."""
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
        
        # Stereo master tracks
        self.left = [0.0] * self.total_samples
        self.right = [0.0] * self.total_samples
        self.synth = CozySynth(sample_rate)

    def add_note(self, start_bar, beat_offset, instrument, note, duration_beats, volume=1.0, pan=0.0):
        """Add instrument note at specific bar and beat offset."""
        start_sec = start_bar * self.bar_dur + beat_offset * self.beat_dur
        start_sample = int(start_sec * self.sr)
        dur_sec = duration_beats * self.beat_dur
        
        if instrument == 'guitar':
            samples = self.synth.render_guitar_pluck(note, dur_sec, volume)
        elif instrument == 'marimba':
            samples = self.synth.render_marimba(note, dur_sec, volume)
        elif instrument == 'flute':
            samples = self.synth.render_flute(note, dur_sec, volume)
        elif instrument == 'rhodes':
            samples = self.synth.render_rhodes(note, dur_sec, volume)
        elif instrument == 'bass':
            samples = self.synth.render_bass(note, dur_sec, volume)
        elif instrument == 'woodblock':
            samples = self.synth.render_woodblock(note, volume)
        else:
            return
            
        pan = max(-1.0, min(1.0, pan))
        # Constant power panning
        angle = (pan + 1.0) * (math.pi / 4.0)
        gain_l = math.cos(angle)
        gain_r = math.sin(angle)
        
        for i, val in enumerate(samples):
            idx = start_sample + i
            if idx >= self.total_samples:
                break
            self.left[idx] += val * gain_l
            self.right[idx] += val * gain_r

    def add_shaker(self, start_bar, beat_offset, volume=0.18, pan=0.15):
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

    def apply_reverb_and_limiter(self):
        """Warm Schroeder-style stereo reverb + master limiter."""
        print("Applying warm stereo ambience and acoustic reverb...")
        # Delays in ms
        delay_times_l = [int(0.029 * self.sr), int(0.037 * self.sr), int(0.043 * self.sr)]
        delay_times_r = [int(0.031 * self.sr), int(0.039 * self.sr), int(0.047 * self.sr)]
        feedback = 0.38
        wet_mix = 0.22
        
        rev_l = [0.0] * self.total_samples
        rev_r = [0.0] * self.total_samples
        
        for dt in delay_times_l:
            for i in range(dt, self.total_samples):
                rev_l[i] += (self.left[i - dt] + rev_l[i - dt] * feedback) / len(delay_times_l)
                
        for dt in delay_times_r:
            for i in range(dt, self.total_samples):
                rev_r[i] += (self.right[i - dt] + rev_r[i - dt] * feedback) / len(delay_times_r)
                
        # Mix dry and wet
        max_peak = 0.0001
        for i in range(self.total_samples):
            self.left[i] = self.left[i] * (1.0 - wet_mix * 0.5) + rev_l[i] * wet_mix
            self.right[i] = self.right[i] * (1.0 - wet_mix * 0.5) + rev_r[i] * wet_mix
            if abs(self.left[i]) > max_peak:
                max_peak = abs(self.left[i])
            if abs(self.right[i]) > max_peak:
                max_peak = abs(self.right[i])
                
        print(f"Max peak before normalization: {max_peak:.3f}")
        # Target peak around 0.88 (-1.1 dB FS)
        norm_factor = 0.88 / max_peak if max_peak > 0 else 1.0
        
        # Soft-knee tanh saturation / limiting
        for i in range(self.total_samples):
            l = self.left[i] * norm_factor
            r = self.right[i] * norm_factor
            # Soft limiting
            self.left[i] = math.tanh(l) if abs(l) > 0.8 else l
            self.right[i] = math.tanh(r) if abs(r) > 0.8 else r

    def save_wav(self, filepath):
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        print(f"Exporting to {filepath}...")
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
        print(f"Success! Duration: {self.total_duration:.2f}s ({len(raw_shorts)//2} stereo frames)")


def compose_cozy_farm_theme():
    # 32 Bars total @ 102 BPM
    mixer = ScoreMixer(bpm=102, total_bars=32)
    
    # MIDI note constants
    # C3=48, G3=55, C4=60, D4=62, E4=64, F4=65, G4=67, A4=69, B4=71, C5=72, D5=74, E5=76, G5=79
    C3, D3, E3, F3, G3, A3, B3 = 48, 50, 52, 53, 55, 57, 59
    C4, D4, E4, F4, G4, A4, B4 = 60, 62, 64, 65, 67, 69, 71
    C5, D5, E5, F5, G5, A5, B5 = 72, 74, 76, 77, 79, 81, 83
    C6, D6, E6, G6 = 84, 86, 88, 91

    # ==========================================
    # 1. PERCUSSION (Subtle shaker & woodblocks)
    # ==========================================
    for bar in range(32):
        # Shakers on 8th notes (gentle cozy groove)
        if bar >= 4:
            for b in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]:
                vol = 0.16 if b in [1.0, 3.0] else 0.10
                mixer.add_shaker(bar, b, volume=vol, pan=0.25)
        # Gentle woodblock syncopations
        if 8 <= bar < 28:
            if bar % 2 == 0:
                mixer.add_note(bar, 1.5, 'woodblock', 77, 0.2, volume=0.18, pan=-0.3)
                mixer.add_note(bar, 3.5, 'woodblock', 72, 0.2, volume=0.15, pan=-0.3)

    # ==========================================
    # 2. GUITAR FINGERPICKING (Warm Foundation)
    # ==========================================
    # Acoustic guitar patterns (Root - Fifth - Octave - Third arpeggio)
    def guitar_pattern(bar, root, chord_notes):
        # 4 beats of gentle arpeggios
        mixer.add_note(bar, 0.0, 'guitar', root, 1.5, volume=0.62, pan=-0.25)
        mixer.add_note(bar, 0.5, 'guitar', chord_notes[0], 0.8, volume=0.48, pan=-0.2)
        mixer.add_note(bar, 1.0, 'guitar', chord_notes[1], 0.8, volume=0.52, pan=-0.25)
        mixer.add_note(bar, 1.5, 'guitar', chord_notes[2], 0.8, volume=0.48, pan=-0.2)
        mixer.add_note(bar, 2.0, 'guitar', root + 7 if root < 55 else root - 5, 1.2, volume=0.58, pan=-0.25)
        mixer.add_note(bar, 2.5, 'guitar', chord_notes[1], 0.8, volume=0.48, pan=-0.2)
        mixer.add_note(bar, 3.0, 'guitar', chord_notes[2], 0.8, volume=0.50, pan=-0.25)
        mixer.add_note(bar, 3.5, 'guitar', chord_notes[0], 0.8, volume=0.45, pan=-0.2)

    Bb3 = 58
    Gs3 = 56
    Bb4 = 70
    Gs5 = 80

    # Chords for 32 bars:
    # 0..3: Intro
    guitar_pattern(0, C3, [G3, C4, E4])
    guitar_pattern(1, F3, [A3, C4, F4])
    guitar_pattern(2, C3, [G3, C4, E4])
    guitar_pattern(3, G3, [B3, D4, G4])

    # 4..11: Section A (Pastoral Morning)
    # C - G/B - Am - Em - F - C/E - Dm7 - G7
    guitar_pattern(4, C3, [G3, C4, E4])
    guitar_pattern(5, B3-12, [G3, B3, D4])
    guitar_pattern(6, A3-12, [E3, A3, C4])
    guitar_pattern(7, E3, [B3, E4, G4])
    guitar_pattern(8, F3, [C4, F4, A4])
    guitar_pattern(9, E3, [G3, C4, E4])
    guitar_pattern(10, D3, [A3, C4, F4])
    guitar_pattern(11, G3, [B3, D4, F4])

    # 12..19: Section B (Royal Road / Japanese Farm Theme: F - G - Em - Am - F - G - C - C7)
    guitar_pattern(12, F3, [C4, E4, A4])
    guitar_pattern(13, G3, [B3, D4, G4])
    guitar_pattern(14, E3, [B3, E4, G4])
    guitar_pattern(15, A3-12, [E3, A3, C4])
    guitar_pattern(16, F3, [C4, E4, A4])
    guitar_pattern(17, G3, [B3, D4, G4])
    guitar_pattern(18, C3, [G3, C4, E4])
    guitar_pattern(19, C3, [G3, Bb3, E4])

    # 20..27: Section C (Afternoon Breeze & Emotional Lift: Dm - G - Em - Am - Dm - E7 - Am - G7)
    guitar_pattern(20, D3, [F3, A3, D4])
    guitar_pattern(21, G3, [B3, D4, G4])
    guitar_pattern(22, E3, [G3, B3, E4])
    guitar_pattern(23, A3-12, [E3, A3, C4])
    guitar_pattern(24, D3, [F3, A3, C4])
    guitar_pattern(25, E3, [Gs3, B3, D4])
    guitar_pattern(26, A3-12, [E3, A3, C4])
    guitar_pattern(27, G3, [C4, D4, G4])

    # 28..31: Outro / Seamless Loop Setup (F - G - C - Gsus4)
    guitar_pattern(28, F3, [C4, F4, A4])
    guitar_pattern(29, G3, [B3, D4, G4])
    guitar_pattern(30, C3, [G3, C4, E4])
    guitar_pattern(31, G3, [C4, D4, G4])

    # ==========================================
    # 3. UPRIGHT BASS (Walking warmth)
    # ==========================================
    def bass_walk(bar, root, fifth, walk1=None, walk2=None):
        mixer.add_note(bar, 0.0, 'bass', root, 1.2, volume=0.72, pan=0.0)
        mixer.add_note(bar, 2.0, 'bass', fifth, 1.0, volume=0.65, pan=0.0)
        if walk1:
            mixer.add_note(bar, 3.0, 'bass', walk1, 0.8, volume=0.58, pan=0.0)
        if walk2:
            mixer.add_note(bar, 3.5, 'bass', walk2, 0.5, volume=0.52, pan=0.0)

    for bar in range(4, 32):
        if bar == 4:  bass_walk(bar, C3, G3, B3-12)
        elif bar == 5:  bass_walk(bar, B3-12, G3, A3-12)
        elif bar == 6:  bass_walk(bar, A3-12, E3, G3-12)
        elif bar == 7:  bass_walk(bar, E3, B3, E3)
        elif bar == 8:  bass_walk(bar, F3, C3, E3)
        elif bar == 9:  bass_walk(bar, E3, G3, D3)
        elif bar == 10: bass_walk(bar, D3, A3, D3)
        elif bar == 11: bass_walk(bar, G3, D3, A3-12, B3-12)
        
        elif bar == 12: bass_walk(bar, F3, C3, E3)
        elif bar == 13: bass_walk(bar, G3, D3, F3)
        elif bar == 14: bass_walk(bar, E3, B3, D3)
        elif bar == 15: bass_walk(bar, A3-12, E3, G3-12)
        elif bar == 16: bass_walk(bar, F3, C3, E3)
        elif bar == 17: bass_walk(bar, G3, D3, B3-12)
        elif bar == 18: bass_walk(bar, C3, G3, Bb3)
        elif bar == 19: bass_walk(bar, C3, G3, A3-12, B3-12)

        elif bar == 20: bass_walk(bar, D3, A3, C3)
        elif bar == 21: bass_walk(bar, G3, D3, F3)
        elif bar == 22: bass_walk(bar, E3, B3, D3)
        elif bar == 23: bass_walk(bar, A3-12, E3, G3-12)
        elif bar == 24: bass_walk(bar, D3, A3, C3)
        elif bar == 25: bass_walk(bar, E3, B3, D3)
        elif bar == 26: bass_walk(bar, A3-12, E3, F3)
        elif bar == 27: bass_walk(bar, G3, D3, F3)

        elif bar == 28: bass_walk(bar, F3, C3, A3-12)
        elif bar == 29: bass_walk(bar, G3, D3, B3-12)
        elif bar == 30: bass_walk(bar, C3, G3, C3)
        elif bar == 31: bass_walk(bar, G3, D3, G3)

    # ==========================================
    # 4. MARIMBA / KALIMBA (Playful Sparkle)
    # ==========================================
    # Intro marimba greeting
    mixer.add_note(0, 2.0, 'marimba', G5, 0.4, volume=0.45, pan=0.3)
    mixer.add_note(0, 2.5, 'marimba', E5, 0.4, volume=0.45, pan=0.3)
    mixer.add_note(0, 3.0, 'marimba', C5, 0.8, volume=0.55, pan=0.3)

    mixer.add_note(1, 2.0, 'marimba', A5, 0.4, volume=0.45, pan=0.3)
    mixer.add_note(1, 2.5, 'marimba', F5, 0.4, volume=0.45, pan=0.3)
    mixer.add_note(1, 3.0, 'marimba', C5, 0.8, volume=0.55, pan=0.3)

    mixer.add_note(2, 2.0, 'marimba', G5, 0.4, volume=0.45, pan=0.3)
    mixer.add_note(2, 2.5, 'marimba', E5, 0.4, volume=0.45, pan=0.3)
    mixer.add_note(2, 3.0, 'marimba', G5, 0.6, volume=0.50, pan=0.3)
    mixer.add_note(2, 3.5, 'marimba', C6, 0.8, volume=0.60, pan=0.3)

    mixer.add_note(3, 1.0, 'marimba', B5, 0.5, volume=0.50, pan=0.3)
    mixer.add_note(3, 2.0, 'marimba', G5, 0.5, volume=0.50, pan=0.3)
    mixer.add_note(3, 3.0, 'marimba', D5, 1.0, volume=0.55, pan=0.3)

    # Marimba accents during Section A (sweet echoes)
    marimba_motifs = [
        (5, 2.5, [G5, E5, D5]),
        (7, 2.5, [E5, G5, B5]),
        (9, 2.5, [C5, E5, G5]),
        (11, 2.0, [F5, D5, B4, G4]),
    ]
    for bar, start_beat, notes in marimba_motifs:
        for idx, n in enumerate(notes):
            mixer.add_note(bar, start_beat + idx * 0.5, 'marimba', n, 0.45, volume=0.52, pan=0.28)

    # Section B Marimba playful arpeggios (syncopated joyful bounce!)
    for b_idx, bar in enumerate(range(12, 20)):
        if b_idx % 2 == 0:
            mixer.add_note(bar, 0.5, 'marimba', C5, 0.3, volume=0.42, pan=0.32)
            mixer.add_note(bar, 1.5, 'marimba', E5, 0.3, volume=0.45, pan=0.32)
            mixer.add_note(bar, 2.5, 'marimba', G5, 0.3, volume=0.48, pan=0.32)
            mixer.add_note(bar, 3.5, 'marimba', C6, 0.4, volume=0.52, pan=0.32)
        else:
            mixer.add_note(bar, 0.5, 'marimba', B5, 0.3, volume=0.42, pan=0.32)
            mixer.add_note(bar, 1.5, 'marimba', G5, 0.3, volume=0.45, pan=0.32)
            mixer.add_note(bar, 2.5, 'marimba', D5, 0.4, volume=0.48, pan=0.32)

    # ==========================================
    # 5. FLUTE / OCARINA (Main Melody)
    # ==========================================
    # Theme A Melody: "Breeze of Nusa Vale" (Bars 4..11)
    # Heartwarming, nostalgic, lyrical
    flute_theme_a = [
        # Bar 4 (C): C5 - D5 - E5 - G5
        (4, 0.0, E5, 1.5), (4, 1.5, G5, 1.0), (4, 2.5, A5, 0.5), (4, 3.0, G5, 1.0),
        # Bar 5 (G/B): E5 - D5 - C5
        (5, 0.0, D5, 2.0), (5, 2.0, B4, 1.0), (5, 3.0, C5, 1.0),
        # Bar 6 (Am): C5 - D5 - E5 - A5
        (6, 0.0, C5, 1.5), (6, 1.5, D5, 0.5), (6, 2.0, E5, 1.5), (6, 3.5, A5, 0.8),
        # Bar 7 (Em): G5 - E5
        (7, 0.0, G5, 2.5), (7, 3.0, E5, 1.0),
        # Bar 8 (F): F5 - G5 - A5 - C6
        (8, 0.0, A5, 1.5), (8, 1.5, C6, 1.0), (8, 2.5, B5, 0.5), (8, 3.0, A5, 1.0),
        # Bar 9 (C/E): G5 - E5 - C5
        (9, 0.0, G5, 2.0), (9, 2.0, E5, 1.0), (9, 3.0, C5, 1.0),
        # Bar 10 (Dm7): D5 - F5 - E5 - D5
        (10, 0.0, D5, 1.5), (10, 1.5, E5, 0.5), (10, 2.0, F5, 1.0), (10, 3.0, A5, 1.0),
        # Bar 11 (G7): G5 sustained with sweet vibrato
        (11, 0.0, G5, 3.0),
    ]
    for bar, beat, note, dur in flute_theme_a:
        mixer.add_note(bar, beat, 'flute', note, dur, volume=0.52, pan=-0.05)

    # Theme B Melody: "Village Sunshine" (Bars 12..19)
    # Bright, bouncy, full of life
    flute_theme_b = [
        # Bar 12 (F): A5 - C6 - B5 - A5
        (12, 0.0, C6, 1.5), (12, 1.5, B5, 0.5), (12, 2.0, A5, 1.0), (12, 3.0, G5, 1.0),
        # Bar 13 (G): B5 - G5
        (13, 0.0, B5, 2.0), (13, 2.0, G5, 2.0),
        # Bar 14 (Em): G5 - B5 - A5 - G5
        (14, 0.0, B5, 1.5), (14, 1.5, A5, 0.5), (14, 2.0, G5, 1.0), (14, 3.0, E5, 1.0),
        # Bar 15 (Am): A5 sustained
        (15, 0.0, A5, 3.0),
        # Bar 16 (F): F5 - A5 - C6 - D6
        (16, 0.0, A5, 1.0), (16, 1.0, C6, 1.0), (16, 2.0, D6, 1.5), (16, 3.5, C6, 0.8),
        # Bar 17 (G): B5 - D6 - G5
        (17, 0.0, B5, 2.0), (17, 2.0, G5, 2.0),
        # Bar 18 (C): C6 - E6 - D6 - C6
        (18, 0.0, C6, 2.5), (18, 2.5, D6, 0.5), (18, 3.0, E6, 1.0),
        # Bar 19 (C7): C6
        (19, 0.0, C6, 3.0),
    ]
    for bar, beat, note, dur in flute_theme_b:
        mixer.add_note(bar, beat, 'flute', note, dur, volume=0.54, pan=-0.05)

    # Theme C Melody: "Golden Horizon / Harvest Dream" (Bars 20..27)
    # Nostalgic, heartwarming emotional climax
    flute_theme_c = [
        # Bar 20 (Dm): F5 - A5 - D6
        (20, 0.0, D6, 2.0), (20, 2.0, C6, 1.0), (20, 3.0, A5, 1.0),
        # Bar 21 (G): B5 - G5
        (21, 0.0, B5, 2.0), (21, 2.0, G5, 2.0),
        # Bar 22 (Em): G5 - B5 - E6
        (22, 0.0, E6, 2.0), (22, 2.0, D6, 1.0), (22, 3.0, B5, 1.0),
        # Bar 23 (Am): C6
        (23, 0.0, C6, 3.0),
        # Bar 24 (Dm): D5 - F5 - A5 - C6
        (24, 0.0, A5, 1.5), (24, 1.5, C6, 1.0), (24, 2.5, B5, 0.5), (24, 3.0, A5, 1.0),
        # Bar 25 (E7): G#5 - B5 (emotional high note)
        (25, 0.0, 80, 2.0), (25, 2.0, B5, 2.0), # 80 is G#5
        # Bar 26 (Am): A5 - C6 - E6
        (26, 0.0, A5, 1.5), (26, 1.5, C6, 1.0), (26, 2.5, D6, 0.5), (26, 3.0, E6, 1.0),
        # Bar 27 (G7): D6 - B5 - G5
        (27, 0.0, D6, 2.0), (27, 2.0, G5, 2.0),
    ]
    for bar, beat, note, dur in flute_theme_c:
        mixer.add_note(bar, beat, 'flute', note, dur, volume=0.55, pan=-0.05)

    # Outro / Loop Bridge (Bars 28..31)
    flute_outro = [
        (28, 0.0, C6, 2.0), (28, 2.0, A5, 2.0),
        (29, 0.0, B5, 2.0), (29, 2.0, G5, 2.0),
        (30, 0.0, C6, 3.0),
        (31, 2.0, G5, 1.0), (31, 3.0, E5, 1.0), # Lead-in to bar 0!
    ]
    for bar, beat, note, dur in flute_outro:
        mixer.add_note(bar, beat, 'flute', note, dur, volume=0.48, pan=-0.05)

    # ==========================================
    # 6. RHODES / ELECTRIC PIANO (Lush Harmony)
    # ==========================================
    # Rhodes enters in Section B & C for lush, dreamy warmth
    rhodes_chords = [
        # Section B
        (12, [F4, A4, C5, E5]),
        (13, [G4, B4, D5, F5]),
        (14, [E4, G4, B4, E5]),
        (15, [A4, C5, E5, G5]),
        (16, [F4, A4, C5, E5]),
        (17, [G4, B4, D5, G5]),
        (18, [C4, E4, G4, C5]),
        (19, [C4, E4, 58, C5]), # C7
        # Section C
        (20, [D4, F4, A4, C5]),
        (21, [G4, B4, D5, F5]),
        (22, [E4, G4, B4, D5]),
        (23, [A4, C5, E5, G5]),
        (24, [D4, F4, A4, C5]),
        (25, [E4, 56, B4, D5]), # E7
        (26, [A4, C5, E5, A5]),
        (27, [G4, C5, D5, G5]),
        # Outro
        (28, [F4, A4, C5, E5]),
        (29, [G4, B4, D5, G5]),
        (30, [C4, E4, G4, C5]),
    ]
    for bar, chord in rhodes_chords:
        for n in chord:
            mixer.add_note(bar, 0.0, 'rhodes', n, 3.2, volume=0.32, pan=0.15)
            # Gentle re-hit on beat 2
            mixer.add_note(bar, 2.0, 'rhodes', n, 1.8, volume=0.22, pan=0.15)

    # Final polish: Reverb, Stereo panning, and Master Limiter
    mixer.apply_reverb_and_limiter()
    
    target_path = os.path.abspath("assets/audio/music/spring_cozy_farm.wav")
    mixer.save_wav(target_path)
    return target_path


def compose_night_cozy_theme():
    """Tranquil, starry night & cozy cabin theme (86 BPM)."""
    mixer = ScoreMixer(bpm=86, total_bars=24)
    
    # MIDI constants in G Major
    G2, A2, B2 = 43, 45, 47
    C3, D3, E3, Fs3, G3, A3, B3 = 48, 50, 52, 54, 55, 57, 59
    C4, D4, E4, Fs4, G4, A4, B4 = 60, 62, 64, 66, 67, 69, 71
    C5, D5, E5, Fs5, G5, A5, B5 = 72, 74, 76, 78, 79, 81, 83
    C6, D6, E6, G6 = 84, 86, 88, 91

    def slow_guitar(bar, root, notes):
        mixer.add_note(bar, 0.0, 'guitar', root, 2.0, volume=0.55, pan=-0.25)
        mixer.add_note(bar, 1.0, 'guitar', notes[0], 1.2, volume=0.45, pan=-0.2)
        mixer.add_note(bar, 2.0, 'guitar', notes[1], 1.5, volume=0.48, pan=-0.25)
        mixer.add_note(bar, 3.0, 'guitar', notes[2], 1.2, volume=0.42, pan=-0.2)

    def night_bass(bar, root, fifth=None):
        mixer.add_note(bar, 0.0, 'bass', root, 2.5, volume=0.60, pan=0.0)
        if fifth:
            mixer.add_note(bar, 2.0, 'bass', fifth, 1.8, volume=0.52, pan=0.0)

    # 24 Bars:
    # 0..3: Intro
    # 4..11: Theme 1
    # 12..19: Theme 2 (Warm nostalgia)
    # 20..23: Outro loop
    chords = [
        # Intro
        (G3, [D4, G4, B4], G2, D3),
        (C3, [E4, G4, C5], C3, G3),
        (G3, [D4, G4, B4], G2, D3),
        (D3, [Fs4, A4, D5], D3, A3),
        # Theme 1
        (G3, [D4, G4, B4], G2, D3),
        (C3, [E4, G4, C5], C3, G3),
        (E3, [B3, E4, G4], E3, B3),
        (D3, [Fs4, A4, C5], D3, A3),
        (C3, [G4, C5, E5], C3, G3),
        (G3, [D4, G4, B4], G2, D3),
        (A3-12, [E4, A4, C5], A2, E3),
        (D3, [Fs4, A4, D5], D3, A3),
        # Theme 2
        (E3, [B3, E4, G4], E3, B3),
        (B3-12, [Fs4, B4, D5], B2, Fs3),
        (C3, [E4, G4, C5], C3, G3),
        (G3, [D4, G4, B4], G2, D3),
        (C3, [G4, C5, E5], C3, G3),
        (D3, [Fs4, A4, D5], D3, A3),
        (E3, [G4, B4, E5], E3, B3),
        (D3, [Fs4, A4, C5], D3, A3),
        # Outro
        (C3, [E4, G4, C5], C3, G3),
        (D3, [Fs4, A4, D5], D3, A3),
        (G3, [D4, G4, B4], G2, D3),
        (G3, [D4, G4, D5], G2, D3),
    ]

    for bar, (g_root, g_notes, b_root, b_fifth) in enumerate(chords):
        slow_guitar(bar, g_root, g_notes)
        night_bass(bar, b_root, b_fifth)

    # Rhodes soft bell chords (bars 4..23)
    for bar in range(4, 23):
        chord_data = chords[bar][1]
        for note in chord_data:
            mixer.add_note(bar, 0.5, 'rhodes', note, 3.0, volume=0.28, pan=0.2)

    # Kalimba / Marimba twinkling stars (high register)
    kalimba_stars = [
        (1, 2.0, B5), (1, 3.0, G5),
        (3, 2.0, A5), (3, 3.0, Fs5),
        (5, 1.5, G5), (5, 2.5, B5), (5, 3.5, D6),
        (7, 2.0, A5), (7, 3.0, Fs5),
        (9, 1.5, B5), (9, 2.5, G5),
        (11, 2.0, Fs5), (11, 3.0, D5),
        (13, 2.0, Fs5), (13, 3.0, D5),
        (15, 1.5, G5), (15, 2.5, B5), (15, 3.5, D6),
        (17, 2.0, C6), (17, 3.0, A5),
        (19, 2.0, Fs5), (19, 3.0, D5),
        (21, 2.0, A5), (21, 3.0, Fs5),
        (22, 1.0, G5), (22, 2.0, B5), (22, 3.0, D6),
    ]
    for bar, beat, note in kalimba_stars:
        mixer.add_note(bar, beat, 'marimba', note, 0.8, volume=0.38, pan=0.3)

    # Flute night melody (bars 4..19)
    night_flute = [
        (4, 0.0, B4, 2.5), (4, 3.0, D5, 1.0),
        (5, 0.0, E5, 2.5), (5, 3.0, G5, 1.0),
        (6, 0.0, G5, 3.0),
        (7, 0.0, Fs5, 3.0),
        (8, 0.0, E5, 2.0), (8, 2.0, D5, 1.0), (8, 3.0, C5, 1.0),
        (9, 0.0, B4, 3.0),
        (10, 0.0, C5, 1.5), (10, 1.5, D5, 0.5), (10, 2.0, E5, 1.5), (10, 3.5, C5, 0.5),
        (11, 0.0, D5, 3.5),
        # Section 2
        (12, 0.0, G5, 2.5), (12, 3.0, Fs5, 1.0),
        (13, 0.0, D5, 3.0),
        (14, 0.0, E5, 2.0), (14, 2.0, G5, 1.0), (14, 3.0, B5, 1.0),
        (15, 0.0, B5, 3.0),
        (16, 0.0, C6, 2.0), (16, 2.0, B5, 1.0), (16, 3.0, A5, 1.0),
        (17, 0.0, A5, 2.0), (17, 2.0, B5, 1.0), (17, 3.0, D6, 1.0),
        (18, 0.0, G5, 3.0),
        (19, 0.0, Fs5, 3.0),
    ]
    for bar, beat, note, dur in night_flute:
        mixer.add_note(bar, beat, 'flute', note, dur, volume=0.45, pan=-0.05)

    mixer.apply_reverb_and_limiter()
    target_path = os.path.abspath("assets/audio/music/night_cozy_serenade.wav")
    mixer.save_wav(target_path)
    return target_path


if __name__ == '__main__':
    print("=== Composing Nusa Vale Cozy Background Music ===")
    p1 = compose_cozy_farm_theme()
    print("Spring/Day track ready:", p1)
    p2 = compose_night_cozy_theme()
    print("Night/Interior track ready:", p2)
    print("=== All BGM Composed Successfully! ===")
