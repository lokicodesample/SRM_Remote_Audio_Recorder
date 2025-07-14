# SRM_Recorder_Server.py - Remote Meeting Recorder Server with SRM Branding
# To be run on the Raspberry Pi

import threading
import os
from datetime import datetime
import time
import sounddevice as sd
import numpy as np
from scipy.io.wavfile import write
import json
from flask import Flask, request, jsonify

class SRMRecorder:
    def __init__(self):
        self.is_recording = False
        self.is_paused = False
        self.audio_frames = []
        self.start_time = 0
        self.time_before_pause = 0
        self.lock = threading.Lock()
        self.meeting_id = ""
        self.meeting_topic = ""
        # Path on the Raspberry Pi where recordings will be saved
        self.save_path = os.path.join(os.path.expanduser('~'), 'fun', 'SRM_audio')
        
        # Ensure the save directory exists
        if not os.path.exists(self.save_path):
            os.makedirs(self.save_path)

    def set_meeting_info(self, meeting_id, topic):
        with self.lock:
            self.meeting_id = meeting_id.strip()
            self.meeting_topic = topic.strip()
            
    def start_recording(self):
        with self.lock:
            if self.is_recording or not self.meeting_id:
                return False
            self.is_recording = True
            self.is_paused = False
            self.audio_frames = []
            self.start_time = time.time()
            self.time_before_pause = 0
            threading.Thread(target=self._record_thread, daemon=True).start()
            return True
    
    def _record_thread(self):
        try:
            # Using a lower sample rate and block size can be more reliable on Raspberry Pi
            with sd.InputStream(samplerate=16000, channels=1, dtype='int16', blocksize=1024) as stream:
                while True:
                    with self.lock:
                        if not self.is_recording:
                            break
                        if self.is_paused:
                            time.sleep(0.1)
                            continue
                    
                    data, _ = stream.read(1024)
                    with self.lock:
                        self.audio_frames.append(data)
        except Exception as e:
            print(f"Recording error: {e}")
            with self.lock:
                self.is_recording = False
                self.is_paused = False
    
    def pause_recording(self):
        with self.lock:
            if not self.is_recording or self.is_paused:
                return False
            self.is_paused = True
            self.time_before_pause += time.time() - self.start_time
            self.start_time = 0
            return True
    
    def resume_recording(self):
        with self.lock:
            if not self.is_recording or not self.is_paused:
                return False
            self.is_paused = False
            self.start_time = time.time()
            return True
    
    def stop_recording(self):
        with self.lock:
            if not self.is_recording:
                return None
            self.is_recording = False
            self.is_paused = False
        
        time.sleep(0.2)  # Let recording thread finish
        
        if not self.audio_frames:
            return None
        
        try:
            with self.lock:
                meeting_time = datetime.now().strftime('%Y-%m-%d_%H-%M')
                
                # Calculate final duration
                final_duration_seconds = self.time_before_pause
                if self.start_time > 0: # If it was running when stopped
                    final_duration_seconds += time.time() - self.start_time
                
                duration_str = self.format_duration(int(final_duration_seconds))
                
                filename = f"SRM_{meeting_time}_{self.meeting_id}"
                if self.meeting_topic:
                    filename += f"_{self.meeting_topic[:20]}"
                filename += f"_{duration_str}.wav"
                
                filename = "".join(c if c.isalnum() or c in ('_', '-') else '_' for c in filename)
                filepath = os.path.join(self.save_path, filename)
                
                write(filepath, 16000, np.concatenate(self.audio_frames, axis=0))
                
                # Reset for next recording
                self.meeting_id = ""
                self.meeting_topic = ""
                self.audio_frames = []
                self.start_time = 0
                self.time_before_pause = 0
                
                return filepath
        except Exception as e:
            print(f"Save error: {e}")
            return None
    
    def format_duration(self, seconds):
        hours = seconds // 3600
        minutes = (seconds % 3600) // 60
        seconds = seconds % 60
        return f"{hours:02d}h{minutes:02d}m{seconds:02d}s"
    
    def get_status(self):
        with self.lock:
            elapsed = self.time_before_pause
            if self.is_recording and not self.is_paused and self.start_time > 0:
                elapsed += time.time() - self.start_time
            return {
                'is_recording': self.is_recording,
                'is_paused': self.is_paused,
                'elapsed_time': elapsed,
                'meeting_id': self.meeting_id,
                'meeting_topic': self.meeting_topic,
                'save_path': self.save_path
            }

# --- Flask Web Server ---
app = Flask(__name__)
recorder = SRMRecorder()

@app.route('/status', methods=['GET'])
def status():
    return jsonify(recorder.get_status())

@app.route('/start', methods=['POST'])
def start():
    data = request.json
    meeting_id = data.get('meeting_id')
    topic = data.get('topic')
    if not meeting_id:
        return jsonify({'status': 'error', 'message': 'Meeting ID is required'}), 400
    
    recorder.set_meeting_info(meeting_id, topic)
    if recorder.start_recording():
        return jsonify({'status': 'success', 'message': 'Recording started'})
    else:
        return jsonify({'status': 'error', 'message': 'Already recording or meeting ID not set'}), 400

@app.route('/stop', methods=['POST'])
def stop():
    filepath = recorder.stop_recording()
    if filepath:
        return jsonify({'status': 'success', 'message': f'Recording saved to {filepath}'})
    else:
        return jsonify({'status': 'error', 'message': 'Not recording or failed to save'}), 400

@app.route('/pause', methods=['POST'])
def pause():
    if recorder.pause_recording():
        return jsonify({'status': 'success', 'message': 'Recording paused'})
    else:
        return jsonify({'status': 'error', 'message': 'Not recording or already paused'}), 400

@app.route('/resume', methods=['POST'])
def resume():
    if recorder.resume_recording():
        return jsonify({'status': 'success', 'message': 'Recording resumed'})
    else:
        return jsonify({'status': 'error', 'message': 'Not recording or not paused'}), 400

if __name__ == "__main__":
    # Runs the server on all available network interfaces
    # The port can be changed if needed
    app.run(host='0.0.0.0', port=5000, debug=False)
