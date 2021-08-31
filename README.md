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
- action_m0
- action_lean_left
- action_lean_right
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
- Mouse Sensitivity : This control how resposive mouse look is
- Air Control : By default set to false. If enabled Player have full control it's horizontal movement while on air as if it's on floor
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
- Throw Force : Force player use to throw grabbed object

Camera_addon has several options that can be customized
- Follow Target : Point it at Player's main Node (KinematicBody), if empty it will use parent node as target
- Feat Head Bob : Enable Head Bobbing while walking
- Feat Lean : Enable leaning sideways by pressing action_lean_left or action_lean_right
- Feat Lean On Wallrun : If enabled, camera will lean while doing wallrun
- Head Bob H : Head bob horizontal movement distance
- Head Bob V : Head bob vertical movement distance
- Head Bob Rotation : Head bob rotation
- Head Bob Speed : Speed of head bobbing
- Lean Angle : Maximum angle when leaning
------------------------------------

##Important
- Remember to disable vsync. Camera uses smoothing script that works best if vsync is disabled






