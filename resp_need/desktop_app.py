# desktop_app.py - All-in-one SRM Desktop Control (v3 - QR Code)
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import threading
import os
import time
import json
import subprocess
import socket
from datetime import datetime
from PIL import Image, ImageTk
import qrcode  # New dependency
import sounddevice as sd
import numpy as np
from scipy.io.wavfile import write
from flask import Flask, request, jsonify

# --- Recorder Logic (No changes here) ---
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
        self.save_path = os.path.join(os.path.expanduser('~'), 'fun', 'SRM_audio')
        if not os.path.exists(self.save_path):
            os.makedirs(self.save_path)

    def set_meeting_info(self, meeting_id, topic, path):
        with self.lock:
            self.meeting_id = meeting_id.strip()
            self.meeting_topic = topic.strip()
            self.save_path = path.strip()

    def start_recording(self):
        with self.lock:
            if self.is_recording or not self.meeting_id: return False
            self.is_recording = True
            self.is_paused = False
            self.audio_frames = []
            self.start_time = time.time()
            self.time_before_pause = 0
            threading.Thread(target=self._record_thread, daemon=True).start()
            return True

    def _record_thread(self):
        try:
            with sd.InputStream(samplerate=16000, channels=1, dtype='int16', blocksize=1024) as stream:
                while True:
                    with self.lock:
                        if not self.is_recording: break
                        if self.is_paused:
                            time.sleep(0.1)
                            continue
                    data, _ = stream.read(1024)
                    with self.lock:
                        self.audio_frames.append(data)
        except Exception as e:
            print(f"Recording error: {e}")
            with self.lock: self.is_recording = False

    def pause_recording(self):
        with self.lock:
            if not self.is_recording or self.is_paused: return False
            self.is_paused = True
            self.time_before_pause += time.time() - self.start_time
            self.start_time = 0
            return True

    def resume_recording(self):
        with self.lock:
            if not self.is_recording or not self.is_paused: return False
            self.is_paused = False
            self.start_time = time.time()
            return True

    def _save_file_in_background(self, frames_to_save, meeting_id, topic, duration_str, save_path):
        try:
            meeting_time = datetime.now().strftime('%Y-%m-%d_%H-%M')
            filename = f"SRM_{meeting_id}_{topic}_{meeting_time}_{duration_str}.wav"
            filename = "".join(c if c.isalnum() or c in ('_', '-') else '_' for c in filename)
            filepath = os.path.join(save_path, filename)
            if not os.path.exists(save_path):
                os.makedirs(save_path)
            audio_data = np.concatenate(frames_to_save, axis=0)
            write(filepath, 16000, audio_data)
            print(f"Successfully saved to {filepath}")
        except Exception as e:
            print(f"Save error in background thread: {e}")

    def stop_recording(self):
        with self.lock:
            if not self.is_recording: return None
            self.is_recording = False
            self.is_paused = False
            duration = self.time_before_pause + (time.time() - self.start_time if self.start_time > 0 else 0)
            duration_str = self.format_duration(int(duration))
            threading.Thread(
                target=self._save_file_in_background,
                args=(self.audio_frames.copy(), self.meeting_id, self.meeting_topic, duration_str, self.save_path),
                daemon=True
            ).start()
            self.audio_frames = []
            self.start_time = 0
            self.time_before_pause = 0
        return True

    def format_duration(self, seconds):
        h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
        return f"{h:02d}:{m:02d}:{s:02d}"

    def get_status(self):
        with self.lock:
            elapsed = self.time_before_pause
            if self.is_recording and not self.is_paused and self.start_time > 0:
                elapsed += time.time() - self.start_time
            return {'is_recording': self.is_recording, 'is_paused': self.is_paused, 'elapsed_time': elapsed}

recorder = SRMRecorder()

# --- Flask Web Server (No changes here) ---
flask_app = Flask(__name__)
@flask_app.route('/status')
def status(): return jsonify(recorder.get_status())
@flask_app.route('/start', methods=['POST'])
def start():
    data = request.json
    recorder.set_meeting_info(data.get('meeting_id'), data.get('topic'), recorder.save_path)
    return jsonify({'status': 'success' if recorder.start_recording() else 'failure'})
@flask_app.route('/stop', methods=['POST'])
def stop(): return jsonify({'status': 'success' if recorder.stop_recording() else 'failure'})
@flask_app.route('/pause', methods=['POST'])
def pause(): return jsonify({'status': 'success' if recorder.pause_recording() else 'failure'})
@flask_app.route('/resume', methods=['POST'])
def resume(): return jsonify({'status': 'success' if recorder.resume_recording() else 'failure'})

