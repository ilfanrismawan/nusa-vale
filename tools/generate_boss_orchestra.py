"""
Nusa Vale - Exclusive Orchestral Boss Battle Theme Generator
Style: Epic Dark Fantasy Symphony & Indonesian Mythological Grandeur
(Driving Strings Spiccato, Majestic French Horns, Screaming Trumpets, Thunderous Timpani,
 War Drums, Military Snare, Choir Chants, Tubular Bells & Deep Gong Ageng)

Outputs high-fidelity 16-bit 44.1kHz stereo WAV:
assets/audio/music/boss_exclusive_orchestra.wav
"""

import math
import struct
import wave
import array
import random
import os
import time

SAMPLE_RATE = 44100
TWO_PI = 2.0 * math.pi

def midi_to_freq(midi_note):
    return 440.0 * (2.0 ** ((midi_note - 69.0) / 12.0))

# Note definitions
C1, D1, E1, F1, G1, A1, B1 = 24, 26, 28, 29, 31, 33, 35
C2, Cs2, D2, Eb2, E2, F2, Fs2, G2, Ab2, A2, Bb2, B2 = 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47
C3, Cs3, D3, Eb3, E3, F3, Fs3, G3, Ab3, A3, Bb3, B3 = 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59
C4, Cs4, D4, Eb4, E4, F4, Fs4, G4, Ab4, A4, Bb4, B4 = 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71
C5, Cs5, D5, Eb5, E5, F5, Fs5, G5, Ab5, A5, Bb5, B5 = 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83
C6, Cs6, D6, Eb6, E6, F6, Fs6, G6, Ab6, A6, Bb6, B6 = 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95


