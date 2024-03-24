extends Control

@onready var description: TextEdit = $Description

var member: DocData.Member
var field: StringName

func _ready() -> void:
	if member:
		description.text = "\n".join(member.get(field))
		refresh_color()
	description.text_changed.connect(update_member)

func set_member(m: DocData.Member, f := &"description"):
	member = m
	field = f
	
	if not member is DocData.ClassMember: 
		var text := PackedStringArray([member.get_name()])
		%Label.text = "".join(text)
	
	#if not arguments.is_empty():
		#text.append("(")
		#
		#var subtext: PackedStringArray
		#for argument in arguments:
			#subtext.append("%s: %s" % argument)
		#text.append(", ".join(subtext))
		#
		#text.append(")")
	#
	#if not return_type.is_empty():
		#text.append(" -> ")
		#text.append(return_type)
	
	if is_node_ready():
		description.text = "\n".join(member.get(field))
		refresh_color()

func refresh_color():
	modulate = Color.RED if description.text.is_empty() else Color.WHITE

func connect_changed(target: Callable):
	description.text_changed.connect(target)

func update_member():
	member.set(field, description.text.split("\n"))
	print(member)

func edit():
	description.grab_focus()
