#  Juno
A CD player for MacOS

See also: [Radio Automne](https://github.com/lesterrry/radio-automne) – an Internet radio

![Juno Player](https://github.com/Lesterrry/Juno/blob/main/Juno/Pictures/Juno%20Player.gif?raw=true)

## What is it?
Juno is a player for all sorts of disks. It opens all files your PC is capable of opening. Moreover, Juno
 * Features different playback modes
 * Supports CDs with folders
 * Can [save](#saving-the-disk) CDs
 * Reads ID3
 * Looks really cool
 
 ## How to use
 1. Download the [latest release](https://github.com/Lesterrry/Juno/releases/latest)
 2. Move the application to your *Applications* folder
 3. Right-click on the app, press *Open* and confirm opening
 4. Press *Play/Pause* button to read the disk
 5. Everything else works just like a regular CD player

## Setting up
 1. Press *Set* button
 2. Use *Folder* *up* and *down* buttons to move between settings
 3. Use *Next* and *Previous* buttons to change settings
 4. Press *Set* button again to save settings
 
 ## Saving the disk
 1. Insert the disk and launch Juno
 2. Go to *./Music/Juno/Disks*
 3. Find an image for the disk. It must be 1x1 and not bigger than 1000x1000px
 4. Move it in this folder and make up an easy name for it
 5. Look for a JSON file which represents your disk
 6. Fill in all the properties using this template:
 ```
 {
   "tracks": [
     {
       "title": "FIRST TRACK TITLE",
       "album": "FIRST TRACK ALBUM",
       "url": "URL; DO NOT CHANGE",
       "artist": "FIRST TRACK ARTIST"
     },
     {
       "title": "SECOND TRACK TITLE",
       "album": "SECOND TRACK ALBUM",
       "url": "URL; DO NOT CHANGE",
       "artist": "SECOND TRACK ARTIST"
     },
     {
       "title": "THIRD TRACK TITLE",
       "album": "THIRD TRACK ALBUM",
       "url": "URL; DO NOT CHANGE",
       "artist": "THIRD TRACK ARTIST"
     }
   ],
   "reliable": true IF THIS FILE SHOULD BE USED; false IF IT SHOULD NOT, 
   "title": "DISK TITLE",
   "cover_image_name": "NAME OF IMAGE WITH AN EXTENSION"
 }
 ```
 
## Other
You can go to MacOS Settings, *CD/DVD*, and set *Open Application*, Juno as an action when a music CD is inserted. If *AUTOLAUNCH* setting is set to *YES* in Juno, CDs will be read automatically.
