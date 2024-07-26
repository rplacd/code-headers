# About this package:

Headers are comments that structure the code, give it logical flow,
etc. They might look something like this:

// * Now create the shader program.

(code goes here)

// ** Link our attributes to vertex info. 

(code goes here)

// * Render!

Extract-headers gets their hierarchy and displays it on a buddy
buffer, with links to their points in the code. It doesn't do online
updating, though, so you'll have to update it as you wish. The point
will jump to the buffer when you do this, though. If the buffer's
already there when extract-headers is run again, it wipes the buffer
and re-uses it.

## How do I use this?

Customize *header-starter* and *comment-starter*. Then bind
extract-headers or extract-headers-online to a key - and run it. 

## So what's next?

If I've got time? A dedicated mode, with navigation keybindings. I
figure I'll eventually end up re-creating half of org-mode's
functionality, though...
