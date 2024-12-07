from flask import Flask, request

app = Flask(__name__)

# Endpoint to receive position data
@app.route('/receive-data', methods=['POST'])
def receive_data():
    data = request.get_json()
    if not data or "position" not in data:
        print("Invalid request received.")
        return "Invalid data", 400

    # Extract the position
    position = data["position"]
    x = position.get("x", 0)
    y = position.get("y", 0)
    z = position.get("z", 0)

    # Log the received position
    print(f"Received position: X={x}, Y={y}, Z={z}")
    return "Position received", 200

# Serve raw position on home page
latest_position = "0 0 0"  # Default position for example
@app.route('/')
def home():
    return latest_position

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)  # Bind to all interfaces