class BossOrchestraSynth:
    def __init__(self, sample_rate=SAMPLE_RATE):
        self.sr = sample_rate

    def render_spiccato_string(self, midi_note, duration=0.22, volume=0.7):
        """Crisp, aggressive bowed cello/double-bass spiccato with rosin bite."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        # Rosin attack noise transient
        att_samples = int(0.025 * self.sr)
        p1, p2, p3 = random.random(), random.random(), random.random()
        dp1 = freq / self.sr
        dp2 = (freq * 2.003) / self.sr
        dp3 = (freq * 3.007) / self.sr
        
        # Tight exponential decay for punchy ostinato chug
        decay_rate = 14.0 if duration < 0.25 else 7.5
        
        for n in range(total_samples):
            t = n / self.sr
            # Sawtooth-like bowed harmonics
            p1 = (p1 + dp1) % 1.0
            p2 = (p2 + dp2) % 1.0
            p3 = (p3 + dp3) % 1.0
            
            s1 = (2.0 * p1 - 1.0)
            s2 = (2.0 * p2 - 1.0) * 0.55
            s3 = (2.0 * p3 - 1.0) * 0.35
            
            # Bow scrape friction at onset
            scrape = (random.random() * 2.0 - 1.0) * math.exp(-t * 90.0) * 0.45
            
            # Envelope: fast bite, then sharp exponential decay
            if n < att_samples:
                env = (n / att_samples) ** 0.8
            else:
                env = math.exp(-(t - 0.025) * decay_rate)
            
            val = (s1 + s2 + s3 + scrape) * env * volume
            # Anti-click taper at tail
            if n > total_samples - 80:
                val *= (total_samples - n) / 80.0
            out[n] = val
        return out

    def render_legato_violins(self, midi_note, duration, volume=0.55, vibrato_delay=0.12):
        """Lush, soaring violin ensemble with multi-voice chorusing and natural vibrato."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        att_samples = int(0.045 * self.sr)
        rel_samples = int(0.08 * self.sr)
        
        # 3 ensemble voices with microscopic detune (unison width)
        detunes = [1.0, 1.0022, 0.9978]
        phases = [random.random(), random.random(), random.random()]
        
        for n in range(total_samples):
            t = n / self.sr
            # Vibrato onset
            vib_depth = 0.007 * (1.0 - math.exp(-max(0.0, t - vibrato_delay) * 8.0))
            vib = 1.0 + vib_depth * math.sin(TWO_PI * 5.6 * t)
            
            sample_acc = 0.0
            for v in range(3):
                f_voice = freq * detunes[v] * vib
                phases[v] = (phases[v] + f_voice / self.sr) % 1.0
                p = phases[v]
                # Rich string timbre: Fundamental + 2nd + 3rd + 4th harmonic
                w = math.sin(TWO_PI * p) + 0.5 * math.sin(TWO_PI * 2.0 * p) + 0.25 * math.sin(TWO_PI * 3.0 * p) + 0.12 * math.sin(TWO_PI * 4.0 * p)
                sample_acc += w
            
            sample_acc /= 3.0
            
            # Envelope
            if n < att_samples:
                env = (n / att_samples) ** 1.2
            elif n > total_samples - rel_samples:
                env = (total_samples - n) / rel_samples
            else:
                env = 1.0
                
            out[n] = sample_acc * env * volume
        return out

    def render_french_horn(self, midi_note, duration, volume=0.72, punch=False):
        """Noble, majestic French Horn with characteristic warm brass body and brassy bite."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        att_s = 0.028 if punch else 0.065
        att_samples = int(att_s * self.sr)
        rel_samples = int(0.09 * self.sr)
        
        p = random.random()
        dp = freq / self.sr
        
        for n in range(total_samples):
            t = n / self.sr
            p = (p + dp) % 1.0
            
            # Brass waveshaping: warm asymmetrical sine with harmonic saturation
            s = math.sin(TWO_PI * p)
            # Horn resonance formant emphasis (~450 Hz and ~900 Hz)
            h2 = math.sin(TWO_PI * 2.0 * p) * 0.45
            h3 = math.sin(TWO_PI * 3.0 * p) * 0.28
            h4 = math.sin(TWO_PI * 4.0 * p) * 0.15
            brass_raw = s + h2 + h3 + h4
            
            # Brassy saturation bite
            brass_sound = math.tanh(brass_raw * 1.35)
            
            # Envelope
            if n < att_samples:
                env = (n / att_samples) ** 1.1
            elif n > total_samples - rel_samples:
                env = (total_samples - n) / rel_samples
            else:
                env = 1.0
                
            out[n] = brass_sound * env * volume
        return out

    def render_trumpet(self, midi_note, duration, volume=0.68):
        """Piercing, heroic symphonic trumpet for soaring fanfares and battle calls."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        att_samples = int(0.022 * self.sr)
        rel_samples = int(0.06 * self.sr)
        
        p = random.random()
        dp = freq / self.sr
        
        for n in range(total_samples):
            t = n / self.sr
            p = (p + dp) % 1.0
            
            # Brilliant, bright trumpet overtone series
            w = (math.sin(TWO_PI * p) +
                 0.65 * math.sin(TWO_PI * 2.0 * p) +
                 0.50 * math.sin(TWO_PI * 3.0 * p) +
                 0.38 * math.sin(TWO_PI * 4.0 * p) +
                 0.22 * math.sin(TWO_PI * 5.0 * p))
            
            # Tongue transient
            tongue = (random.random() * 2.0 - 1.0) * math.exp(-t * 120.0) * 0.3
            
            if n < att_samples:
                env = (n / att_samples) ** 0.9
            elif n > total_samples - rel_samples:
                env = (total_samples - n) / rel_samples
            else:
                env = 1.0
                
            out[n] = (w * 0.85 + tongue) * env * volume
        return out

    def render_low_brass(self, midi_note, duration, volume=0.75):
        """Ominous, crushing Tuba / Bass Trombone stabs and foundational pedal notes."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        att_samples = int(0.035 * self.sr)
        rel_samples = int(0.09 * self.sr)
        p = 0.0
        dp = freq / self.sr
        
        for n in range(total_samples):
            t = n / self.sr
            p = (p + dp) % 1.0
            # Heavy saw-tri brass buzz
            saw = (2.0 * p - 1.0)
            sub = math.sin(TWO_PI * p * 0.5) * 0.4
            raw = (saw * 0.7 + sub) * 1.5
            dist = math.tanh(raw)
            
            if n < att_samples:
                env = (n / att_samples) ** 1.0
            elif n > total_samples - rel_samples:
                env = (total_samples - n) / rel_samples
            else:
                env = 1.0
                
            out[n] = dist * env * volume
        return out

    def render_timpani(self, midi_note, duration=0.8, volume=0.85):
        """Thunderous symphonic kettle drum with striking felt mallet and pitch drop."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        p_fund = 0.0
        p_mode2 = 0.0
        p_mode3 = 0.0
        
        for n in range(total_samples):
            t = n / self.sr
            # Striking pitch drop (membrane stretching under mallet hit)
            f_drop = freq * (1.0 + 0.18 * math.exp(-t * 22.0))
            
            p_fund += TWO_PI * f_drop / self.sr
            p_mode2 += TWO_PI * (f_drop * 1.59) / self.sr
            p_mode3 += TWO_PI * (f_drop * 2.14) / self.sr
            
            s1 = math.sin(p_fund) * math.exp(-t * 3.8)
            s2 = math.sin(p_mode2) * math.exp(-t * 7.5) * 0.45
            s3 = math.sin(p_mode3) * math.exp(-t * 11.0) * 0.25
            
            # Mallet impact thump
            impact = (random.random() * 2.0 - 1.0) * math.exp(-t * 80.0) * 0.5
            
            val = (s1 + s2 + s3 + impact) * volume
            if n > total_samples - 100:
                val *= (total_samples - n) / 100.0
            out[n] = val
        return out

    def render_war_drum(self, duration=0.6, volume=0.9):
        """Subterranean Taiko / Gran Cassa war drum hit that rattles the screen."""
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        for n in range(total_samples):
            t = n / self.sr
            # Pitch sweep from 75Hz down to 32Hz
            f = 32.0 + 43.0 * math.exp(-t * 16.0)
            phase = TWO_PI * f * t
            sub = math.sin(phase) * math.exp(-t * 4.2)
            punch = math.sin(TWO_PI * f * 2.0 * t) * math.exp(-t * 14.0) * 0.6
            click = (random.random() * 2.0 - 1.0) * math.exp(-t * 90.0) * 0.4
            
            sample = (sub + punch + click) * volume
            if n > total_samples - 100:
                sample *= (total_samples - n) / 100.0
            out[n] = sample
        return out

    def render_snare(self, duration=0.25, volume=0.55, is_roll=False):
        """Crisp orchestral snare with wire rattle and wooden shell punch."""
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        body_decay = 28.0 if not is_roll else 45.0
        wire_decay = 18.0 if not is_roll else 35.0
        
        for n in range(total_samples):
            t = n / self.sr
            # Drumhead tone (210 Hz)
            body = math.sin(TWO_PI * 210.0 * t) * math.exp(-t * body_decay)
            # Snare wires (highpassed noise)
            noise = (random.random() * 2.0 - 1.0) * math.exp(-t * wire_decay)
            
            sample = (body * 0.45 + noise * 0.65) * volume
            if n > total_samples - 60:
                sample *= (total_samples - n) / 60.0
            out[n] = sample
        return out

    def render_crash_cymbal(self, duration=2.4, volume=0.58):
        """Massive symphonic crash cymbal with shimmering metallic wash."""
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        # Highpass filtered white noise burst with metal pings
        last_val = 0.0
        for n in range(total_samples):
            t = n / self.sr
            noise = random.random() * 2.0 - 1.0
            # Highpass
            hp = noise - last_val + 0.88 * last_val
            last_val = hp
            
            # Metal ringing tones
            pings = (math.sin(TWO_PI * 3420.0 * t) * 0.15 +
                     math.sin(TWO_PI * 5210.0 * t) * 0.12 +
                     math.sin(TWO_PI * 7890.0 * t) * 0.08)
            
            env = math.exp(-t * 2.4)
            sample = (hp * 0.75 + pings) * env * volume
            if n > total_samples - 300:
                sample *= (total_samples - n) / 300.0
            out[n] = sample
        return out

    def render_gong_ageng(self, duration=4.0, volume=0.72):
        """Deep, majestic Indonesian bronze Gong Ageng marking ancient ritual power."""
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        f0 = 68.0 # Deep, grounding bronze fundamental
        for n in range(total_samples):
            t = n / self.sr
            # Om-bak: natural beating amplitude undulation
            ombak = 1.0 + 0.28 * math.sin(TWO_PI * 2.4 * t)
            
            s1 = math.sin(TWO_PI * f0 * t) * math.exp(-t * 0.9)
            s2 = math.sin(TWO_PI * (f0 * 1.98) * t) * math.exp(-t * 1.6) * 0.45
            s3 = math.sin(TWO_PI * (f0 * 2.94) * t) * math.exp(-t * 2.3) * 0.25
            
            # Metallic strike mallet
            mallet = math.sin(TWO_PI * 340.0 * t) * math.exp(-t * 35.0) * 0.35
            
            sample = (s1 * ombak + s2 + s3 + mallet) * volume
            if n > total_samples - 400:
                sample *= (total_samples - n) / 400.0
            out[n] = sample
        return out

    def render_tubular_bell(self, midi_note, duration=3.0, volume=0.55):
        """Cathedral chime / tubular bell marking epic heroic climaxes."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        # Inharmonic partials characteristic of cylindrical bells
        partials = [1.0, 2.76, 5.4, 8.9]
        amps = [0.65, 0.32, 0.18, 0.09]
        decays = [1.2, 2.2, 3.8, 5.5]
        
        for n in range(total_samples):
            t = n / self.sr
            sample = 0.0
            for p_idx in range(len(partials)):
                f_p = freq * partials[p_idx]
                sample += math.sin(TWO_PI * f_p * t) * amps[p_idx] * math.exp(-t * decays[p_idx])
            
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_epic_choir(self, midi_note, duration, volume=0.52, vowel='ah'):
        """Massive gothic choir chanting with multi-formant vowels and ensemble detuning."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        
        # Formants (center Hz)
        if vowel == 'ah':
            f_formants = [720.0, 1180.0, 2600.0]
        else: # 'oh'
            f_formants = [450.0, 820.0, 2400.0]
            
        att_samples = int(0.07 * self.sr)
        rel_samples = int(0.10 * self.sr)
        
        detunes = [1.0, 1.0035, 0.9965]
        phases = [random.random(), random.random(), random.random()]
        
        for n in range(total_samples):
            t = n / self.sr
            # Natural choral vibrato
            vib = 1.0 + 0.006 * math.sin(TWO_PI * 5.2 * t)
            
            acc = 0.0
            for v in range(3):
                f_v = freq * detunes[v] * vib
                phases[v] = (phases[v] + f_v / self.sr) % 1.0
                p = phases[v]
                
                # Vocal excitation pulse
                pulse = (2.0 * p - 1.0)
                # Formant resonance approximation
                formant_resp = (math.sin(TWO_PI * f_formants[0] * t) * 0.5 +
                                math.sin(TWO_PI * f_formants[1] * t) * 0.35 +
                                math.sin(TWO_PI * f_formants[2] * t) * 0.15)
                acc += pulse * 0.4 + formant_resp * 0.6
                
            acc /= 3.0
            
            if n < att_samples:
                env = (n / att_samples) ** 1.3
            elif n > total_samples - rel_samples:
                env = (total_samples - n) / rel_samples
            else:
                env = 1.0
                
            out[n] = acc * env * volume
        return out


