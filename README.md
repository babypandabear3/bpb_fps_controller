# BPB FPS CONTROLLER
------------------------------------
BabyPandaBear3 First Person Shooter Player Controller
------------------------------------
## Status:
> 0.1.2
------------------------------------
## Install:
Clone or download the repository. Extract
Copy folder "player_controller" to your project
 
Add These Input to Input Map
- movement_forward
- movement_backward
- movement_left
- movement_right
- movement_jump
- action_sprint
- action_crouch_toggle
- action_toggle_fly
- action_lean_left
- action_lean_right
- action_activate
- action_m0
- action_m1
- hotkey_1
- hotkey_2
- hotkey_3
- hotkey_4
- hotkey_5

------------------------------------
## Usage
- Put Player.tscn to your map
------------------------------------
## Features
- Crouching
- Climbing, Dishonored / Thief Style. Press and Hold movement_jump while on air, near ledge and player will climb up
- Enable / Disable Air Control
- Grab and Throw Objects, Half Life / Portal Style
- Moving and Rotating Platform
- Body can be affected by external force such as Wind Tunnel
- Sliding (Dishonored style, Run then Crouch to slide)
- Wall Run and Wall Jump
- Set Jump Limit to 2 or 3 to allow Double / Triple Jump
------------------------------------
## Customization
There are several exported variables that can be changed to customize Player behavior. 

- Feat Crouching : Default On. If disabled then player won't be able to crouch
- Feat Climbing : Allows player to climb ledge, Dishonored / Thief like
- Feat Slide : Allows player to slide. To execute, start crouching while running
- Feat Wallrun : Allows player to run on wall while not on floor. To execute, run while on air and touching wall
- Stand After Slide : if enabled, player will stand (uncrouching) after slide
- Stand After Climb : if enabled, player will stand (uncrouching) after slide
- Mouse Sensitivity : This control how resposive mouse look is
- Air Control : By default set to false. If enabled Player have full control it's horizontal movement while on air as if it's on floor
- Courch Anim : Several options for crouch animation, each has different crouching height
- Speed H Max : Maximum horizontal velocity speed
- Speed Acc : Horizontal movement acceleration rate
- Speed Deacc : Horizontal movement deacceleration rate
- Sprint Modi : If action_sprint button is pressed,  maximum speed is now Speed H Max * Sprint Modi Active
- Crouch Modi : When crouching, maximum speed formula is Speed H Max * Crouch Modi.
- Coyote Time : Allows player to jump a short time after getting off ground
- Gravity Force : Maximum vertical speed
- Gravity Acc : Vertical movement acceleration rate
- Jump Force : Affect Jump Height
- Jump Limit : Define how many jump player can do. If set to 2 then player can do double jump
- Slope Limit : in Degree. If floor is steeper than Slope Limit then Player can't climb and will slide down slope
- On Slope Steep Speed : how fast player will slide down steep slope
- Slide Time : How long player will slide 
- Bump Force : Force applice to Rigidbody when player bumbp to it
- Swim H Deacc : Swimming movement speed deacceleration
- Swim V Deacc : Swimming fall down deacceleration when entering water

Camera_addon has several options that can be customized
- Follow Target : Point it at Player's main Node (KinematicBody), if empty it will use parent node as target
- Feat Head Bob : Enable Head Bobbing while walking
- Feat Lean : Enable leaning sideways by pressing action_lean_left or action_lean_right
- Feat Lean On Wallrun : If enabled, camera will lean while doing wallrun
- Feat Crouch Crawl : Raise crouching camera position, but when getting into tight space like air duct then camera gets lower
- Fov Default : Default Field of View for camera
- Head Bob : Head bob vertical movement distance
- Head Bob Speed : Speed of head bobbing
- Lean Angle : Maximum angle when leaning
- Lean Pivot Move Speed : Camera movement speed when leaning
- Wallrun Lean Angle : Angle camera tilted while doing wall run
------------------------------------
## ADDITIONAL
The controller comes with GameLogic_addon. This is where you are supposed to implement your game logic.
Included in GameLogic_addon, are several examples :
- Grab and throw object. Press action_activate to grab or release, action_m0 to throw grabbed object
- simple pistol, shotgun and smg. Press hotkey_1, hotkey_2, hotkey_3 to change active weapons, press action_m0 to shoot
- blink "teleport" from Dishonored. Press hotkey_4 to activate blink, press and hold action_m1 to target, release action_m1 to execute blink
- wind blast. Press hotkey_5 to activate wind blast, press action_m1 to execute wind blast. 

## Important
- Remember to disable vsync. Camera uses smoothing script that works best if vsync is disabled