# --- Main Desktop Application ---
class SRMDesktopApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("SRM Desktop Control")
        self.geometry("550x650") # Increased height for QR code
        self.ngrok_process = None

        self.style = ttk.Style(self)
        self.style.theme_use('clam')

        self.ip_var = tk.StringVar(value="Finding IP...")
        self.ngrok_var = tk.StringVar(value="Starting ngrok...")
        self.timer_var = tk.StringVar(value="00:00:00")
        self.status_var = tk.StringVar(value="Ready")
        self.save_path_var = tk.StringVar(value=recorder.save_path)
        self.meeting_id_var = tk.StringVar()
        self.meeting_topic_var = tk.StringVar()
        self.qr_image = None # To hold the QR code image

        self.create_widgets()
        self.start_background_tasks()
        self.update_timer()
        self.protocol("WM_DELETE_WINDOW", self.on_close)

    def load_logo(self):
        try:
            logo_path = os.path.join(os.path.dirname(__file__), "srm_logo.png")
            img = Image.open(logo_path).resize((150, 50), Image.LANCZOS)
            return ImageTk.PhotoImage(img)
        except Exception as e:
            print(f"Could not load logo: {e}")
            return None

    def create_widgets(self):
        main_frame = ttk.Frame(self, padding="10")
        main_frame.pack(fill=tk.BOTH, expand=True)

        # --- Top section: Logo and Title ---
        header_frame = ttk.Frame(main_frame)
        header_frame.pack(fill=tk.X, pady=(0, 10))
        self.logo = self.load_logo()
        if self.logo:
            ttk.Label(header_frame, image=self.logo).pack(side=tk.LEFT, padx=(0, 10))
        ttk.Label(header_frame, text="SRM Meeting Recorder", font=("Arial", 18, "bold")).pack(side=tk.LEFT)

        # --- Middle section: Split into two columns ---
        content_frame = ttk.Frame(main_frame)
        content_frame.pack(fill=tk.BOTH, expand=True)
        left_frame = ttk.Frame(content_frame)
        left_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 5))
        right_frame = ttk.Frame(content_frame)
        right_frame.pack(side=tk.RIGHT, fill=tk.Y, padx=(5, 0))

        # --- Left Column: Details and Controls ---
        details_frame = ttk.LabelFrame(left_frame, text="Meeting Details", padding="10")
        details_frame.pack(fill=tk.X, pady=5)
        ttk.Label(details_frame, text="Meeting ID*:").grid(row=0, column=0, sticky=tk.W, pady=2)
        self.id_entry = ttk.Entry(details_frame, textvariable=self.meeting_id_var)
        self.id_entry.grid(row=0, column=1, sticky=tk.EW, padx=5)
        ttk.Label(details_frame, text="Meeting Topic:").grid(row=1, column=0, sticky=tk.W, pady=2)
        self.topic_entry = ttk.Entry(details_frame, textvariable=self.meeting_topic_var)
        self.topic_entry.grid(row=1, column=1, sticky=tk.EW, padx=5)
        details_frame.columnconfigure(1, weight=1)

        save_frame = ttk.LabelFrame(left_frame, text="Save Location", padding="10")
        save_frame.pack(fill=tk.X, pady=5)
        self.path_entry = ttk.Entry(save_frame, textvariable=self.save_path_var)
        self.path_entry.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0, 5))
        ttk.Button(save_frame, text="Browse...", command=self.browse_location).pack(side=tk.LEFT)

        ttk.Label(left_frame, textvariable=self.timer_var, font=("Courier", 40, "bold"), anchor=tk.CENTER).pack(pady=10, fill=tk.X)

        control_frame = ttk.Frame(left_frame)
        control_frame.pack(pady=5)
        self.start_btn = ttk.Button(control_frame, text="Start", command=self.start_recording, style="Accent.TButton")
        self.start_btn.pack(side=tk.LEFT, padx=5, ipady=5)
        self.pause_btn = ttk.Button(control_frame, text="Pause", command=self.toggle_pause, state=tk.DISABLED)
        self.pause_btn.pack(side=tk.LEFT, padx=5, ipady=5)
        self.stop_btn = ttk.Button(control_frame, text="Stop", command=self.stop_recording, state=tk.DISABLED)
        self.stop_btn.pack(side=tk.LEFT, padx=5, ipady=5)
        self.style.configure("Accent.TButton", font=("Arial", 10, "bold"))

        # --- Right Column: Connection Info and QR Code ---
        conn_frame = ttk.LabelFrame(right_frame, text="Remote Access", padding="10")
        conn_frame.pack(fill=tk.X)
        ttk.Label(conn_frame, text="Local IP:").grid(row=0, column=0, sticky=tk.W)
        ttk.Entry(conn_frame, textvariable=self.ip_var, state="readonly", width=15).grid(row=0, column=1, sticky=tk.EW, padx=5)
        ttk.Label(conn_frame, text="ngrok URL:").grid(row=1, column=0, sticky=tk.W)
        self.ngrok_entry = ttk.Entry(conn_frame, textvariable=self.ngrok_var, state="readonly", width=15)
        self.ngrok_entry.grid(row=1, column=1, sticky=tk.EW, padx=5)
        
        self.qr_label = ttk.Label(right_frame, text="QR will appear here", anchor=tk.CENTER)
        self.qr_label.pack(pady=10, fill=tk.BOTH, expand=True)

        # --- Bottom Status Bar ---
        ttk.Label(self, textvariable=self.status_var, relief=tk.SUNKEN, anchor=tk.W).pack(side=tk.BOTTOM, fill=tk.X)

    def browse_location(self):
        path = filedialog.askdirectory(initialdir=self.save_path_var.get())
        if path: self.save_path_var.set(path)

    def start_background_tasks(self):
        threading.Thread(target=lambda: flask_app.run(host='0.0.0.0', port=5000), daemon=True).start()
        threading.Thread(target=self.find_ip_address, daemon=True).start()
        threading.Thread(target=self.run_ngrok, daemon=True).start()

    def find_ip_address(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80)); self.ip_var.set(s.getsockname()[0]); s.close()
        except Exception: self.ip_var.set("Not Found")

    def run_ngrok(self):
        ngrok_path = os.path.join(os.path.dirname(__file__), "ngrok")
        if not os.path.exists(ngrok_path):
            self.ngrok_var.set("ngrok not found!"); return
        os.chmod(ngrok_path, 0o755)
        self.ngrok_process = subprocess.Popen([ngrok_path, "http", "5000", "--log=stdout"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in iter(self.ngrok_process.stdout.readline, ""):
            if "url=" in line:
                url = line.split("url=")[-1].strip()
                self.ngrok_var.set(url)
                self.generate_qr_code(url) # Generate QR on URL discovery
                break

    def generate_qr_code(self, url):
        qr = qrcode.QRCode(version=1, box_size=10, border=2)
        qr.add_data(url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white").resize((150, 150))
        self.qr_image = ImageTk.PhotoImage(img)
        self.qr_label.config(image=self.qr_image, text="") # Update label with image

    def start_recording(self):
        if not self.meeting_id_var.get():
            messagebox.showerror("Error", "Meeting ID is required."); return
        recorder.set_meeting_info(self.meeting_id_var.get(), self.meeting_topic_var.get(), self.save_path_var.get())
        if recorder.start_recording():
            self.status_var.set(f"Recording: {self.meeting_id_var.get()}")
            self.update_ui_state()

    def stop_recording(self):
        if recorder.stop_recording():
            self.status_var.set("Stopped. Saving in background...")
            self.update_ui_state()

    def toggle_pause(self):
        status = recorder.get_status()
        if status['is_paused']:
            recorder.resume_recording(); self.status_var.set(f"Recording: {self.meeting_id_var.get()}")
        else:
            recorder.pause_recording(); self.status_var.set("Paused")
        self.update_ui_state()

    def update_ui_state(self):
        status = recorder.get_status()
        is_recording = status['is_recording']; is_paused = status['is_paused']
        self.id_entry.config(state=tk.DISABLED if is_recording else tk.NORMAL)
        self.topic_entry.config(state=tk.DISABLED if is_recording else tk.NORMAL)
        self.path_entry.config(state=tk.DISABLED if is_recording else tk.NORMAL)
        self.start_btn.config(state=tk.DISABLED if is_recording else tk.NORMAL)
        self.stop_btn.config(state=tk.NORMAL if is_recording else tk.DISABLED)
        self.pause_btn.config(state=tk.NORMAL if is_recording else tk.DISABLED, text="Resume" if is_paused else "Pause")
        if not is_recording: self.timer_var.set("00:00:00")

    def update_timer(self):
        status = recorder.get_status()
        if status['is_recording']:
            self.timer_var.set(recorder.format_duration(int(status['elapsed_time'])))
        self.after(500, self.update_timer)

    def on_close(self):
        if self.ngrok_process: self.ngrok_process.terminate()
        self.destroy()

if __name__ == "__main__":
    app = SRMDesktopApp()
    app.mainloop()
