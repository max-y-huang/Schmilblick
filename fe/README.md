# SmartTurner - Running the Flutter App


## Install backend dependencies
```
cd be
npm install --immutable
```

## Run the server
Inside `/be`, create a `.env` file with the contents `NODE_PORT=3000`. Now we can run the server at port 3000:
```
npm run dev
```

## Run the Flutter app on the Web (Chrome)
Open a new terminal window and navigate to the `/fe` directory.

Inside `/fe`, create a directory called `/assets`, if it does not already exist. 

Add `happy_birthday.mxl` to this `/assets` directory, if it does not already exist.
> You can also upload any other `.mxl` file of your choosing, just make sure to change the `filename` in `main.dart` to be the name of your file:
```
const filename = "happy_birthday.mxl";
```

Select the Web as your device and run the Flutter app!



