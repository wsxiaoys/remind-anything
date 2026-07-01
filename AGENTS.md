1. If you need user provide feeback on app, you need run Scripts/build_app.sh to create a new distribution under dist/.

2. To relaunch a fresh build for testing, quit the running app and reopen the
   bundle. The running process name is the bundle *executable* name
   (`RemindAnything`, no space), NOT the `.app` display name (`Remind Anything`),
   so `pkill -x "Remind Anything"` never matches. Use one of these instead:

   ```sh
   pkill -x RemindAnything; sleep 1; open "dist/Remind Anything.app"
   ```

   Alternatives to quit the app:
   - `pkill -f "Remind Anything.app"` — match against the full path.
   - `osascript -e 'quit app "Remind Anything"'` — graceful quit by display name.
