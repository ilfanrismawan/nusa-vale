"""
Nusa Vale - Midnight Nightmare & Haunted Horror BGM Generator
Style: Chilling psychological horror / Darkwood / Silent Hill / Indonesian haunted folklore
Features:
- Warped detuned horror music box (creepy nursery motif)
- Deep subterranean sub drone & dread swells
- Ominous muffled heartbeat (lub-dub)
- Dissonant screeching string clusters (tritones & minor 2nds)
- Ghostly breath sweeps & eerie metallic scrapes
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

class HorrorSynth:
    def __init__(self, sample_rate=44100):
        self.sr = sample_rate

    def render_dark_drone(self, freq, duration, volume=0.65):
        """Deep sub-bass drone with slow menacing pulse and pitch instability."""
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        phase1, phase2 = 0.0, 0.0
        for n in range(total_samples):
            t = n / self.sr
            # Slow pulse modulation (0.25 Hz)
            lfo = 0.75 + 0.25 * math.sin(TWO_PI * 0.22 * t)
            pitch_drift = 1.0 + 0.008 * math.sin(TWO_PI * 0.15 * t)
            f = freq * pitch_drift
            
            phase1 += TWO_PI * f / self.sr
            phase2 += TWO_PI * (f * 1.503) / self.sr # dark fifth with slight detune
            if phase1 > TWO_PI: phase1 -= TWO_PI
            if phase2 > TWO_PI: phase2 -= TWO_PI
            
            s1 = math.sin(phase1)
            s2 = math.sin(phase2) * 0.35
            # Low rumble sub
            s_sub = math.sin(phase1 * 0.5) * 0.5
            
            att = min(1.0, n / (0.3 * self.sr))
            rel = min(1.0, (total_samples - n) / (0.3 * self.sr))
            out[n] = (s1 + s2 + s_sub) * lfo * att * rel * volume
        return out

    def render_haunted_music_box(self, midi_note, duration, volume=0.5):
        """Creepy, detuned vintage music box with wow-and-flutter and metallic ping."""
        freq = midi_to_freq(midi_note)
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        tau = 0.95
        phase = 0.0
        for n in range(total_samples):
            t = n / self.sr
            # Pitch wobble / wow-and-flutter (unstable vintage mechanism)
            wobble = 0.012 * math.sin(TWO_PI * 3.4 * t) + 0.006 * math.sin(TWO_PI * 0.7 * t)
            cur_f = freq * (1.0 + wobble)
            phase += TWO_PI * cur_f / self.sr
            if phase > TWO_PI: phase -= TWO_PI
            
            # Pure bell with cold high inharmonic overtone (ratio 3.14)
            s1 = math.sin(phase) * math.exp(-t / tau)
            s2 = math.sin(phase * 3.1415) * 0.45 * math.exp(-t / (tau * 0.35))
            s3 = math.sin(phase * 5.82) * 0.2 * math.exp(-t / (tau * 0.12))
            # Mechanical tine pluck click
            click = math.exp(-t / 0.004) * 0.3 * (random.random() * 2.0 - 1.0)
            
            sample = s1 + s2 + s3 + click
            if n > total_samples - 200:
                sample *= (total_samples - n) / 200.0
            out[n] = sample * volume
        return out

    def render_dissonant_cluster(self, midi_note, duration, volume=0.45):
        """Spine-chilling bowed string cluster (tritone dissonance + shivering tremolo)."""
        f1 = midi_to_freq(midi_note)
        f2 = midi_to_freq(midi_note + 6) # Devil's interval: Tritone!
        f3 = midi_to_freq(midi_note + 7) # Minor 2nd clash against tritone
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        att_samples = int(0.6 * self.sr)
        rel_samples = int(0.8 * self.sr)
        sust_samples = max(0, total_samples - att_samples - rel_samples)
        p1, p2, p3 = 0.0, 0.0, 0.0
        for n in range(total_samples):
            t = n / self.sr
            if n < att_samples:
                env = (n / att_samples) ** 1.6
            elif n < att_samples + sust_samples:
                env = 1.0
            else:
                rel_idx = n - (att_samples + sust_samples)
                env = max(0.0, 1.0 - (rel_idx / rel_samples))
                
            # Shivering horror tremolo (6.5 Hz)
            trem = 0.7 + 0.3 * math.sin(TWO_PI * 6.5 * t)
            
            p1 += TWO_PI * f1 / self.sr
            p2 += TWO_PI * f2 / self.sr
            p3 += TWO_PI * f3 / self.sr
            
            # Sawtooth-like bowed harmonics
            s1 = (math.sin(p1) + 0.4 * math.sin(2.0*p1) + 0.2 * math.sin(3.0*p1))
            s2 = (math.sin(p2) + 0.35 * math.sin(2.0*p2)) * 0.8
            s3 = (math.sin(p3) + 0.3 * math.sin(2.0*p3)) * 0.6
            
            sample = (s1 + s2 + s3) * env * trem
            out[n] = sample * volume
        return out

    def render_heartbeat(self, volume=0.75):
        """Deep ominous lub-dub heartbeat."""
        dur = 0.65
        total_samples = int(dur * self.sr)
        out = [0.0] * total_samples
        thud_samples = int(0.18 * self.sr)
        
        # Lub (1st thud)
        for n in range(thud_samples):
            t = n / self.sr
            f = 55.0 * math.exp(-t * 14.0) # pitch drops 55Hz -> 20Hz
            s = math.sin(TWO_PI * f * t) * math.exp(-t * 12.0)
            out[n] += s * volume
            
        # Dub (2nd thud, offset by 0.22s)
        offset = int(0.22 * self.sr)
        for n in range(thud_samples):
            t = n / self.sr
            f = 48.0 * math.exp(-t * 14.0)
            s = math.sin(TWO_PI * f * t) * math.exp(-t * 10.0)
            if offset + n < total_samples:
                out[offset + n] += s * volume * 0.85
        return out

    def render_metallic_scrape(self, duration=0.6, volume=0.35):
        """Creepy fingernails/chains scraping on rusty metal."""
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        f_scrape = 1450.0
        phase = 0.0
        for n in range(total_samples):
            t = n / self.sr
            noise = random.random() * 2.0 - 1.0
            # Rapid FM frequency jitter
            f = f_scrape + 400.0 * math.sin(TWO_PI * 45.0 * t) + noise * 200.0
            phase += TWO_PI * f / self.sr
            s = math.sin(phase) * (noise * 0.5 + 0.5)
            env = math.sin(math.pi * (n / total_samples)) ** 2.0
            out[n] = s * env * volume
        return out

    def render_ghost_whisper(self, duration=3.0, volume=0.32):
        """Eerie wind / spirit breath sweeping in the dark."""
        total_samples = int(duration * self.sr)
        out = [0.0] * total_samples
        state = 0.0
        for n in range(total_samples):
            t = n / self.sr
            noise = random.random() * 2.0 - 1.0
            # Resonant lowpass sweeping
            cutoff = 400.0 + 350.0 * math.sin(TWO_PI * (0.35 * t))
            alpha = min(0.9, TWO_PI * cutoff / self.sr)
            state += alpha * (noise - state)
            env = math.sin(math.pi * (n / total_samples)) ** 1.8
            out[n] = state * env * volume
        return out


class ScoreMixer:
    def __init__(self, bpm=66, total_bars=24, sample_rate=44100):
        self.bpm = bpm
        self.sr = sample_rate
        self.beat_dur = 60.0 / bpm
        self.bar_dur = self.beat_dur * 4.0
        self.total_duration = total_bars * self.bar_dur
        self.total_samples = int(self.total_duration * self.sr)
        self.left = [0.0] * self.total_samples
        self.right = [0.0] * self.total_samples
        self.synth = HorrorSynth(sample_rate)

    def add_custom_samples(self, start_bar, beat_offset, samples, pan=0.0):
        start_sec = start_bar * self.bar_dur + beat_offset * self.beat_dur
        start_sample = int(start_sec * self.sr)
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

    def apply_horror_reverb(self, wet_mix=0.32, feedback=0.52):
        """Dark cavernous reverb with long eerie decay."""
        delay_times_l = [int(0.041 * self.sr), int(0.067 * self.sr), int(0.089 * self.sr)]
        delay_times_r = [int(0.047 * self.sr), int(0.073 * self.sr), int(0.097 * self.sr)]
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
        print(f"Exported Horror BGM {filepath}: {self.total_duration:.2f}s")


def compose_midnight_horror_theme():
    # 24 bars @ 66 BPM = ~87 seconds of dread
    mixer = ScoreMixer(bpm=66, total_bars=24)
    s = mixer.synth
    
    # MIDI constants in C Minor / Locrian (dreadful dissonance)
    # C4=60, D4=62, Eb4=63, F4=65, F#4=66, G4=67, Ab4=68, B4=71, C5=72, Eb5=75, F#5=78, G5=79, B5=83, C6=84
    C4, Eb4, Fs4, G4, Ab4, B4 = 60, 63, 66, 67, 68, 71
    C5, Eb5, Fs5, G5, Ab5, B5 = 72, 75, 78, 79, 80, 83
    C6, Eb6, Fs6, G6 = 84, 87, 90, 91

    # ==================================================
    # 1. MENACING SUB-DRONE (Undercurrent of tension)
    # ==================================================
    # Low C1 (32.7 Hz) and C#1 (34.6 Hz - sickening semitone dissonance)
    for bar in range(0, 24, 4):
        # 4-bar dark drone blocks
        base_f = 32.7 if bar < 12 else (34.6 if bar < 20 else 32.7)
        drone = s.render_dark_drone(base_f, mixer.bar_dur * 4.0, volume=0.72)
        mixer.add_custom_samples(bar, 0.0, drone, pan=0.0)

    # ==================================================
    # 2. HEARTBEAT (Tension pulse - lub-dub)
    # ==================================================
    # The heart beats steadily every 2 beats, then speeds up when danger mounts
    for bar in range(24):
        # Heartbeat on beat 0 and beat 2
        mixer.add_custom_samples(bar, 0.0, s.render_heartbeat(volume=0.75), pan=-0.05)
        mixer.add_custom_samples(bar, 2.0, s.render_heartbeat(volume=0.70), pan=-0.05)
        # Extra rapid anxious beats during climax (bars 14..20)
        if 14 <= bar <= 20:
            mixer.add_custom_samples(bar, 1.0, s.render_heartbeat(volume=0.55), pan=0.1)
            mixer.add_custom_samples(bar, 3.0, s.render_heartbeat(volume=0.55), pan=0.1)

    # ==================================================
    # 3. GHOSTLY BREATH & SCRAPES (Spatial jumpscares)
    # ==================================================
    whisper_bars = [1, 5, 9, 13, 17, 21]
    for b in whisper_bars:
        pan = -0.6 if b % 2 == 1 else 0.6
        whisper = s.render_ghost_whisper(duration=3.4, volume=0.38)
        mixer.add_custom_samples(b, 1.0, whisper, pan=pan)

    scrape_moments = [
        (3, 2.5, 0.7),
        (7, 3.5, -0.65),
        (11, 2.0, 0.6),
        (15, 3.0, -0.75),
        (19, 1.5, 0.8),
        (23, 2.0, -0.5),
    ]
    for bar, beat, pan in scrape_moments:
        scrape = s.render_metallic_scrape(duration=0.55, volume=0.42)
        mixer.add_custom_samples(bar, beat, scrape, pan=pan)

    # ==================================================
    # 4. DISSONANT HORROR STRINGS (Bowed screech)
    # ==================================================
    # Enters in eerie swells
    string_clusters = [
        (2, 0.0, 48, 3.0), # C3 cluster (C3 + F#3 + G3)
        (6, 0.0, 49, 3.2), # C#3 cluster (creeping terror)
        (10, 0.0, 48, 3.5),
        # Climax horror swells (bars 12..19)
        (12, 0.0, 54, 3.5), # F#3
        (14, 0.0, 55, 3.5), # G3
        (16, 0.0, 60, 3.5), # C4 screeching cluster
        (18, 0.0, 61, 3.5), # C#4 ultimate tension
        (20, 0.0, 48, 3.0), # Resolves back to dark C
    ]
    for bar, beat, note, dur_beats in string_clusters:
        cluster = s.render_dissonant_cluster(note, dur_beats * mixer.beat_dur, volume=0.48)
        mixer.add_custom_samples(bar, beat, cluster, pan=-0.2)

    # ==================================================
    # 5. WARPED CREEPY MUSIC BOX (Haunted Nightmare Lullaby)
    # ==================================================
    # A warped, off-kilter nightmare nursery motif
    # (Notice the use of tritone F# and minor 2nds to sound terrifying and deeply unsettled)
    lullaby_notes = [
        # Phrase 1: The Call (Bars 0..3)
        (0, 1.0, C5, 1.8), (0, 3.0, Eb5, 1.5),
        (1, 0.5, Fs5, 1.5), (1, 2.5, G5, 2.0),
        (2, 1.0, Eb5, 1.5), (2, 2.5, C5, 2.0),
        (3, 1.0, B4, 3.0), # Unresolved creepy leading tone

        # Phrase 2: The Stalker Approaches (Bars 4..7)
        (4, 1.0, C5, 1.5), (4, 2.5, Eb5, 1.5),
        (5, 0.5, Fs5, 1.5), (5, 2.0, B5, 1.5), (5, 3.5, C6, 1.0),
        (6, 1.0, Ab5, 2.0), (6, 3.0, Fs5, 1.5),
        (7, 1.0, G5, 3.5),

        # Phrase 3: Whispers from the shadows (Bars 8..11)
        (8, 0.5, Eb6, 1.5), (8, 2.5, C6, 1.5),
        (9, 0.5, Fs5, 1.5), (9, 2.0, G5, 1.0), (9, 3.0, Eb5, 1.5),
        (10, 1.0, C5, 2.0), (10, 3.0, B4, 1.5),
        (11, 0.5, Fs4, 3.5), # Deep tritone bell

        # Phrase 4: The Nightmare Climax (Bars 12..19)
        (12, 1.0, C6, 1.0), (12, 2.0, B5, 1.0), (12, 3.0, Fs5, 1.5),
        (13, 1.0, G5, 2.0), (13, 3.0, Eb5, 1.5),
        (14, 0.5, Fs5, 1.0), (14, 1.5, G5, 1.0), (14, 2.5, Ab5, 1.5), (14, 3.5, B5, 0.8),
        (15, 0.5, C6, 2.5), (15, 3.0, Eb6, 1.5),
        (16, 0.5, Fs6, 2.0), (16, 2.5, Eb6, 1.5),
        (17, 0.5, C6, 2.0), (17, 2.5, B5, 1.5),
        (18, 0.5, Ab5, 1.5), (18, 2.0, Fs5, 1.5), (18, 3.5, G5, 1.5),
        (19, 1.0, C5, 3.5),

        # Outro into loop (Bars 20..23)
        (20, 1.0, Eb5, 1.5), (20, 3.0, C5, 1.5),
        (21, 1.0, Fs5, 2.0), (21, 3.0, G5, 1.5),
        (22, 1.0, Eb5, 2.0), (22, 3.0, B4, 2.0),
        (23, 1.0, C5, 3.5),
    ]

    for bar, beat, note, dur in lullaby_notes:
        box_sample = s.render_haunted_music_box(note, dur * mixer.beat_dur, volume=0.52)
        mixer.add_custom_samples(bar, beat, box_sample, pan=0.22)

    mixer.apply_horror_reverb(wet_mix=0.34, feedback=0.54)
    target = os.path.abspath("assets/audio/music/midnight_horror_nightmare.wav")
    mixer.save_wav(target)
    return target


if __name__ == '__main__':
    print("=== Composing Nusa Vale Midnight Nightmare Horror BGM ===")
    out_path = compose_midnight_horror_theme()
    print("Haunted Nightmare Track Ready:", out_path)
    print("=== Horror Composition Complete! ===")
