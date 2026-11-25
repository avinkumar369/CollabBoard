# CollabBoard

Real-time collaborative whiteboard: Flutter + Node.js + Socket.IO + MySQL.

People draw on the same board, see each other's cursors live, and can share a
read-only link with anyone - no account needed.
## Features

- Pen, eraser, rectangle, circle, triangle, diamond, line and arrow tools
- Text boxes and sticky notes
- Select tool: tap to select, drag to move, delete
- Infinite canvas with pan and 25%-300% zoom
- Live cursors and presence over Socket.IO
- Undo / redo, 50 steps, persisted to the server
- Read-only share links and invitation codes
- PNG export of the whole board
- JWT auth with owner / editor / viewer roles
## Run it

Backend: `cd CollabBoard/backend`, then `npm install`, copy `.env.example` to
`.env`, load `database/schema.sql`, and run `npm start`.

Frontend: `cd CollabBoard/frontend/collabboard_app`, then `flutter pub get` and
`flutter run`.
API address by device: `10.0.2.2` for the Android emulator, `localhost` with
`adb reverse tcp:5000 tcp:5000` over USB, or your PC's LAN IP on Wi-Fi. It is
set in `lib/services/api_service.dart`.

## Tests

`flutter analyze && flutter test` in the app folder, or `.\check.ps1` from the
repository root. GitHub Actions runs both on every push.

## Author

Avin Rathod
