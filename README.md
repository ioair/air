# What is Air

Air is a tool to help you run GUN instances with ease. It was designed to run on Raspberry Pi computers at home, so it will magically sync your Public IP with GoDaddy DNS and you don't have to use any DDNS service.

Air is in development and the "main" branch is the development branch.

# Docs

-   GUN: https://github.com/amark/gun
-   Air: not written yet.

# Features

-   Automatically run on system startup.
-   Automatically update Godaddy DNS IP.
-   Automatically install/renew Let'sEncrypt SSL certificate.
-   Automatically pull update from github.
-   Automatically join Air hub.
-   Automatically update IP, heartbeat status to user space.

# Install

## NAT/port forwarding

You might need one of the following things:

-   Godaddy domain, API key, API secret: if you don't have static Public IP and want Air to automatically update Godaddy DNS IP for you.
-   Make sure you have setup NAT/port forwarding so that Let'sEncrypt bot can find you on the internet.

Tested on: Raspberry OS on Raspberry Pi 4, Ubuntu 19.10 on Acer Nitro 5.

## Standalone Super Peer.

You can install Air as a standalone GUN peer. Just clone this repo.

```bash
sudo ./install.sh
```

## NodeJS module

You can also use Air in your NodeJS projects.

```javascript
import { db } from "air"
const main = async () => {
    await db.start() // Start the db instance
    const { GUN, gun, sea, user } = db
}
main()
```