class ScoreMixer:
    def __init__(self, bpm=136, total_bars=32, sample_rate=SAMPLE_RATE):
        self.bpm = bpm
        self.sr = sample_rate
        self.beat_dur = 60.0 / bpm
        self.bar_dur = self.beat_dur * 4.0
        self.total_duration = total_bars * self.bar_dur
        self.total_samples = int(self.total_duration * self.sr)
        
        self.left = [0.0] * self.total_samples
        self.right = [0.0] * self.total_samples
        self.synth = BossOrchestraSynth(sample_rate)

    def add_event(self, bar, beat, samples, pan=0.0):
        start_sec = bar * self.bar_dur + beat * self.beat_dur
        start_sample = int(start_sec * self.sr)
        pan = max(-1.0, min(1.0, pan))
        angle = (pan + 1.0) * (math.pi / 4.0)
        gain_l = math.cos(angle)
        gain_r = math.sin(angle)
        
        for i, val in enumerate(samples):
            idx = start_sample + i
            if idx >= self.total_samples:
                # Wrap around seamlessly for perfect battle looping!
                wrap_idx = idx % self.total_samples
                self.left[wrap_idx] += val * gain_l
                self.right[wrap_idx] += val * gain_r
            else:
                self.left[idx] += val * gain_l
                self.right[idx] += val * gain_r

    def apply_orchestral_hall_reverb(self, wet_mix=0.28, feedback=0.48):
        """Expansive orchestral hall acoustics with lush spatial reflections."""
        delays_l = [int(0.029 * self.sr), int(0.053 * self.sr), int(0.083 * self.sr), int(0.113 * self.sr)]
        delays_r = [int(0.031 * self.sr), int(0.059 * self.sr), int(0.089 * self.sr), int(0.127 * self.sr)]
        
        rev_l = [0.0] * self.total_samples
        rev_r = [0.0] * self.total_samples
        
        for dt in delays_l:
            for i in range(dt, self.total_samples):
                rev_l[i] += (self.left[i - dt] + rev_l[i - dt] * feedback) / len(delays_l)
        for dt in delays_r:
            for i in range(dt, self.total_samples):
                rev_r[i] += (self.right[i - dt] + rev_r[i - dt] * feedback) / len(delays_r)
                
        # Peak normalization and soft-limiting
        max_peak = 0.0001
        for i in range(self.total_samples):
            self.left[i] = self.left[i] * (1.0 - wet_mix * 0.4) + rev_l[i] * wet_mix
            self.right[i] = self.right[i] * (1.0 - wet_mix * 0.4) + rev_r[i] * wet_mix
            if abs(self.left[i]) > max_peak: max_peak = abs(self.left[i])
            if abs(self.right[i]) > max_peak: max_peak = abs(self.right[i])
            
        norm = 0.88 / max_peak if max_peak > 0 else 1.0
        for i in range(self.total_samples):
            l = self.left[i] * norm
            r = self.right[i] * norm
            # Musical tape-style soft limiting
            self.left[i] = math.tanh(l) if abs(l) > 0.75 else l
            self.right[i] = math.tanh(r) if abs(r) > 0.75 else r

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
        print(f"-> Successfully saved Boss Exclusive Orchestra BGM to: {filepath} ({self.total_duration:.2f}s, {self.bpm} BPM)")


