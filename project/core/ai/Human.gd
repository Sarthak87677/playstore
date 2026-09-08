extends Node3D
class_name Human
## A person: articulated torso, head, arms and legs, built from the same
## procedural generators as everything else.
##
## The world had no human presence at all. The only characters were a survey
## drone and a four-legged walker, and the walker's limbs were boxes. A figure
## you recognise as a person -- correct proportions, a head that has a jaw, arms
## that hang from shoulders rather than sockets in a slab -- does more for
## whether a place reads as real than any amount of surface detail, because it
## is the one shape every viewer is an expert on.
##
## Deliberately not a game character: these are survey crew, standing or slumped
## where the story left them. They breathe and shift their weight, which is
## enough to stop them reading as statues, and they are scannable.

## Human proportions in head-heights, the canon every figure drawing uses:
## roughly 7.5 heads tall, shoulders 2 heads wide, legs half the total height.
const HEADS := 7.4

var height := 1.78
var build := 1.0                  ## 0.85 slight, 1.15 heavy
var skin := Color(0.60, 0.44, 0.35)
var cloth := Color(0.30, 0.33, 0.36)
var hair_col := Color(0.16, 0.12, 0.10)
var seed_v := 0
var pose := "stand"               ## "stand", "sit", "slump"

var _t := 0.0
var _joints: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = seed_v
	_t = _rng.randf_range(0.0, 10.0)
	_build()

func _hm() -> float:
	return height / HEADS

func _build() -> void:
	var h := _hm()
	var skin_mat := ProcAssets.mat_variant("skin", skin)
	var cloth_mat := ProcAssets.mat_variant("cloth", cloth)
	var boot_mat := ProcAssets.mat_variant("cloth", Color(0.32, 0.30, 0.29), 0.10)

	# Hips sit at just under half total height; everything hangs off this.
	var hips := Node3D.new()
	hips.position = Vector3(0, height * 0.50, 0)
	add_child(hips)
	_joints["hips"] = hips

	var torso_h := h * 2.9
	var torso := MeshInstance3D.new()
	torso.mesh = ProcAssets.body_mesh(torso_h, h * 1.95 * build, h * 1.15 * build)
	torso.material_override = cloth_mat
	hips.add_child(torso)
	_joints["torso"] = torso

	var neck := Node3D.new()
	neck.position = Vector3(0, torso_h, 0)
	hips.add_child(neck)
	_joints["neck"] = neck

	# A neck. Without one the head sits straight on the shoulders and the whole
	# figure reads as a doll.
	var throat := MeshInstance3D.new()
	throat.mesh = ProcAssets.limb_mesh(h * 0.30, h * 0.17, h * 0.20, 8, 1.0)
	throat.material_override = skin_mat
	throat.position = Vector3(0, h * 0.30, 0)
	neck.add_child(throat)

	var head := MeshInstance3D.new()
	head.mesh = ProcAssets.head_mesh(h * 0.46)
	head.material_override = skin_mat
	head.position = Vector3(0, h * 0.52, 0)
	neck.add_child(head)
	_joints["head"] = head

	# Hair, as a cap over the crown and the back of the skull. A bare ellipsoid
	# the colour of skin reads as an egg; the dark mass at the top is most of
	# what makes the silhouette say "head" at any distance.
	var hair := MeshInstance3D.new()
	hair.mesh = ProcAssets.rock_mesh(seed_v + 77, h * 0.44, 0.05, 8, 12, 1.0)
	hair.material_override = ProcAssets.mat_variant("cloth", hair_col, 0.05)
	hair.position = Vector3(0, h * 0.62, -h * 0.05)
	hair.scale = Vector3(1.02, 0.86, 1.06)
	neck.add_child(hair)

	# Arms. The shoulder sits inboard of the torso's widest point, or the arms
	# splay off the body like a scarecrow's.
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(side * h * 0.88 * build, torso_h * 0.94, 0)
		hips.add_child(sh)
		var upper := MeshInstance3D.new()
		upper.mesh = ProcAssets.limb_mesh(h * 1.35, h * 0.20 * build, h * 0.15 * build, 9, 1.3)
		upper.material_override = cloth_mat
		sh.add_child(upper)
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -h * 1.35, 0)
		sh.add_child(elbow)
		var fore := MeshInstance3D.new()
		fore.mesh = ProcAssets.limb_mesh(h * 1.15, h * 0.15 * build, h * 0.11 * build, 9, 1.25)
		fore.material_override = skin_mat
		elbow.add_child(fore)
		var hand := MeshInstance3D.new()
		hand.mesh = ProcAssets.rock_mesh(seed_v + 31, h * 0.17, 0.10, 6, 8, 0.62)
		hand.material_override = skin_mat
		hand.position = Vector3(0, -h * 1.22, 0)
		elbow.add_child(hand)
		_joints["shoulder%d" % int(side)] = sh
		_joints["elbow%d" % int(side)] = elbow

	# Legs.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * h * 0.42 * build, 0.0, 0)
		hips.add_child(hip)
		var thigh := MeshInstance3D.new()
		thigh.mesh = ProcAssets.limb_mesh(h * 1.85, h * 0.30 * build, h * 0.21 * build, 10, 1.2)
		thigh.material_override = cloth_mat
		hip.add_child(thigh)
		var knee := Node3D.new()
		knee.position = Vector3(0, -h * 1.85, 0)
		hip.add_child(knee)
		var shin := MeshInstance3D.new()
		shin.mesh = ProcAssets.limb_mesh(h * 1.75, h * 0.21 * build, h * 0.14 * build, 10, 1.25)
		shin.material_override = cloth_mat
		knee.add_child(shin)
		var foot := MeshInstance3D.new()
		foot.mesh = ProcAssets.box_mesh(Vector3(h * 0.36, h * 0.24, h * 0.78))
		foot.material_override = boot_mat
		foot.position = Vector3(0, -h * 1.85, h * 0.18)
		knee.add_child(foot)
		_joints["leg%d" % int(side)] = hip
		_joints["knee%d" % int(side)] = knee

	_apply_pose()

