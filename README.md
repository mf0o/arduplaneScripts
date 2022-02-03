# Arduplane scripts


I'm gona collect a few scripts here that can be used on Arduplane

## fslanding
this script will allow your plane to land in case a failsafe is triggered but no DO_LAND mission is set up.
In case of a RTL it will loiter, then slowly decend until a preconfigured altitute is reached.
At that altitude it will continue to loiter until it is heading into the wind, then switch to FBWA and disarm to gently glide to ground