def compose_boss_exclusive_orchestra():
    # 32 bars @ 136 BPM = 56.47 seconds of relentless epic orchestral power!
    bpm = 136
    total_bars = 32
    mixer = ScoreMixer(bpm=bpm, total_bars=total_bars)
    s = mixer.synth
    beat_dur = 60.0 / bpm

    print("Composing Section 1: Ominous Ritual Awakening (Bars 0-3)...")
    # Bar 0: Massive Gong Ageng & Sub War Drum + Low Tuba Drone
    gong = s.render_gong_ageng(duration=5.0, volume=0.85)
    mixer.add_event(0, 0.0, gong, pan=0.0)
    
    war_boom = s.render_war_drum(duration=0.8, volume=0.95)
    mixer.add_event(0, 0.0, war_boom, pan=0.0)
    
    cymbal_crash = s.render_crash_cymbal(duration=3.0, volume=0.65)
    mixer.add_event(0, 0.0, cymbal_crash, pan=-0.35)
    
    # Timpani rolling crescendo into bar 1
    for i in range(8):
        roll_vol = 0.35 + 0.07 * i
        timp_roll = s.render_timpani(D2, duration=0.25, volume=roll_vol)
        mixer.add_event(0, 2.0 + i * 0.25, timp_roll, pan=-0.2)
        
    tuba_pedal = s.render_low_brass(D1, duration=mixer.bar_dur * 4.0, volume=0.7)
    mixer.add_event(0, 0.0, tuba_pedal, pan=0.1)

    # Bars 1-3: Low Strings Spiccato Ostinato kicks off
    # D minor driving pattern: D - D - D - D | F - E - D - C# | D - D - F - G | A - G - F - E
    ostinato_pattern = [
        # (beat_offset, note)
        (0.0, D2), (0.25, D2), (0.5, D2), (0.75, D2),
        (1.0, D2), (1.25, D2), (1.5, D2), (1.75, D2),
        (2.0, F2), (2.25, F2), (2.5, E2), (2.75, E2),
        (3.0, D2), (3.25, D2), (3.5, Cs2), (3.75, Cs2),
    ]
    for bar in range(1, 4):
        for b_off, n in ostinato_pattern:
            spic = s.render_spiccato_string(n, duration=0.22, volume=0.68)
            mixer.add_event(bar, b_off, spic, pan=-0.3)
            # Double bass reinforcement on downbeats
            if b_off in [0.0, 1.0, 2.0, 3.0]:
                db = s.render_spiccato_string(n - 12, duration=0.26, volume=0.72)
                mixer.add_event(bar, b_off, db, pan=0.0)
        # Snare cadence entering on bar 2 & 3
        if bar >= 2:
            for bt in [1.0, 2.0, 3.0, 3.5]:
                sn = s.render_snare(duration=0.15, volume=0.45)
                mixer.add_event(bar, bt, sn, pan=0.25)

    print("Composing Section 2: Movement I - The Guardian Strikes (Bars 4-11)...")
    # French Horns lead the grand, menacing Boss Motif in D minor
    horn_melody_bars_4_7 = [
        # (bar, beat, note, dur, punch)
        (4, 0.0, D3, 1.5, True),
        (4, 1.5, F3, 1.0, False),
        (4, 2.5, G3, 1.5, True),
        (5, 0.0, A3, 2.5, True),  # Majestic hold
        (5, 2.5, Bb3, 0.75, False),
        (5, 3.25, A3, 0.75, False),
        (6, 0.0, G3, 1.5, True),
        (6, 1.5, F3, 1.0, False),
        (6, 2.5, E3, 1.5, True),
        (7, 0.0, D3, 2.0, True),
        (7, 2.0, Cs3, 1.0, False),
        (7, 3.0, D3, 1.0, True),
    ]
    for bar, b_off, note, dur, punch in horn_melody_bars_4_7:
        hn = s.render_french_horn(note, duration=dur * beat_dur, volume=0.78, punch=punch)
        mixer.add_event(bar, b_off, hn, pan=0.2)
        # Trombone harmony an octave lower
        tb = s.render_low_brass(note - 12, duration=dur * beat_dur, volume=0.70)
        mixer.add_event(bar, b_off, tb, pan=-0.2)

    # Horn Melody Repetition with Triumph Variation (Bars 8-11)
    horn_melody_bars_8_11 = [
        (8, 0.0, D3, 1.5, True),
        (8, 1.5, F3, 1.0, False),
        (8, 2.5, G3, 1.5, True),
        (9, 0.0, A3, 2.0, True),
        (9, 2.0, C4, 1.0, True),
        (9, 3.0, D4, 1.0, True),
        (10, 0.0, Bb3, 1.5, True),
        (10, 1.5, A3, 1.0, False),
        (10, 2.5, G3, 1.5, True),
        (11, 0.0, A3, 2.5, True),
        (11, 2.5, Cs4, 1.5, True),
    ]
    for bar, b_off, note, dur, punch in horn_melody_bars_8_11:
        hn = s.render_french_horn(note, duration=dur * beat_dur, volume=0.82, punch=punch)
        mixer.add_event(bar, b_off, hn, pan=0.25)
        tb = s.render_low_brass(note - 12, duration=dur * beat_dur, volume=0.72)
        mixer.add_event(bar, b_off, tb, pan=-0.2)

    # Full Rhythm Section & Battle Drums for Bars 4-11
    for bar in range(4, 12):
        # Spiccato cellos driving continuously
        bar_root = D2 if bar in [4, 5, 8, 9] else (G2 if bar == 6 or bar == 10 else A2)
        for b_off in [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75]:
            n = bar_root if (b_off < 2.0 or b_off > 3.0) else (bar_root + 3)
            sp = s.render_spiccato_string(n, duration=0.22, volume=0.66)
            mixer.add_event(bar, b_off, sp, pan=-0.35)
            
        # War drum & Timpani accents
        mixer.add_event(bar, 0.0, s.render_war_drum(0.5, volume=0.9), pan=0.0)
        mixer.add_event(bar, 0.0, s.render_timpani(D2, 0.6, volume=0.8), pan=-0.15)
        mixer.add_event(bar, 1.5, s.render_timpani(A1, 0.4, volume=0.7), pan=-0.15)
        mixer.add_event(bar, 2.0, s.render_war_drum(0.4, volume=0.85), pan=0.0)
        mixer.add_event(bar, 3.0, s.render_timpani(D2, 0.5, volume=0.85), pan=-0.15)
        
        # Snare battle rhythm
        for sn_b in [1.0, 2.0, 2.5, 3.5, 3.75]:
            mixer.add_event(bar, sn_b, s.render_snare(duration=0.18, volume=0.52), pan=0.2)
            
        # Crash cymbal on phrase beginnings (Bars 4 and 8)
        if bar in [4, 8]:
            mixer.add_event(bar, 0.0, s.render_crash_cymbal(2.5, volume=0.6), pan=-0.3)
            
        # Gothic Choir supporting harmony (Vowel 'oh')
        choir_chord = [D3, F3, A3] if bar in [4, 5, 8, 9] else ([G3, Bb3, D4] if bar in [6, 10] else [A3, Cs4, E4])
        for c_note in choir_chord:
            ch = s.render_epic_choir(c_note, duration=mixer.bar_dur * 0.95, volume=0.48, vowel='oh')
            mixer.add_event(bar, 0.0, ch, pan=0.3)

    print("Composing Section 3: Movement II - Escalation & Soaring Counter-Offensive (Bars 12-19)...")
    # High Violins + Screaming Trumpets enter!
    # Dramatic ascending violin arpeggios and counter-melodies
    violin_runs = [
        # Bar 12 (D minor)
        (12, 0.0, D5, 0.5), (12, 0.5, F5, 0.5), (12, 1.0, A5, 0.5), (12, 1.5, D6, 0.5),
        (12, 2.0, C6, 0.5), (12, 2.5, Bb5, 0.5), (12, 3.0, A5, 0.5), (12, 3.5, G5, 0.5),
        # Bar 13 (F Major / Heroic)
        (13, 0.0, F5, 0.5), (13, 0.5, A5, 0.5), (13, 1.0, C6, 0.5), (13, 1.5, F6, 0.5),
        (13, 2.0, E6, 0.5), (13, 2.5, D6, 0.5), (13, 3.0, C6, 0.5), (13, 3.5, Bb5, 0.5),
        # Bar 14 (G Minor / Urgent)
        (14, 0.0, G5, 0.5), (14, 0.5, Bb5, 0.5), (14, 1.0, D6, 0.5), (14, 1.5, G6, 0.5),
        (14, 2.0, Fs6, 0.5), (14, 2.5, E6, 0.5), (14, 3.0, D6, 0.5), (14, 3.5, C6, 0.5),
        # Bar 15 (A dominant cadence)
        (15, 0.0, Cs6, 1.0), (15, 1.0, E6, 1.0), (15, 2.0, G6, 1.0), (15, 3.0, A6, 1.0),
        
        # Bars 16-19: Triumphant battle theme in high octaves
        (16, 0.0, D6, 1.5), (16, 1.5, F6, 1.0), (16, 2.5, E6, 1.5),
        (17, 0.0, D6, 2.0), (17, 2.0, C6, 1.0), (17, 3.0, Bb5, 1.0),
        (18, 0.0, A5, 1.5), (18, 1.5, Bb5, 1.0), (18, 2.5, C6, 1.5),
        (19, 0.0, D6, 2.5), (19, 2.5, Cs6, 1.5),
    ]
    for bar, b_off, note, dur in violin_runs:
        vln = s.render_legato_violins(note, duration=dur * beat_dur, volume=0.62)
        mixer.add_event(bar, b_off, vln, pan=-0.4)

    # Trumpet fanfare bursts in Bars 12-19
    trumpet_fanfares = [
        # Bar 12
        (12, 0.0, D4, 0.35), (12, 0.35, D4, 0.35), (12, 0.7, D4, 0.6), (12, 2.0, A4, 1.5),
        # Bar 14
        (14, 0.0, G4, 0.35), (14, 0.35, G4, 0.35), (14, 0.7, G4, 0.6), (14, 2.0, D5, 1.5),
        # Bar 16
        (16, 0.0, D5, 1.0), (16, 1.0, F5, 1.0), (16, 2.0, A5, 2.0),
        # Bar 18
        (18, 0.0, F5, 1.0), (18, 1.0, G5, 1.0), (18, 2.0, A5, 2.0),
    ]
    for bar, b_off, note, dur in trumpet_fanfares:
        tpt = s.render_trumpet(note, duration=dur * beat_dur, volume=0.72)
        mixer.add_event(bar, b_off, tpt, pan=0.35)

    # Snare double-time military rolls and Timpani driving
    for bar in range(12, 20):
        # Spiccato cellos continuing
        for b_off in [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75]:
            mixer.add_event(bar, b_off, s.render_spiccato_string(D2, 0.2, volume=0.62), pan=-0.35)
        # War drum & Timpani
        mixer.add_event(bar, 0.0, s.render_war_drum(0.5, volume=0.92), pan=0.0)
        mixer.add_event(bar, 2.0, s.render_war_drum(0.5, volume=0.88), pan=0.0)
        mixer.add_event(bar, 1.0, s.render_timpani(D2, 0.4, volume=0.82), pan=-0.2)
        mixer.add_event(bar, 3.0, s.render_timpani(A2, 0.4, volume=0.85), pan=-0.2)
        
        # Snare 16th-note battle pattern
        for sn_b in [0.5, 1.0, 1.5, 2.5, 2.75, 3.0, 3.5, 3.75]:
            mixer.add_event(bar, sn_b, s.render_snare(duration=0.15, volume=0.55), pan=0.25)
            
        # Choir chanting 'Ah' with passionate intensity
        choir_c = [D4, F4, A4] if bar in [12, 16, 17] else ([F4, A4, C5] if bar in [13, 18] else [G4, Bb4, D5])
        for c_note in choir_c:
            mixer.add_event(bar, 0.0, s.render_epic_choir(c_note, duration=mixer.bar_dur * 0.95, volume=0.54, vowel='ah'), pan=0.25)

    print("Composing Section 4: Movement III - Wrath of the Boss / Climax Unison (Bars 20-27)...")
    # Gong Ageng marks the colossal boss rage / climax!
    mixer.add_event(20, 0.0, s.render_gong_ageng(5.0, volume=0.9), pan=0.0)
    mixer.add_event(20, 0.0, s.render_crash_cymbal(3.0, volume=0.7), pan=-0.4)
    mixer.add_event(24, 0.0, s.render_crash_cymbal(3.0, volume=0.7), pan=0.4)
    
    # Cathedral Tubular Bells pealing on dramatic climax bars
    for bell_bar, b_off, bell_note in [(20, 0.0, D5), (22, 0.0, F5), (24, 0.0, G5), (26, 0.0, A5)]:
        bell = s.render_tubular_bell(bell_note, duration=3.5, volume=0.65)
        mixer.add_event(bell_bar, b_off, bell, pan=0.3)

    # Orchestral Fortissimo Unison Stabs (3+3+2 syncopated punch rhythm!)
    # Rhythm: Beat 0.0, 0.75, 1.5, 2.25, 3.0
    punch_beats = [0.0, 0.75, 1.5, 2.25, 3.0]
    for bar in range(20, 28):
        root = D2 if bar in [20, 21] else (F2 if bar in [22, 23] else (G2 if bar in [24, 25] else Cs3))
        for pb in punch_beats:
            # Massive Brass Unison Punch
            tuba = s.render_low_brass(root - 12, duration=0.35, volume=0.82)
            horn = s.render_french_horn(root, duration=0.35, volume=0.85, punch=True)
            tpt = s.render_trumpet(root + 12, duration=0.35, volume=0.80)
            mixer.add_event(bar, pb, tuba, pan=-0.2)
            mixer.add_event(bar, pb, horn, pan=0.2)
            mixer.add_event(bar, pb, tpt, pan=0.3)
            
            # Heavy Timpani + War Drum punch on unison hits
            timp = s.render_timpani(root, duration=0.4, volume=0.9)
            drum = s.render_war_drum(duration=0.35, volume=0.95)
            mixer.add_event(bar, pb, timp, pan=-0.15)
            mixer.add_event(bar, pb, drum, pan=0.0)
            
            # Snare crack
            sn = s.render_snare(duration=0.2, volume=0.65)
            mixer.add_event(bar, pb, sn, pan=0.25)
            
            # Screaming strings marcato
            str_hit = s.render_spiccato_string(root + 24, duration=0.3, volume=0.75)
            mixer.add_event(bar, pb, str_hit, pan=-0.4)
            
            # Choir explosive chant 'Dah!'
            ch = s.render_epic_choir(root + 12, duration=0.3, volume=0.6, vowel='ah')
            mixer.add_event(bar, pb, ch, pan=0.1)

    print("Composing Section 5: Movement IV - Final Surge & Seamless Loop Seam (Bars 28-31)...")
    # Accelerating chromatic ascension: Bb -> Bdim -> C -> C#dim -> Dm -> A7
    tension_chords = [
        (28, Bb2, [Bb3, D4, F4]),
        (29, C3,  [C4, E4, G4]),
        (30, Cs3, [Cs4, E4, A4]),
        (31, A2,  [A3, Cs4, E4, G4]),
    ]
    for bar, bass_n, chord_notes in tension_chords:
        # Furious 16th-note string ostinato climbing up
        for b_off in [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75]:
            mixer.add_event(bar, b_off, s.render_spiccato_string(bass_n, 0.18, volume=0.74), pan=-0.35)
            # Snare roll accelerating
            if bar == 31:
                mixer.add_event(bar, b_off, s.render_snare(duration=0.12, volume=0.4 + b_off * 0.1, is_roll=True), pan=0.25)
            else:
                if b_off in [0.0, 1.0, 2.0, 3.0, 3.5]:
                    mixer.add_event(bar, b_off, s.render_snare(duration=0.15, volume=0.55), pan=0.25)
                    
        # Brass fanfare ascending
        for cn in chord_notes:
            hn = s.render_french_horn(cn, duration=mixer.bar_dur * 0.9, volume=0.82, punch=True)
            mixer.add_event(bar, 0.0, hn, pan=0.2)
            tpt = s.render_trumpet(cn + 12, duration=mixer.bar_dur * 0.9, volume=0.75)
            mixer.add_event(bar, 0.0, tpt, pan=0.35)
            
        # Timpani & War drums pounding
        mixer.add_event(bar, 0.0, s.render_war_drum(0.5, volume=0.95), pan=0.0)
        mixer.add_event(bar, 2.0, s.render_war_drum(0.5, volume=0.9), pan=0.0)
        mixer.add_event(bar, 0.0, s.render_timpani(bass_n, 0.5, volume=0.88), pan=-0.15)
        mixer.add_event(bar, 2.0, s.render_timpani(bass_n, 0.5, volume=0.85), pan=-0.15)

    # Bar 31 Climax: Giant Timpani roll + Cymbal wash leading into loop point
    for i in range(16):
        roll_vol = 0.45 + 0.035 * i
        timp_roll = s.render_timpani(A1, duration=0.15, volume=roll_vol)
        mixer.add_event(31, i * 0.25, timp_roll, pan=-0.2)
        
    mixer.add_event(31, 2.0, s.render_crash_cymbal(3.5, volume=0.75), pan=0.0)
    
    # Grand orchestral reverb application
    print("Applying Orchestral Hall Reverb and Mastering Limiter...")
    mixer.apply_orchestral_hall_reverb(wet_mix=0.30, feedback=0.46)
    
    target_path = os.path.abspath("assets/audio/music/boss_exclusive_orchestra.wav")
    mixer.save_wav(target_path)
    return target_path


if __name__ == '__main__':
    t0 = time.time()
    print("==========================================================")
    print("NUSA VALE - EXCLUSIVE ORCHESTRAL BOSS THEME COMPOSITION")
    print("==========================================================")
    out_file = compose_boss_exclusive_orchestra()
    elapsed = time.time() - t0
    print(f"Done in {elapsed:.2f} seconds. File created at: {out_file}")
