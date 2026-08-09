extends Line2D

var target
var point
@export var targetPath : NodePath
@export var trailLength = 20

# Called when the node enters the scene tree for the first time.
func _ready():
	target = get_node(targetPath)
	set_as_top_level(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	global_rotation = 0
	point = target.global_position
	add_point(point)
	while get_point_count() > trailLength:
		remove_point(0)
