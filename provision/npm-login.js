var RegistryClient = require('npm-registry-client');

var client = new RegistryClient({});

// see https://github.com/npm/npm-registry-client/blob/v8.5.0/lib/adduser.js
client.adduser(
  process.env.NPM_REGISTRY,
  {
    auth: {
      username: process.env.NPM_USER,
      password: process.env.NPM_PASS,
      email: process.env.NPM_EMAIL,
    }
  },
  (error, data, raw, response) => {
    if (error) {
      console.error(error)
      process.exit(1)
    }
    console.log(data.token)
    process.exit()
  }
);
