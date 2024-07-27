# SmartTurner - Running the Flutter App


## Install backend dependencies
```
cd be
npm install --immutable
```

## Run the server
Inside `/be`, create a `.env` file with the contents `NODE_PORT=<YOUR_PORT_HERE>`. Now we can run the server at your specified port:
```
npm run dev
```
Alternatively, you may wish to run `npm run dev:tunnel`. This executes the `start-tunnel.js` script which uses [localhost.run](https://localhost.run/) to forward your `NODE_PORT` to a URI it generates. Then you can copy the URI generated for you and paste this URI into the value for `final uri` in `main.dart`.

## Run the Flutter app
Open a new terminal window and navigate to the `/fe` directory.

Inside `/fe`, there is a directory called `/assets` containing our sheet music in `.mxl` and `.pdf` formats.
You may add your own sheet music of these formats to the `/assets` directory. Just make sure to add the file name to the `assets` section inside `pubspec.yaml` too.

In `main.dart`, you can change the `filename` to be the name of your sheet music file:
```
const filename = "happy_birthday.mxl";
```

Now you're ready to run. Make sure the backend server is still running.
Inside `/fe`, run `flutter run`. Have fun!


