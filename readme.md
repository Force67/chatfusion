## Monkeychat

I wanted to have a frontend for chatting with LLMs that doesn't suck and
has a uniform interface for both mobile and desktop and syncs chat history between devices without the need for a third party server.
So i made my own. It's a work in progress, but it's getting there.

### Features
- [x] Privacy first, no data is stored on any servers.
- [x] Chat with multiple backends
- [x] Select multiple models
- [x] Adjust parameters like temperature in the chat on the go (TODO: personas)
- [x] Save and load chat history
- [x] Clear the context without deleting the entire chat history

## Planned Features
- [ ] Save incomplete messages (if you quit while typing)
- [ ] Multimodal chat
- [ ] Whisper integration -> chat directly with voice
- [ ] Support for ollama
- [ ] Render reasoning behind the AI's response
- [ ] Cost/Limit setting for both tokens and $$ spent
- [ ] Add more backends
- [ ] Add local sync, so the chat history is shared between all instances of the app without the use of a server

## Usage
I recommend using openrouter. Simply request your api key and set in the app settings. Then you should be able to view the model list and begin chatting.