## Static poses. A crew that is all standing to attention is its own kind of
## wrong, so figures can be sat or slumped where the scene calls for it.
func _apply_pose() -> void:
	match pose:
		"sit":
			for side in [-1.0, 1.0]:
				(_joints["leg%d" % int(side)] as Node3D).rotation.x = -1.45
				(_joints["knee%d" % int(side)] as Node3D).rotation.x = 1.5
			(_joints["hips"] as Node3D).position.y = height * 0.28
		"slump":
			(_joints["hips"] as Node3D).rotation.x = 0.22
			(_joints["neck"] as Node3D).rotation.x = 0.42
			for side in [-1.0, 1.0]:
				(_joints["shoulder%d" % int(side)] as Node3D).rotation.x = 0.30
		_:
			# Standing: arms fall slightly away from the body and the elbows are
			# never locked straight. A perfectly straight arm reads as a mannequin.
			for side in [-1.0, 1.0]:
				(_joints["shoulder%d" % int(side)] as Node3D).rotation.z = side * -0.12
				(_joints["elbow%d" % int(side)] as Node3D).rotation.x = -0.18

func _process(dt: float) -> void:
	_t += dt
	# Breathing, and a slow weight shift. Two cheap motions, but a figure that
	# holds perfectly still is a statue no matter how it is modelled.
	var breathe := sin(_t * 1.05) * 0.012
	var sway := sin(_t * 0.37) * 0.02
	var torso := _joints.get("torso") as Node3D
	if torso:
		torso.scale = Vector3(1.0 + breathe, 1.0, 1.0 + breathe * 1.6)
	var hips := _joints.get("hips") as Node3D
	if hips:
		hips.rotation.z = sway
	var neck := _joints.get("neck") as Node3D
	if neck and pose != "slump":
		neck.rotation.y = sin(_t * 0.23) * 0.22
