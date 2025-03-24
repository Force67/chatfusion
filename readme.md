<table>
  <tr>
    <td><img src="./app/linux/icons/256x256/chatfusion.png?raw=true" alt="ChatFusion Logo" width="80"></td>
    <td>
      <h1 style="display: inline-block;">ChatFusion</h1>
      <p>
        <a href="https://github.com/Force67/chatfusion/actions/workflows/build.yml">
          <img src="https://img.shields.io/github/actions/workflow/status/Force67/chatfusion/build.yml?logo=linux&label=Linux" alt="Linux Build Status">
        </a>
        <a href="https://github.com/Force67/chatfusion/actions/workflows/build.yml">
          <img src="https://img.shields.io/github/actions/workflow/status/Force67/chatfusion/build.yml?logo=android&label=Android" alt="Android Build Status">
        </a>
      </p>
    </td>
  </tr>
</table>

Pretty cool AI chat frontend for power users.


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

### Installing on NixOS
Add this flake to your flake inputs:
```
chatfusion.url = "github:Force67/chatfusion";
```
Then you can reference this repository via 
```
inputs.chatfusion.packages.${pkgs.system}.default
```
in your packages list.

## Development

Just install flutter. Then run `flutter run` in the app directory of the project. If you have nixOS, you can just use `nix develop` to get my exact development environment.

### Linux

On linux, you need zenity installed in order to render the file picker. You can install it with `sudo apt install zenity`.