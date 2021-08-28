# BPB FPS CONTROLLER
------------------------------------

BabyPandaBear3 First Person Shooter Player Controller
------------------------------------


## Status:
> 0.1.0
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

------------------------------------

## Usage
- Put Player.tscn to your map

## Features
- Crouching
- Climbing, Dishonored / Thief Style. Press and Hold movement_jump while on air, near ledge and player will climb up
- Enable / Disable Air Control
- Grab and Throw Objects, Half Life / Portal Style
- Moving and Rotating Platform
- Body can be affected by external force such as Wind Tunnel

## Customization
There are several exported variables that can be changed to customize Player behavior. 

- Feat Crouching : Default On. If disabled then player won't be able to crouch
- Feat Climbing : Default On. If disabled, player can't climb ledge
- Mouse Sensitivity : This control how resposive mouse look is
- Air Control : By default set to false. If enabled Player have full control it's horizontal movement while on air as if it's on floor
- Speed H Max : Maximum horizontal velocity speed
- Speed Acc : Horizontal movement acceleration rate
- Speed Deacc : Horizontal movement deacceleration rate
- Sprint Modi Active : If action_sprint button is pressed,  maximum speed is now Speed H Max * Sprint Modi Active
- Gravity Force : Maximum vertical soeed
- Gravity Acc : vertical movement acceleration rate
- Jump Force : Affect Jump Height
- Slope Limit : in Degree. If floor is steeper than Slope Limit then Player can't climb and will slide down slope
- On Slope Steep Speed : how fast player will slide down steep slope
- Throw Force : Force player use to throw grabbed object

- Body Height : Please don't touch this. This is used by animation player to change player stance between crouching and standing






