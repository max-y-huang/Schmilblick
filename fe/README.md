# smart_turner


## Install backend dependencies
```
cd be
npm install --immutable
```

## Run the server
Inside `/be/src`, create a `.env` file with the contents `PORT=3000`. Now we can run the server at port 3000:
```
ts-node index.ts
```

## Run the Flutter app on the Web (Chrome)
Open a new terminal window and navigate to the `/fe` directory.

Inside `/fe`, create a directory called `/assets`. 

Add `happy_birthday.mxl` to this `/assets` directory.
> You can also upload any other `.mxl` file of your choosing, just make sure to change the `filename` in `main.dart` to be the name of your file:
```
const filename = "happy_birthday.mxl";
```

Select the Web as your device and run the Flutter app!



