# Arduplane scripts


I'm gona collect a few scripts here that can be used on Arduplane

## fslanding
this script will allow your plane to land in case a failsafe is triggered but no DO_LAND mission is set up.
In case of a RTL it will loiter, then slowly decend until a preconfigured altitute is reached.
At that altitude it will continue to loiter until it is heading into the wind, then switch to FBWA and disarm to gently glide to ground

This is currently untested on a real plane due to lack of time.
A detailed test is still necessary:
- RTL_AUTOLAND=0
- _no_ DO_LAND mission set up
- ensure your plane does glide well enough in FBWA at 0 throttle
- set to loiter, cut throttle and switch to FBWA and see how it behaves - thats the final slope approach
- test your RTL settings by RTL>loiter via switch
- then fly out a bit and engage failsafe
- messages of FSS (failsafescript) should appear
- the plane should return and start loitering as regular
- then it will slowley decend, at 10m it should stop and turn into wind, switch to FBWA and glide down with 0 throttle

good luck
