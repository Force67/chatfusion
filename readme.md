## Monkeychat

An AI chat frontend for power users.

As someone who uses AI a lot, i wanted to have a frontend for chatting with LLMs that doesn't suck. For me that includes:

- [x] Privacy first, no data is stored on any servers.
- [ ] Chat with multiple backends
- [x] Select multiple models
- [x] Adjust parameters like temperature in the chat on the go (TODO: personas)
- [x] Save and load chat history
- [x] Clear the context without deleting the entire chat history
- [x] Render reasoning behind the AI's response (If supported by the model)

## Planned Features
- [ ] Save incomplete messages (if you quit while typing)
- [ ] Multimodal chat
- [ ] Whisper integration -> chat directly with voice
- [ ] Cost/Limit setting for both tokens and $$ spent
- [ ] Add more backends, such as ollama
- [ ] Add local sync, so the chat history is shared between all instances of the app without the use of a server
- [ ] Chat-sharing feature 

## Usage
I recommend using openrouter. Simply request your api key and set in the app settings. Then you should be able to view the model list and begin chatting.

### Linux

On linux, you need zenity installed in order to render the file picker. You can install it with `sudo apt install zenity`.