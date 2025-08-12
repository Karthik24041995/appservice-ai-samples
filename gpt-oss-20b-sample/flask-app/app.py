from flask import Flask, request, jsonify, render_template_string, Response

import requests, json
app = Flask(__name__)

OLLAMA_HOST = "http://localhost:11434"
MODEL_NAME = "gpt-oss:20b"


@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    prompt = data.get("prompt", "")
    if not prompt:
        return jsonify({"error": "Prompt is required."}), 400
    payload = {
        "model": MODEL_NAME,
        "messages": [{"role": "user", "content": prompt}],
        "stream": True
    }
    def generate():
        try:
            with requests.post(f"{OLLAMA_HOST}/api/chat", json=payload, stream=True) as r:
                r.raise_for_status()
                for line in r.iter_lines(decode_unicode=True):
                    if not line:
                        continue
                    event = json.loads(line)
                    if "message" in event and "content" in event["message"]:
                        yield event["message"]["content"]
                    if event.get("done"):
                        break
        except Exception as e:
            yield f"[Error: {str(e)}]"
    return Response(generate(), mimetype='text/plain')


# Simple chat UI
@app.route("/")
def index():
    html = r'''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>GPT-OSS-20B Chat</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            #chatbox { width: 100%; height: 300px; border: 1px solid #ccc; padding: 10px; overflow-y: auto; margin-bottom: 10px; }
            #prompt { width: 80%; padding: 8px; }
            #send { padding: 8px 16px; }
        </style>
    </head>
    <body>
        <h2>GPT-OSS-20B Chat</h2>
        <div id="chatbox"></div>
        <input type="text" id="prompt" placeholder="Type your message..." />
        <button id="send">Send</button>
        <script>
            const chatbox = document.getElementById('chatbox');
            const promptInput = document.getElementById('prompt');
            const sendBtn = document.getElementById('send');
            function appendMessage(sender, text) {
                const msgDiv = document.createElement('div');
                msgDiv.innerHTML = `<b>${sender}:</b> <span>${text}</span>`;
                chatbox.appendChild(msgDiv);
                chatbox.scrollTop = chatbox.scrollHeight;
                return msgDiv.querySelector('span');
            }
            async function streamBotResponse(prompt) {
                appendMessage('You', prompt);
                // Create bot message element with 'thinking...' text
                const botSpan = appendMessage('Bot', '');
                botSpan.textContent = '';
                // Add a spinner or thinking message
                const thinkingSpan = document.createElement('span');
                thinkingSpan.innerHTML = ' <span style="color: #888;">Bot is thinking...</span>';
                botSpan.parentNode.appendChild(thinkingSpan);
                try {
                    const res = await fetch('/chat', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ prompt })
                    });
                    if (!res.body) throw new Error('No response body');
                    const reader = res.body.getReader();
                    let decoder = new TextDecoder();
                    let done = false;
                    let firstChunk = true;
                    while (!done) {
                        const { value, done: doneReading } = await reader.read();
                        done = doneReading;
                        if (value) {
                            const chunk = decoder.decode(value);
                            if (firstChunk) {
                                // Remove thinking message on first chunk
                                thinkingSpan.remove();
                                firstChunk = false;
                            }
                            botSpan.textContent += chunk;
                            chatbox.scrollTop = chatbox.scrollHeight;
                        }
                    }
                    if (firstChunk) {
                        // If no chunk ever arrived, remove thinking message
                        thinkingSpan.remove();
                    }
                } catch (e) {
                    thinkingSpan.remove();
                    botSpan.textContent = 'Error: ' + e;
                }
            }
            sendBtn.onclick = function() {
                const prompt = promptInput.value.trim();
                if (!prompt) return;
                promptInput.value = '';
                streamBotResponse(prompt);
            };
            promptInput.addEventListener('keydown', function(e) {
                if (e.key === 'Enter') sendBtn.click();
            });
        </script>
    </body>
    </html>
    '''
    return render_template_string(html)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
