// Load environment variables from .env file
require('dotenv').config();

const spawn = require('child_process').spawn;

// Use the PORT variable from the .env file
const port = process.env.NODE_PORT;
const commandString = `-R 80:localhost:${port} localhost.run`.split(' ');
const command = spawn(`ssh`, commandString);

command.stdout.pipe(process.stdout);
