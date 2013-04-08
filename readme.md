# PacPac

This is Pac-Man from a parallel universe.

![PacPac Title](https://raw.github.com/tylerneylon/pacpac/master/screenshots/title.png)

![PacPac Level Samples](https://raw.github.com/tylerneylon/pacpac/master/screenshots/level1_2.png)

There are 3 mazes to play through. This is thrice as
many as the original pac-man :)

You need the [löve](http://love2d.org) game engine to play - at least version 0.8.0.

The original code was written in under 24 hours as a challenge.
My wife didn't believe I could make a pac-man-like game in a day.
Here's a fun [first 24-hour evolution of the game in screenshots](http://tylerneylon.com/pacpac/).

## How to install and run

1. Download and install [löve](http://love2d.org). (Older versions before 0.8.0 won't work.)
2. Download and unzip the [zipfile of this repo](https://github.com/tylerneylon/pacpac/archive/master.zip).
3. Double-click the file `pacpac.love`.
   Alternatively, in OS X and Ubuntu, type `love pacpac.love` from the command line - which assumes
   the `love` executable is in your path.

## Level Editing

I've set up the game so that you can make your own levels without having to know how to program.
Just edit `level1.txt` or any other `levelN.txt` file to change that level. The file format is
explained within those files, and this format is designed to be human-friendly and flexible.

If you're running PacPac using `pacpac.love`, then you need to run
`make_love_file.sh` before the level changes will show up in the game. This
shell script is meant to be run from the command line by cd'ing into your pacpac
directory (the one containing `make_love_file.sh`) and typing the command
`./make_love_file.sh`.

## Contributions

It would be awesome if other coders contributed more levels. I'd like each level to add something
new to the game. For now, level 2 adds a new layout and color, which in most games would
not count as "new" but since Pac-Man has such a strong 1-layout tradition, I'm counting it as new.

My code philosophy for PacPac is to keep the code a little dirty, as in using global variables
freely. Seriously. It's not that dirty is good, but rather that getting things done is good.
So I'm asking for contributions that fix bugs or improve gameplay, but are not focused on
refactoring. Refactoring is fine as a by-product of other changes, though.

If you'd like to add a level, please read the next section to understand what kind of
level designs would fit in with the game. Thanks!

## Things That Could be Added

### Levels

Below are a few ideas for later levels.
It would be cool to arrange them in the game from easiest to hardest.

* New ghost AI's in different colors.
* A gun that can shoot ghosts.
* A level with keys that can open doors. Doors are basically walls that you can erase
  with a key.
* A level with portal-like mechanics. Maybe a warp door that changes connected doors,
  or a warp gun. (This sounds a little scary to have to debug.)
* A level where the hero and ghosts switch roles. By default, the ghosts are weak - i.e., flashing
  white/blue and can be eaten. The ghosts eat dots, and if they eat a superdot, then the hero
  becomes vulnerable - i.e., the ghosts appear non-flashing temporarily. However, the ghosts no
  longer reincarnate, and it is the hero's goal to eat all of them.

Once we have 10 good and mostly bug-free levels, I'll consider the game to be v1-ready.

### Other features

Summary:

* Tasty foods for bonus points
* One or maybe two extra lives for certain score points
* Replay a previously-played game
* Analytics
* Server-based high-score-of-the-day

#### Tasty foods

In the original game, you can eat fruit like apples and oranges.
It would be cool to add more fun foods like pizza, burgers, fries,
and waffles. Maybe cinnamon rolls. Foods that are tasty and would
make for fun pixel art.

#### Extra lives

In the original game, you also get an extra life once you reach a
certain score. This is a nice feature that we could include
in PacPac.

#### Game reply

Automatically save all the effective commands the user provides so that
we can exactly replay that game as a watch-only experience. Maybe this
could happen automatically for the highest-scoring game, which would
be displayed from the title screen if the user is idle.

There are a couple points to be careful about. The game currently uses
a random number generator, so we'd have to save the seed used. It also
depends on the dt values sent in to update, so we'd have to be careful
about how the replay worked with the dt values. That might be tricky.
Finally, there is technically analog input available through gamepads,
but this can be discretized so that we only need to remember the
successful calls to `dir_request`.

#### Analytics

By this, I mean heat maps of death locations on each level, and average
time-of-life per level. This could help us figure out which levels are
most challenging. From there we could do things like modify too-hard or
too-easy sections, and make sure the levels are in the right order.

#### Server-based scores

This is self-explanatory. Even better is being able to download and watch
a replay of good high scores.

## Credits

This game uses the font 8bitoperator created by
[GrandChaos9000](http://grandchaos9000.deviantart.com/)
(aka Jayvee D. Enaguas) and is distributed under the
[CC-BY-SA](http://creativecommons.org/licenses/by-sa/2.0/) license.
